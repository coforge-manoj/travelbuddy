import 'dart:typed_data';

/// A line of speech that has been fully prepared and is ready to play with no
/// further network work.
///
/// [ChatViewModel] holds the assistant's bubble back until it has one of
/// these, so the passenger never sees text that then sits silent while audio
/// is still being fetched.
class PreparedSpeech {
  const PreparedSpeech({required this.spokenText, this.audioBytes});

  /// What will actually be spoken — already summarized for the ear, which is
  /// usually shorter than the text shown on screen.
  final String spokenText;

  /// Pre-rendered audio when the engine synthesizes ahead of playback
  /// (Cartesia). `null` means the engine renders at play time (on-device TTS).
  final Uint8List? audioBytes;

  bool get isEmpty => spokenText.trim().isEmpty;
}

/// A text-to-speech backend.
///
/// Preparation and playback are deliberately separate so a slow network
/// engine can do its work before the UI commits to showing anything.
abstract class SpeechSynthesizer {
  /// Renders [text] as far as this engine can ahead of time. Returns `null`
  /// when the engine can't handle this line at all, which tells the caller to
  /// fall back to another engine.
  Future<PreparedSpeech?> prepare(String text);

  Future<void> play(PreparedSpeech speech);

  Future<void> stop();

  Future<void> dispose();
}
