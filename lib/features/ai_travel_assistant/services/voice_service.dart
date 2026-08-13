import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:ai_travel_assistant/core/services/tts_engine_setting_store.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/cartesia_speech_synthesizer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/speech_summarizer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/speech_synthesizer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/speech_trace.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/system_speech_synthesizer.dart';

/// The microphone half of [VoiceService], as the conversation loop needs it.
///
/// A separate, narrow interface so `VoiceConversationController` can be tested
/// against a fake of about thirty lines rather than a stand-in for the whole
/// TTS stack. The loop never speaks directly — it drives `ChatViewModel` for
/// that and listens to its `speechActivity` — so this covers listening only.
abstract interface class ConversationVoicePort {
  /// Initializes the recognizer, prompting for permission the first time.
  /// False means the loop cannot run at all.
  Future<bool> ensureReady();

  bool get isListening;

  /// Opens the microphone.
  ///
  /// [onResult] fires for partial transcripts as well as the final one.
  /// [onError] carries the platform's error code, and whether it is worth
  /// retrying — a silent passenger is not the same problem as a busy recognizer.
  /// [onStatus] reports the recognizer's own lifecycle, which is how the loop
  /// knows the previous session really closed before reopening.
  Future<bool> startListening({
    required void Function(String transcript, bool isFinal) onResult,
    void Function(String errorCode, bool permanent)? onError,
    void Function(String status)? onStatus,
    String localeId,
  });

  /// Closes the microphone and delivers whatever was heard as a final result.
  Future<void> stopListening();

  /// Closes the microphone and throws away what was heard.
  ///
  /// Distinct from [stopListening], and the distinction matters: interrupting
  /// must not submit the half-spoken sentence the passenger just abandoned.
  Future<void> cancelListening();
}

/// Wraps speech-to-text (voice input) and text-to-speech (voice output)
/// behind a single, platform-agnostic surface so the ViewModel/UI never
/// touch the underlying plugins directly.
///
/// Output is split into [prepareSpeech] and [playSpeech] so a caller can get
/// the audio fully rendered *before* it commits to showing the matching
/// message — see `ChatViewModel._appendMessage`.
class VoiceService implements ConversationVoicePort {
  VoiceService({
    stt.SpeechToText? speechToText,
    SpeechSynthesizer? systemSynthesizer,
    SpeechSynthesizer? neuralSynthesizer,
    SpeechSummarizer? summarizer,
    TtsEngine Function()? engine,
    bool Function()? summaryEnabled,
    Future<void> Function()? warmUpEngine,
  })  : _speech = speechToText ?? stt.SpeechToText(),
        _warmUpEngine = warmUpEngine,
        _system = systemSynthesizer ?? SystemSpeechSynthesizer(),
        _neural = neuralSynthesizer ?? CartesiaSpeechSynthesizer(),
        _summarizer = summarizer ?? const FallbackSpeechSummarizer(),
        // Read through a callback rather than captured at construction, so
        // flipping the setting takes effect on the very next utterance.
        _engine = engine ?? (() => TtsEngine.cartesia),
        _summaryEnabled = summaryEnabled ?? (() => true);

  final stt.SpeechToText _speech;
  final SpeechSynthesizer _system;
  final SpeechSynthesizer _neural;
  final SpeechSummarizer _summarizer;
  final TtsEngine Function() _engine;
  final bool Function() _summaryEnabled;

  /// Injected rather than taken from [_neural], because only the network
  /// engine has a connection to open and [SpeechSynthesizer] shouldn't carry
  /// a hook every fake would have to stub out.
  final Future<void> Function()? _warmUpEngine;

  bool _speechInitialized = false;

  /// Whether the active engine produces audio before playback starts.
  ///
  /// True for Cartesia, which returns a finished clip from a network call, and
  /// false for the device engine, which renders as it speaks. Callers use it to
  /// decide whether splitting a line into chunks is worth anything: chunking
  /// exists to overlap a network render with playback, so against an engine
  /// with no render step it only adds seams between the pieces.
  bool get rendersAheadOfPlayback => _engine() == TtsEngine.cartesia;

  /// Requests the microphone/speech-recognition permission and initializes
  /// the recognizer. Safe to call more than once. Returns false if the
  /// platform denies permission or has no recognizer available — the
  /// caller should surface a voice-recognition-failed message in that case.
  @override
  Future<bool> ensureReady() async {
    if (_speechInitialized) return true;
    _speechInitialized = await _speech.initialize(
      onError: (_) => _speechInitialized = false,
      onStatus: (_) {},
    );
    return _speechInitialized;
  }

  @override
  bool get isListening => _speech.isListening;

  /// How long a pause ends the passenger's turn.
  ///
  /// Started at 1.2s, which was far too eager on a real device: people pause
  /// mid-sentence to think — "show me my… trips for next month" — and the
  /// recognizer would finalize the fragment and send it. The passenger
  /// experiences that as being cut off after a second or two and never heard
  /// out.
  ///
  /// 3s is closer to how long a person waits before assuming you have finished.
  /// The cost of being too generous is only a slightly later reply; the cost of
  /// being too eager is answering the wrong question.
  static const defaultPauseFor = Duration(seconds: 3);

  /// A ceiling on one turn, so a stuck recognizer can't hold the loop open.
  /// Generous, because it should only ever catch a genuinely stuck session —
  /// a passenger describing a trip can easily talk for half a minute.
  static const defaultListenFor = Duration(seconds: 60);

  /// Starts listening, invoking [onResult] with each partial/final
  /// transcript. Returns false (without calling [onResult]) if the
  /// recognizer couldn't be initialized.
  @override
  Future<bool> startListening({
    required void Function(String transcript, bool isFinal) onResult,
    void Function(String errorCode, bool permanent)? onError,
    void Function(String status)? onStatus,
    String localeId = 'en_US',
    Duration pauseFor = defaultPauseFor,
    Duration listenFor = defaultListenFor,
  }) async {
    final ready = await ensureReady();
    if (!ready) return false;

    if (onError != null) {
      _speech.errorListener = (error) =>
          onError(error.errorMsg, error.permanent);
    }
    if (onStatus != null) _speech.statusListener = onStatus;

    await _speech.listen(
      onResult: (result) => onResult(result.recognizedWords, result.finalResult),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        // Was true, which cancelled the whole session on any error. In a
        // continuous loop that is fatal: a passenger who simply says nothing
        // raises error_speech_timeout, and the conversation would die silently
        // rather than ask again.
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation,
        localeId: localeId,
      ),
      pauseFor: pauseFor,
      listenFor: listenFor,
    );
    return true;
  }

  /// Ends the turn and delivers what was heard.
  @override
  Future<void> stopListening() => _speech.stop();

  /// Ends the turn and discards what was heard.
  ///
  /// Used when the passenger interrupts. [stopListening] would finalize the
  /// half-spoken sentence they just abandoned and send it as their next
  /// message.
  @override
  Future<void> cancelListening() => _speech.cancel();

  /// Gets the selected engine's one-off setup out of the way before the first
  /// reply needs it. Call when the chat opens; failures are ignored.
  Future<void> warmUpSpeech() async {
    final warmUp = _warmUpEngine;
    if (warmUp == null || _engine() != TtsEngine.cartesia) return;
    try {
      await warmUp();
    } catch (_) {
      // Best-effort: `prepareSpeech` connects on demand regardless.
    }
  }

  /// Summarizes [text] for the ear and renders it as far ahead of playback as
  /// the selected engine allows. Returns `null` when there is nothing worth
  /// speaking.
  ///
  /// Cartesia failures degrade to the on-device engine here rather than at
  /// playback time, so the caller always receives something playable.
  ///
  /// Pass `summarize: false` for a line already written for the ear — one
  /// composed by `CardSpeechTextBuilder` from a card's payload. Those carry
  /// fares, PNRs, gates and seat numbers this code is responsible for, and the
  /// summarizer is an LLM: a single transposed character in a booking reference
  /// is a wrong answer delivered confidently. Skipping it also removes a
  /// network round trip from the turn.
  /// Resolves what will actually be said, without synthesizing it.
  ///
  /// Split out so a caller that chunks a line can summarize the whole thing
  /// once and then synthesize the pieces: summarizing each chunk separately
  /// would pay for two LLM round trips and could word the halves
  /// inconsistently, since neither call sees the other.
  Future<String> resolveSpokenText(String text, {bool summarize = true}) async {
    return summarize
        ? _spokenTextFor(text)
        : Future.value(FallbackSpeechSummarizer.stripForSpeech(text));
  }

  Future<PreparedSpeech?> prepareSpeech(
    String text, {
    bool summarize = true,
  }) async {
    final spoken = await resolveSpokenText(text, summarize: summarize);
    if (spoken.isEmpty) return null;

    if (_engine() == TtsEngine.cartesia) {
      final prepared = await _neural.prepare(spoken);
      if (prepared != null) return prepared;
      SpeechTrace.step('cartesia.unavailable', detail: 'falling back to device');
    }
    final prepared = await _system.prepare(spoken);
    SpeechTrace.step('system.prepare.done', detail: 'renders at play time');
    return prepared;
  }

  /// Plays audio produced by [prepareSpeech]. Routed by what the preparation
  /// actually yielded, so a line that fell back to the device engine still
  /// plays correctly while Cartesia is selected.
  Future<void> playSpeech(PreparedSpeech speech) {
    if (speech.isEmpty) return Future<void>.value();
    return speech.audioBytes != null ? _neural.play(speech) : _system.play(speech);
  }

  /// Prepare-then-play in one step, for callers that don't need to gate UI on
  /// readiness.
  Future<void> speak(String text) async {
    final prepared = await prepareSpeech(text);
    if (prepared != null) await playSpeech(prepared);
  }

  Future<void> stopSpeaking() async {
    await _neural.stop();
    await _system.stop();
  }

  Future<String> _spokenTextFor(String text) async {
    if (!_summaryEnabled()) {
      final stripped = FallbackSpeechSummarizer.stripForSpeech(text);
      SpeechTrace.step('summarize.off', detail: 'chars=${stripped.length}');
      return stripped;
    }
    try {
      final spoken = (await _summarizer.summarize(text)).trim();
      SpeechTrace.step(
        'summarize.done',
        detail: 'in=${text.length} out=${spoken.length}',
      );
      return spoken;
    } catch (error) {
      // Summarization is an enhancement — never let it silence the reply.
      SpeechTrace.step('summarize.threw', detail: '${error.runtimeType}');
      return FallbackSpeechSummarizer.stripForSpeech(text);
    }
  }

  /// Stops rather than disposes the synthesizers: they are owned by their own
  /// providers, which handle teardown.
  void dispose() {
    // Teardown must not be the thing that throws. Both calls reach a platform
    // channel, and both fail on a device with no recognizer or TTS engine
    // installed — and under `flutter test`, where there are no channels at all.
    // `stopSpeaking` is additionally a future nobody awaits, so its rejection
    // would surface as an unhandled async error far from here rather than as
    // anything a caller could catch.
    try {
      _speech.cancel();
    } catch (_) {
      // Voice is a nice-to-have; see [_spokenTextFor].
    }
    unawaited(stopSpeaking().catchError((_) {}));
  }
}
