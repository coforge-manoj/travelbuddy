import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_travel_assistant/core/di/providers.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_state.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_viewmodel.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/voice_conversation_state.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/voice_transcript_rules.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_service.dart';

/// Drives the hands-free conversation: listen, send, speak, listen again.
///
/// Owns the loop, not the conversation. Messages, cards and the backend session
/// all stay in [ChatViewModel] — this reads its state, calls its methods, and
/// listens to its `speechActivity`. That split is what lets audio mode be
/// entered and left without disturbing the transcript, and what lets the loop
/// be tested without standing up thirteen use cases.
///
/// **The loop is half-duplex.** The microphone is never open while the
/// assistant is speaking. True barge-in — talking over the assistant — needs a
/// single long-lived `playAndRecord` audio session with echo cancellation, and
/// is a different piece of work; half-building toward it would mostly produce a
/// microphone that hears the assistant and answers itself.
///
/// **Interrupting does not cancel the turn in flight.** The backend has already
/// advanced its journey state against the session id, and there is no
/// cancellation token on the client. A turn the passenger interrupts still
/// completes and still renders its cards — it just is not spoken. Aborting
/// locally would leave the screen disagreeing with a booking that really did
/// go through.
class VoiceConversationController extends StateNotifier<VoiceConversationState> {
  VoiceConversationController({
    required ConversationVoicePort voice,
    required ChatViewModel chat,
    this.reopenDelay = const Duration(milliseconds: 350),
    this.recoveryDelay = const Duration(milliseconds: 800),
    this.thinkingTimeout = const Duration(seconds: 20),
    this.silentTurnLimit = 2,
  })  : _voice = voice,
        _chat = chat,
        super(const VoiceConversationState());

  final ConversationVoicePort _voice;
  final ChatViewModel _chat;

  /// How long to wait after the assistant stops before reopening the
  /// microphone.
  ///
  /// Not politeness — it covers the audio session handing back from playback to
  /// recording, and the speaker's own decay. Reopening immediately catches the
  /// tail of the assistant's last word.
  final Duration reopenDelay;

  final Duration recoveryDelay;

  /// A backstop for a turn that never produces speech or an error — a request
  /// that hangs, or a synthesizer that never resolves.
  final Duration thinkingTimeout;

  /// How many silent turns in a row before the loop stops asking.
  final int silentTurnLimit;

  StreamSubscription<SpeechActivity>? _speechSubscription;
  Timer? _reopenTimer;
  Timer? _watchdog;
  Stopwatch? _sinceReopened;

  /// Identifies one open-microphone session, so callbacks arriving after it has
  /// ended can be ignored. See [_isLive].
  int _micSession = 0;
  bool _sessionConcluded = false;

  /// Guards against two opens overlapping — `startListening` is asynchronous,
  /// and a second call while the first is still in flight leaves the recognizer
  /// in a state where it immediately errors.
  bool _openingMicrophone = false;

  /// Incremented by every interruption and by [stop].
  ///
  /// Everything asynchronous captures it and checks it before acting, so work
  /// belonging to an abandoned turn cannot move the loop on. Without this a
  /// `settled` from an interrupted turn would arrive late and reopen the
  /// microphone after the passenger had closed audio mode.
  int _turn = 0;

  /// Whether the loop was running when the app went to the background, so
  /// resuming can put it back.
  bool _wasActiveOnPause = false;

  /// Opens the microphone and starts the loop.
  ///
  /// Speaks nothing on entry — the passenger opened audio mode to talk, and
  /// re-entering mid-conversation should not replay the last answer.
  Future<void> start() async {
    if (state.isActive) return;
    _turn++;
    final turn = _turn;

    state = state.copyWith(
      phase: VoicePhase.preparing,
      clearMessage: true,
      consecutiveSilentTurns: 0,
      partialTranscript: '',
    );

    final ready = await _voice.ensureReady();
    if (turn != _turn || !mounted) return;
    if (!ready) {
      state = state.copyWith(
        phase: VoicePhase.permissionDenied,
        message: 'I need permission to use the microphone.',
      );
      return;
    }

    // Voice output drives the loop: the microphone reopens when speech settles,
    // so with it off nothing would ever settle and the loop would stall in
    // `thinking` until the watchdog fired.
    if (!_chat.state.isVoiceOutputEnabled) _chat.toggleVoiceOutput();

    _speechSubscription ??= _chat.speechActivity.listen(_onSpeechActivity);
    await _openMicrophone();
  }

  /// Cuts the assistant off and stops the loop, leaving audio mode open.
  ///
  /// Uses `cancelListening`, not `stopListening`: the latter finalizes, which
  /// would submit the half-spoken sentence the passenger just abandoned as
  /// their next message.
  Future<void> interrupt() async {
    _turn++;
    _cancelTimers();
    await _voice.cancelListening();
    _chat.abortSpeechQueue();
    if (!mounted) return;
    state = state.copyWith(
      phase: VoicePhase.idle,
      partialTranscript: '',
      clearMessage: true,
    );
  }

  /// Leaves audio mode entirely.
  Future<void> stop() async {
    _turn++;
    _cancelTimers();
    await _speechSubscription?.cancel();
    _speechSubscription = null;
    await _voice.cancelListening();
    _chat.abortSpeechQueue();
    if (!mounted) return;
    state = state.copyWith(phase: VoicePhase.idle, partialTranscript: '');
  }

  /// Reopens the microphone after the loop has gone [VoicePhase.idle] —
  /// the passenger tapping to start talking again.
  Future<void> resume() => start();

  void onAppLifecycle(AppLifecycleState lifecycle) {
    switch (lifecycle) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Covers phone calls, app switching, Siri and the screen locking in one
        // mechanism: all of them drive the app out of `resumed` first, and the
        // platform pauses playback itself.
        if (!state.isActive) return;
        _wasActiveOnPause = true;
        unawaited(interrupt());
      case AppLifecycleState.resumed:
        if (!_wasActiveOnPause) return;
        _wasActiveOnPause = false;
        unawaited(start());
    }
  }

  // ---------------------------------------------------------------------------
  // The loop
  // ---------------------------------------------------------------------------

  Future<void> _openMicrophone() async {
    if (_openingMicrophone) return;
    _openingMicrophone = true;

    final turn = _turn;
    final session = ++_micSession;
    _sessionConcluded = false;
    state = state.copyWith(phase: VoicePhase.listening, partialTranscript: '');
    _sinceReopened = Stopwatch()..start();

    try {
      final started = await _voice.startListening(
        onResult: (transcript, isFinal) =>
            _onTranscript(session, transcript, isFinal),
        onError: (code, permanent) =>
            _onRecognizerError(session, code, permanent),
      );

      if (turn != _turn || !mounted) return;
      if (!started) {
        state = state.copyWith(
          phase: VoicePhase.permissionDenied,
          message: 'I could not open the microphone.',
        );
      }
    } finally {
      _openingMicrophone = false;
    }
  }

  /// Whether [session] is still the open one and has not already ended.
  ///
  /// A single silence produces *two* callbacks on Android — an empty final
  /// result and an `error_no_match` — and both used to be treated as the end of
  /// a turn. That scheduled two reopens for one pause, which the passenger sees
  /// as the microphone restarting over and over and never hearing them out.
  /// The first callback to conclude a session wins; the rest are ignored.
  bool _isLive(int session) =>
      session == _micSession && !_sessionConcluded && mounted;

  /// Marks this listening session finished, so no later callback can act on it.
  void _conclude() => _sessionConcluded = true;

  void _onTranscript(int session, String transcript, bool isFinal) {
    if (!_isLive(session)) return;
    final heard = transcript.trim();

    if (!isFinal) {
      if (heard.isEmpty) return;
      state = state.copyWith(
        phase: VoicePhase.capturing,
        partialTranscript: heard,
      );
      return;
    }

    if (heard.isEmpty) {
      _conclude();
      _onSilentTurn();
      return;
    }

    _conclude();

    // The microphone hearing the tail of the assistant's own voice, not the
    // passenger. Dropped rather than answered — replying to it would send the
    // assistant into a conversation with itself.
    if (looksLikeEcho(
      heard,
      state.lastSpokenLine,
      sinceReopened: _sinceReopened?.elapsed ?? Duration.zero,
    )) {
      unawaited(_reopenAfterGap());
      return;
    }

    unawaited(_submit(heard));
  }

  Future<void> _submit(String transcript) async {
    final turn = _turn;
    state = state.copyWith(
      phase: VoicePhase.thinking,
      partialTranscript: transcript,
      consecutiveSilentTurns: 0,
    );
    _startWatchdog(turn);

    // A spoken "yes" while something is pending has to go through
    // confirmPendingAction, which sends the affirmation the backend honours.
    // Routed through sendMessage it would be re-parsed as a fresh request —
    // "cancel my booking" answered with "yes" comes back "Left it as it was",
    // and the UI would report a cancellation that never happened.
    if (_chat.state.needsConfirmation) {
      if (isAffirmation(transcript)) {
        await _chat.confirmPendingAction();
        return;
      }
      if (isDecline(transcript)) {
        _chat.declinePendingAction();
        if (turn == _turn) unawaited(_reopenAfterGap());
        return;
      }
    }

    await _chat.sendMessage(transcript);
  }

  void _onSpeechActivity(SpeechActivity activity) {
    if (!mounted || !state.isActive) return;

    switch (activity) {
      case SpeechActivity.preparing:
        break;
      case SpeechActivity.playing:
        _watchdog?.cancel();
        // Taken from what was handed to the synthesizer, not from the last
        // message: on a card turn the bubble holds the caption while the spoken
        // line is the narration built from the payload, and the echo guard
        // needs the words that actually came out of the speaker.
        state = state.copyWith(
          phase: VoicePhase.speaking,
          lastSpokenLine: _chat.lastSpokenLine,
        );
      case SpeechActivity.settled:
        // The one edge the whole loop turns on: the answer has been spoken, so
        // the passenger's turn begins. Not tied to any single playback future —
        // a turn emits a reply and several cards, and the first of those to
        // finish is nowhere near the end of the answer.
        _watchdog?.cancel();
        if (state.phase == VoicePhase.thinking ||
            state.phase == VoicePhase.speaking) {
          unawaited(_reopenAfterGap());
        }
    }
  }

  void _onRecognizerError(int session, String code, bool permanent) {
    if (!_isLive(session)) return;
    _conclude();

    if (isSilenceError(code)) {
      _onSilentTurn();
      return;
    }
    if (permanent) {
      state = state.copyWith(
        phase: VoicePhase.permissionDenied,
        message: 'I could not use the microphone.',
      );
      return;
    }

    final turn = _turn;
    state = state.copyWith(phase: VoicePhase.recovering);
    _reopenTimer?.cancel();
    _reopenTimer = Timer(recoveryDelay, () {
      if (turn != _turn || !mounted) return;
      unawaited(_openMicrophone());
    });
  }

  /// A turn where the passenger said nothing.
  ///
  /// Counted rather than treated as an error, but not retried forever: someone
  /// who has put the phone down should not be asked again every two seconds.
  void _onSilentTurn() {
    final silent = state.consecutiveSilentTurns + 1;
    if (silent >= silentTurnLimit) {
      _turn++;
      _cancelTimers();
      unawaited(_voice.cancelListening());
      state = state.copyWith(
        phase: VoicePhase.idle,
        consecutiveSilentTurns: silent,
        partialTranscript: '',
        message: "Tap when you're ready to talk.",
      );
      return;
    }
    state = state.copyWith(consecutiveSilentTurns: silent);
    unawaited(_reopenAfterGap());
  }

  Future<void> _reopenAfterGap() async {
    final turn = _turn;
    _reopenTimer?.cancel();
    _reopenTimer = Timer(reopenDelay, () {
      if (turn != _turn || !mounted) return;
      unawaited(_openMicrophone());
    });
  }

  void _startWatchdog(int turn) {
    _watchdog?.cancel();
    _watchdog = Timer(thinkingTimeout, () {
      if (turn != _turn || !mounted) return;
      state = state.copyWith(
        phase: VoicePhase.recovering,
        message: 'That took too long. Let me try again.',
      );
      unawaited(_reopenAfterGap());
    });
  }

  void _cancelTimers() {
    _reopenTimer?.cancel();
    _reopenTimer = null;
    _watchdog?.cancel();
    _watchdog = null;
  }

  @override
  void dispose() {
    _cancelTimers();
    unawaited(_speechSubscription?.cancel());
    _speechSubscription = null;
    super.dispose();
  }
}

/// The hands-free loop for the current chat session.
///
/// `autoDispose` so each entry into audio mode starts from a clean
/// [VoicePhase.idle] with no stale phase, partial transcript or silent-turn
/// count. That resets the *loop* only — the conversation lives in
/// [chatViewModelProvider], which survives because `ChatPage` stays mounted
/// beneath the voice page and keeps watching it. Re-entering therefore
/// continues the same conversation, on the same backend session, rather than
/// starting over.
final voiceConversationControllerProvider = StateNotifierProvider.autoDispose<
    VoiceConversationController, VoiceConversationState>((ref) {
  final controller = VoiceConversationController(
    voice: ref.watch(voiceServiceProvider),
    chat: ref.watch(chatViewModelProvider.notifier),
  );
  ref.onDispose(controller.stop);
  return controller;
});
