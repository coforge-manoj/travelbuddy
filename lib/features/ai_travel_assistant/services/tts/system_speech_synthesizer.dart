import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/speech_synthesizer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/speech_trace.dart';

/// On-device text-to-speech via `flutter_tts`.
///
/// The engine renders at play time, so [prepare] only normalizes the text.
/// It still picks the best installed voice and sets an explicit pitch/rate —
/// previously this path used the default voice at a flat rate, which is what
/// made it sound robotic.
class SystemSpeechSynthesizer implements SpeechSynthesizer {
  SystemSpeechSynthesizer({FlutterTts? flutterTts})
      : _tts = flutterTts ?? FlutterTts();

  final FlutterTts _tts;
  bool _configured = false;

  /// Substrings that mark a higher-quality voice on each platform. Apple's
  /// enhanced/premium Siri voices and Google's network voices sound markedly
  /// better than the compact defaults, when the user has them installed.
  static const _preferredVoiceMarkers = <String>[
    'premium',
    'enhanced',
    'neural',
    'wavenet',
  ];

  @override
  Future<PreparedSpeech?> prepare(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return PreparedSpeech(spokenText: trimmed);
  }

  @override
  Future<void> play(PreparedSpeech speech) async {
    if (speech.isEmpty) return;
    // Voice selection is a one-off, but it is a slow one — worth seeing on the
    // first utterance of a session.
    final needsSetup = !_configured;
    await _ensureConfigured();
    if (needsSetup) SpeechTrace.step('system.configured', detail: 'first use');
    await _tts.stop();
    SpeechTrace.step('audio.playing', detail: 'device engine');
    await _tts.speak(speech.spokenText);
    SpeechTrace.step('audio.finished');
  }

  @override
  Future<void> stop() => _tts.stop();

  @override
  Future<void> dispose() async {
    await _tts.stop();
  }

  /// Applied once per process — these are engine-wide settings, not
  /// per-utterance ones.
  Future<void> _ensureConfigured() async {
    if (_configured) return;
    _configured = true;

    try {
      await _tts.setLanguage('en-US');
      // The two platforms scale this differently, so they are tuned separately
      // rather than sharing a number. On Android 0.52 measured about eight
      // characters a second — half conversational pace, turning a card
      // narration into a 43-second monologue — and 0.85 overshot into hurried.
      // 0.62 sits between them.
      await _tts.setSpeechRate(Platform.isIOS ? 0.46 : 0.62);
      await _tts.setPitch(1.05);
      await _tts.setVolume(1.0);
      // Lets `play` await actual completion instead of returning on dispatch.
      await _tts.awaitSpeakCompletion(true);
      await _selectBestVoice();
    } catch (_) {
      // Voice output is a nice-to-have; a platform that rejects any of these
      // should still speak with its defaults.
    }
  }

  Future<void> _selectBestVoice() async {
    final voices = await _tts.getVoices as List<dynamic>?;
    if (voices == null) return;

    final english = <Map<String, String>>[];
    for (final voice in voices) {
      if (voice is! Map) continue;
      final entry = voice.map((key, value) => MapEntry('$key', '$value'));
      if ((entry['locale'] ?? '').toLowerCase().startsWith('en-us')) {
        english.add(entry);
      }
    }
    if (english.isEmpty) return;

    final best = english.firstWhere(
      (voice) {
        final name = (voice['name'] ?? '').toLowerCase();
        final quality = (voice['quality'] ?? '').toLowerCase();
        return _preferredVoiceMarkers
            .any((marker) => name.contains(marker) || quality.contains(marker));
      },
      orElse: () => english.first,
    );

    await _tts.setVoice({
      'name': best['name'] ?? '',
      'locale': best['locale'] ?? 'en-US',
    });
  }
}
