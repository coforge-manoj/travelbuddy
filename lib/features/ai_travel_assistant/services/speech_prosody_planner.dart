/// One spoken chunk with pitch/rate hints for the TTS engine.
class SpeechSegment {
  const SpeechSegment({
    required this.text,
    required this.pitch,
    required this.rate,
  });

  final String text;
  final double pitch;
  final double rate;
}

/// Splits spoken copy into sentence segments and assigns subtle pitch/rate
/// so questions, soft apologies, and dense codes don't all sound identical.
///
/// Platform TTS (`flutter_tts`) has no SSML; the only lever is changing
/// engine knobs between utterances. Deltas stay small on purpose.
class SpeechProsodyPlanner {
  const SpeechProsodyPlanner._();

  static const statementPitch = 1.0;
  static const statementRate = 0.48;

  static const questionPitch = 1.12;
  static const questionRate = 0.50;

  static const softPitch = 0.95;
  static const softRate = 0.44;

  static const densePitch = 1.0;
  static const denseRate = 0.42;

  static final _softOpeners = RegExp(
    r"^(i'm sorry|i am sorry|i'm afraid|unfortunately|sadly)\b",
    caseSensitive: false,
  );

  /// Single-character alphanumeric tokens — how [SpeechTextFormatter] spells
  /// flight numbers and gates ("U A 4 8 2", "B 1 2").
  static final _shortToken = RegExp(r'^[A-Za-z0-9]$');

  /// Splits [text] on sentence boundaries and classifies each piece.
  static List<SpeechSegment> plan(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];

    return _splitSentences(trimmed).map(_toSegment).toList(growable: false);
  }

  static List<String> _splitSentences(String text) {
    final matches = RegExp(r'[^.!?]+[.!?]+|[^.!?]+$').allMatches(text);
    return [
      for (final match in matches)
        if (match.group(0)!.trim().isNotEmpty) match.group(0)!.trim(),
    ];
  }

  static SpeechSegment _toSegment(String sentence) {
    if (sentence.endsWith('?')) {
      return SpeechSegment(
        text: sentence,
        pitch: questionPitch,
        rate: questionRate,
      );
    }
    if (_softOpeners.hasMatch(sentence)) {
      return SpeechSegment(
        text: sentence,
        pitch: softPitch,
        rate: softRate,
      );
    }
    if (_isDense(sentence)) {
      return SpeechSegment(
        text: sentence,
        pitch: densePitch,
        rate: denseRate,
      );
    }
    return SpeechSegment(
      text: sentence,
      pitch: statementPitch,
      rate: statementRate,
    );
  }

  static bool _isDense(String sentence) {
    final body = sentence.replaceAll(RegExp(r'[.!?]+$'), '');
    final tokens = body.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.length < 3) return false;
    final shortCount = tokens.where(_shortToken.hasMatch).length;
    return shortCount >= 3;
  }
}
