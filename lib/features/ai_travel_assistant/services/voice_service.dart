import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:ai_travel_assistant/features/ai_travel_assistant/services/speech_prosody_planner.dart';

/// Wraps speech-to-text (voice input) and text-to-speech (voice output)
/// behind a single, platform-agnostic surface so the ViewModel/UI never
/// touch the underlying plugins directly.
///
/// Text handed to [speak] is expected to already be speech-ready — see
/// `SpeechTextFormatter`. Callers should go through `VoiceNarrator` rather
/// than calling [speak] directly, so utterances queue instead of cutting
/// each other off.
class VoiceService {
  VoiceService({stt.SpeechToText? speechToText, FlutterTts? flutterTts})
      : _speech = speechToText ?? stt.SpeechToText(),
        _tts = flutterTts ?? FlutterTts();

  final stt.SpeechToText _speech;
  final FlutterTts _tts;
  bool _speechInitialized = false;
  bool _ttsConfigured = false;
  bool _isSpeaking = false;

  /// Updated per [startListening] call so [initialize]'s one-shot handlers
  /// can forward into the active session.
  void Function(String status)? _statusHandler;
  void Function()? _errorEndedHandler;

  /// Requests the microphone/speech-recognition permission and initializes
  /// the recognizer. Safe to call more than once. Returns false if the
  /// platform denies permission or has no recognizer available — the
  /// caller should surface a voice-recognition-failed message in that case.
  Future<bool> ensureReady() async {
    if (_speechInitialized) return true;
    _speechInitialized = await _speech.initialize(
      debugLogging: kDebugMode,
      onError: (error) {
        // Kept behind [kDebugMode]: a device with no recognizer or no
        // language pack fails silently otherwise, and this is the only clue.
        if (kDebugMode) {
          debugPrint('[voice] stt error: ${error.errorMsg} permanent=${error.permanent}');
        }
        _speechInitialized = false;
        _errorEndedHandler?.call();
      },
      onStatus: (status) => _statusHandler?.call(status),
    );
    return _speechInitialized;
  }

  bool get isListening => _speech.isListening;

  bool get isSpeaking => _isSpeaking;

  /// Starts listening, invoking [onResult] with each partial/final
  /// transcript. Returns false (without calling [onResult]) if the
  /// recognizer couldn't be initialized.
  ///
  /// [pauseFor] is what makes a final result arrive reliably once the
  /// passenger stops talking, rather than only when the platform decides
  /// the session is over.
  ///
  /// [onListeningEnded] fires when the platform session finishes (silence,
  /// timeout, error, or stop) so the UI can leave the listening state even
  /// when no usable transcript arrived.
  ///
  /// [localeId] defaults to whatever [_resolveLocaleId] finds the installed
  /// recognizer can actually handle; pass one explicitly only to override.
  Future<bool> startListening({
    required void Function(String transcript, bool isFinal) onResult,
    void Function()? onListeningEnded,
    String? localeId,
    Duration listenFor = const Duration(seconds: 15),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    final ready = await ensureReady();
    if (!ready) return false;

    final resolvedLocaleId = localeId ?? await _resolveLocaleId();

    var ended = false;
    void notifyEnded() {
      if (ended) return;
      ended = true;
      onListeningEnded?.call();
    }

    _statusHandler = (status) {
      if (status == stt.SpeechToText.doneStatus ||
          status == stt.SpeechToText.notListeningStatus) {
        notifyEnded();
      }
    };
    _errorEndedHandler = notifyEnded;

    await _speech.listen(
      onResult: (result) => onResult(result.recognizedWords, result.finalResult),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        localeId: resolvedLocaleId,
        listenFor: listenFor,
        pauseFor: pauseFor,
      ),
    );
    return true;
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }

  /// Memoized so the locale lookup costs one platform round trip per run,
  /// and so concurrent [startListening] calls share the same answer.
  Future<String?>? _localeIdFuture;

  /// Picks a locale the installed recognizer actually has a language pack for.
  ///
  /// Hardcoding `en_US` breaks voice input outright on any device set to a
  /// different English variant. The recognizer starts, the microphone
  /// records, and speech is even detected — but with no matching pack it
  /// returns no transcript at all, so the session just times out as though
  /// the passenger never spoke. On an en-GB device this shows up in logcat
  /// as `SodaSpeechRecognizer: Failed to get language pack of required
  /// locale` alongside `SodaLPDirGenerator: Returning no LP`.
  ///
  /// Preference order: the device's own locale, then another variant of the
  /// same language, then `en_US`, then null — which lets each platform fall
  /// back to its own default rather than a locale we know is wrong.
  Future<String?> _resolveLocaleId() => _localeIdFuture ??= _computeLocaleId();

  Future<String?> _computeLocaleId() async {
    try {
      final available = await _speech.locales();
      if (available.isEmpty) return null;

      String canonical(String id) => id.replaceAll('-', '_').toLowerCase();
      String languageOf(String id) => canonical(id).split('_').first;

      final byCanonicalId = {
        for (final locale in available) canonical(locale.localeId): locale.localeId,
      };

      final systemLocaleId = (await _speech.systemLocale())?.localeId;
      if (systemLocaleId != null) {
        final exact = byCanonicalId[canonical(systemLocaleId)];
        if (exact != null) return exact;

        final language = languageOf(systemLocaleId);
        for (final locale in available) {
          if (languageOf(locale.localeId) == language) return locale.localeId;
        }
      }

      return byCanonicalId['en_us'] ?? systemLocaleId;
    } catch (_) {
      // Locale enumeration isn't available on every platform. Null is the
      // safe answer — the recognizer then uses its own default.
      return null;
    }
  }

  /// Speaks [text], resolving only once the utterance has actually finished
  /// (see [_ensureTtsConfigured]). That completion guarantee is what lets
  /// `VoiceNarrator` queue utterances back to back.
  ///
  /// [pitch] and [rate] default to statement prosody; pass per-segment
  /// values from [SpeechProsodyPlanner] for question / soft / dense tone.
  Future<void> speak(
    String text, {
    double pitch = SpeechProsodyPlanner.statementPitch,
    double rate = SpeechProsodyPlanner.statementRate,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _ensureTtsConfigured();
    _isSpeaking = true;
    try {
      await _tts.setPitch(pitch);
      await _tts.setSpeechRate(rate);
      await _tts.speak(trimmed);
    } finally {
      _isSpeaking = false;
    }
  }

  Future<void> stopSpeaking() async {
    _isSpeaking = false;
    await _tts.stop();
  }

  void dispose() {
    _speech.cancel();
    _tts.stop();
  }

  /// One-time engine setup. `awaitSpeakCompletion(true)` is the important
  /// part: without it `speak` returns as soon as the utterance *starts*,
  /// which makes serialized narration impossible.
  Future<void> _ensureTtsConfigured() async {
    if (_ttsConfigured) return;
    _ttsConfigured = true;
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(SpeechProsodyPlanner.statementRate);
    await _tts.setPitch(SpeechProsodyPlanner.statementPitch);
    await _preferQualityVoice();

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // Without a shared session, iOS cuts TTS off when the speech
      // recognizer takes over the audio session. `playAndRecord` (rather
      // than `playback`) is required here too: `playback` is output-only,
      // so once TTS configures the session, the mic silently stops
      // capturing audio for every listen session afterward.
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playAndRecord,
        [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );
    }
  }

  /// Picks a higher-quality en-US system voice when the platform exposes one.
  /// Falls back silently to the language-only default.
  Future<void> _preferQualityVoice() async {
    try {
      final raw = await _tts.getVoices;
      if (raw is! List) return;

      final voices = <Map<String, String>>[
        for (final entry in raw)
          if (entry is Map)
            {
              for (final key in entry.keys)
                if (entry[key] != null) '$key': '${entry[key]}',
            },
      ];

      final enUs = voices.where((voice) {
        final locale = (voice['locale'] ?? voice['localeId'] ?? '').toLowerCase();
        return locale == 'en-us' || locale == 'en_us';
      }).toList();
      if (enUs.isEmpty) return;

      int score(Map<String, String> voice) {
        final quality = (voice['quality'] ?? '').toLowerCase();
        if (quality.contains('enhanced') || quality.contains('premium')) return 3;
        if (quality.contains('default') || quality.contains('normal')) return 1;
        final name = (voice['name'] ?? '').toLowerCase();
        if (name.contains('enhanced') || name.contains('premium') || name.contains('neural')) {
          return 2;
        }
        return 0;
      }

      enUs.sort((a, b) => score(b).compareTo(score(a)));
      final best = enUs.first;
      final name = best['name'];
      final locale = best['locale'] ?? best['localeId'] ?? 'en-US';
      if (name == null || name.isEmpty) return;
      await _tts.setVoice({'name': name, 'locale': locale});
    } catch (_) {
      // Voice enumeration isn't available on every platform/engine. Language
      // defaults from setLanguage are enough.
    }
  }
}
