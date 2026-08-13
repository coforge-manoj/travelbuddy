import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_travel_assistant/core/di/providers.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_state.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_viewmodel.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/voice_conversation_state.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/voice_transcript_rules.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/acknowledgement_composer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice/mic_level_meter.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_service.dart';

/// Drives the hands-free conversation: listen, answer back, send, speak,
/// listen again.
///
/// **The assistant speaks twice per turn.** The moment a request is sent it
/// says what it understood and what it is about to do — see
/// [AcknowledgementComposer] — and the answer follows when it arrives. That
/// middle line is the difference between a conversation and a form submission:
/// the wait is the same length either way, but only one of them leaves the
/// passenger wondering whether they were heard.
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
    AcknowledgementComposer? acknowledgements,
    this.reopenDelay = const Duration(milliseconds: 350),
    this.recoveryDelay = const Duration(milliseconds: 800),
    this.thinkingTimeout = const Duration(seconds: 20),
    this.silentTurnLimit = 2,
  })  : _voice = voice,
        _chat = chat,
        _acknowledgements = acknowledgements ?? AcknowledgementComposer(),
        super(const VoiceConversationState());

  final ConversationVoicePort _voice;
  final ChatViewModel _chat;

  /// Words the wait, so the passenger hears what was understood while the
  /// answer is still being fetched. Held per loop rather than per turn: it
  /// remembers what it last said so a conversation does not open every turn the
  /// same way.
  final AcknowledgementComposer _acknowledgements;

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

  /// The passenger's microphone level, 0..1, for the orb to animate from.
  ///
  /// **Deliberately not part of [VoiceConversationState].** The recognizer
  /// reports at roughly 10-20Hz, and every one of those samples would be a new
  /// state object — rebuilding the page, `VoiceCardStage` and every card widget
  /// under it, several times a second, for a number only the orb reads. A
  /// notifier with a stable identity lets the orb listen on its own.
  ///
  /// A *target*, not a radius: the orb interpolates towards it each frame. Read
  /// directly it would stair-step, because the samples arrive far slower than
  /// the display refreshes.
  final ValueNotifier<double> micLevel = ValueNotifier<double>(0);

  /// Stays at zero on a platform that never reports a level — `speech_to_text`
  /// does not promise the callback, and does not document what Android's value
  /// even means. The orb handles that by blending a breathe in as the level
  /// falls, so a silent meter and a passenger mid-pause both keep it moving;
  /// nothing here needs to detect the difference.
  final MicLevelMeter _meter = MicLevelMeter();

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
    _silenceMic();
    await _voice.cancelListening();
    _chat.abortSpeechQueue();
    if (!mounted) return;
    state = state.copyWith(
      phase: VoicePhase.idle,
      partialTranscript: '',
      acknowledgement: '',
      clearMessage: true,
    );
  }

  /// Leaves audio mode entirely.
  Future<void> stop() async {
    _turn++;
    _cancelTimers();
    _silenceMic();
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

  /// A suggestion chip tapped in audio mode.
  ///
  /// Goes through the same path as a spoken utterance rather than straight to
  /// `ChatViewModel.sendMessage`, so the loop keeps its phase, its watchdog and
  /// its confirmation handling. Tapping "Yes, cancel it" and saying it have to
  /// mean the same thing — and only this path knows that the words approve
  /// something already pending.
  ///
  /// The microphone is cancelled rather than stopped: whatever half-sentence
  /// was in progress belongs to a turn the passenger has just abandoned in
  /// favour of the chip.
  Future<void> say(String utterance) async {
    final text = utterance.trim();
    if (text.isEmpty || _chat.state.isBusy) return;

    _cancelTimers();
    _conclude();
    await _voice.cancelListening();
    if (!mounted) return;

    await _submit(text);
  }

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
    _silenceMic();
    state = state.copyWith(
      phase: VoicePhase.listening,
      partialTranscript: '',
      // The previous turn's opening line has been overtaken by its answer.
      acknowledgement: '',
    );
    _sinceReopened = Stopwatch()..start();

    try {
      final started = await _voice.startListening(
        onResult: (transcript, isFinal) =>
            _onTranscript(session, transcript, isFinal),
        onError: (code, permanent) =>
            _onRecognizerError(session, code, permanent),
        onLevel: (level) => _onLevel(session, level),
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
  ///
  /// Silences the meter too: every path that ends a listening session goes
  /// through here, and a meter left holding its last sample leaves the orb
  /// inflated at the size of the passenger's final word for the whole of the
  /// wait that follows.
  void _conclude() {
    _sessionConcluded = true;
    _silenceMic();
  }

  /// Drops the level to zero without waiting for it to decay.
  void _silenceMic() {
    _meter.reset();
    micLevel.value = 0;
  }

  void _onLevel(int session, double level) {
    if (!_isLive(session)) return;
    micLevel.value = _meter.add(level);
  }

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

    // A spoken "yes" while something is pending has to go through
    // confirmPendingAction, which sends the affirmation the backend honours.
    // Routed through sendMessage it would be re-parsed as a fresh request —
    // "cancel my booking" answered with "yes" comes back "Left it as it was",
    // and the UI would report a cancellation that never happened.
    final pending = _chat.state.needsConfirmation;
    // The wording of what is awaiting approval, so the passenger can answer in
    // its own words — "yes, cancel it" is how people actually approve a
    // cancellation, and it is the very phrasing the backend suggests.
    final pendingAction = _chat.state.pendingConfirmationMessage ?? '';
    final confirming =
        pending && isAffirmation(transcript, pendingAction: pendingAction);
    final declining =
        pending && isDecline(transcript, pendingAction: pendingAction);

    // Anything else said while an approval is waiting drops it — see
    // `ChatViewModel.sendMessage`. On screen the confirmation bar visibly goes;
    // spoken, it has to be said, or the passenger's next "yes" lands on nothing
    // and is posted to the backend as a fresh request.
    final dropsPending = pending && !confirming && !declining;

    final acknowledgement = switch ((declining, dropsPending)) {
      // Nothing is fetched for a refusal, so this line is the whole turn.
      (true, _) => _acknowledgements.composeDecline(),
      (_, true) => _acknowledgements.composeDropped(
          _acknowledgements.compose(transcript),
        ),
      _ => _acknowledgements.compose(transcript, confirming: confirming),
    };

    state = state.copyWith(
      phase: VoicePhase.thinking,
      partialTranscript: transcript,
      acknowledgement: acknowledgement,
      consecutiveSilentTurns: 0,
    );
    _startWatchdog(turn);

    if (confirming) {
      await _chat.confirmPendingAction(acknowledgement: acknowledgement);
      return;
    }
    if (declining) {
      _chat.declinePendingAction(acknowledgement: acknowledgement);
      // The spoken refusal hands the turn back when it settles, exactly as an
      // answer does. Reopening here as well would put the microphone up while
      // the assistant is still talking, and the loop is half-duplex. The
      // watchdog started above is the backstop if nothing is ever spoken.
      if (acknowledgement.isEmpty && turn == _turn) {
        unawaited(_reopenAfterGap());
      }
      return;
    }

    await _chat.sendMessage(transcript, acknowledgement: acknowledgement);
  }

  void _onSpeechActivity(SpeechActivity activity) {
    if (!mounted || !state.isActive) return;

    switch (activity) {
      case SpeechActivity.preparing:
        break;
      case SpeechActivity.acknowledging:
        // Audible, but the turn is not answered yet: the watchdog deliberately
        // keeps running. Cancelling it here — as `playing` does — would leave a
        // backend that never replies with nothing to catch it, and the loop
        // would sit listening to its own "let me check that" forever.
        state = state.copyWith(
          phase: VoicePhase.acknowledging,
          lastSpokenLine: _chat.lastSpokenLine,
        );
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
            state.phase == VoicePhase.acknowledging ||
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
    micLevel.dispose();
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
