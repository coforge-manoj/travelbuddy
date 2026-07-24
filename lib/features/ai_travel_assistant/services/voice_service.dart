import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// What a finished voice-mode-2 recording produces: the replayable audio
/// location plus the speech-to-text transcript captured live while recording.
class AudioRecordingResult {
  const AudioRecordingResult({
    this.audioPath,
    required this.transcript,
    required this.duration,
  });

  /// Local file path (mobile/desktop) or blob URL (web).
  ///
  /// Null on Android when only speech-to-text was used: the platform cannot
  /// share the microphone between [record] and [speech_to_text], so we skip
  /// the file to avoid a native crash and still return a live transcript.
  final String? audioPath;
  final String transcript;
  final Duration duration;
}

/// Wraps speech-to-text (voice input) and text-to-speech (voice output)
/// behind a single, platform-agnostic surface so the ViewModel/UI never
/// touch the underlying plugins directly.
class VoiceService {
  VoiceService({stt.SpeechToText? speechToText, FlutterTts? flutterTts})
      : _speech = speechToText ?? stt.SpeechToText(),
        _tts = flutterTts ?? FlutterTts();

  final stt.SpeechToText _speech;
  final FlutterTts _tts;
  bool _speechInitialized = false;

  /// Requests the microphone/speech-recognition permission and initializes
  /// the recognizer. Safe to call more than once. Returns false if the
  /// platform denies permission or has no recognizer available — the
  /// caller should surface a voice-recognition-failed message in that case.
  Future<bool> ensureReady() async {
    if (_speechInitialized) return true;
    _speechInitialized = await _speech.initialize(
      onError: (_) => _speechInitialized = false,
      onStatus: (_) {},
    );
    return _speechInitialized;
  }

  bool get isListening => _speech.isListening;

  /// Starts listening, invoking [onResult] with each partial/final
  /// transcript. Returns false (without calling [onResult]) if the
  /// recognizer couldn't be initialized.
  Future<bool> startListening({
    required void Function(String transcript, bool isFinal) onResult,
    String localeId = 'en_US',
  }) async {
    try {
      final ready = await ensureReady();
      if (!ready) return false;

      await _speech.listen(
        onResult: (result) =>
            onResult(result.recognizedWords, result.finalResult),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          localeId: localeId,
        ),
      );
      return true;
    } catch (_) {
      _speechInitialized = false;
      return false;
    }
  }

  Future<void> stopListening() => _speech.stop();

  /// Speaks [text] aloud, stripping markdown markers first since they read
  /// awkwardly out loud (e.g. "asterisk asterisk delayed asterisk asterisk").
  Future<void> speak(String text) async {
    final cleaned = _stripMarkdown(text).trim();
    if (cleaned.isEmpty) return;
    await _tts.stop();
    await _tts.setSpeechRate(0.48);
    await _tts.speak(cleaned);
  }

  Future<void> stopSpeaking() => _tts.stop();

  void dispose() {
    _speech.cancel();
    _tts.stop();
  }

  String _stripMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'[*_`#]'), '')
        .replaceAll(RegExp(r'\[(.*?)\]\(.*?\)'), r'$1');
  }
}
