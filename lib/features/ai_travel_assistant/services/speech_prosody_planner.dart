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

/// Splits spoken copy into sentence segments and assigns pitch/rate so
/// questions, soft apologies, and dense codes don't all sound identical.
///
/// Online speech uses Edge neural voices, which already rise on `?`, so
/// questions stay a single segment with a light pitch nudge (also used by
/// the on-device [flutter_tts] fallback). Platform TTS has no SSML; Edge
/// accepts rate/pitch as `±N%` / `±NHz` via [VoiceService].
class SpeechProsodyPlanner {
  const SpeechProsodyPlanner._();

  static const statementPitch = 1.0;
  static const statementRate = 0.48;

  /// Whole-question nudge for engines that ignore `?`. Neural Edge voices
  /// mostly ignore this and still sound interrogative from the punctuation.
  static const questionPitch = 1.12;
  static const questionRate = 0.47;

  static const softPitch = 0.95;
  static const softRate = 0.44;

  static const densePitch = 1.0;
  static const denseRate = 0.42;

  static final _softOpeners = RegExp(
    r"^(i'm sorry|i am sorry|i'm afraid|unfortunately|sadly)\b",
    caseSensitive: false,
  );

  /// Interrogative openers that often arrive without a trailing `?` from the
  /// phrasing model ("Shall I go ahead and book that.").
  static final _interrogativeOpeners = RegExp(
    r"^(would you|wouldn't you|shall i|should i|do you|does that|did you|"
    r"which|what would|what can|what's|whats|can i|can you|could you|"
    r"could i|is there|are you|have you|want me|may i|how about)\b",
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
    if (_isQuestion(sentence)) {
      return SpeechSegment(
        text: sentence,
        pitch: questionPitch,
        rate: questionRate,
      );
    }
    if (_softOpeners.hasMatch(sentence)) {
      return SpeechSegment(text: sentence, pitch: softPitch, rate: softRate);
    }
    if (_isDense(sentence)) {
      return SpeechSegment(text: sentence, pitch: densePitch, rate: denseRate);
    }
    return SpeechSegment(
      text: sentence,
      pitch: statementPitch,
      rate: statementRate,
    );
  }

  static bool _isQuestion(String sentence) {
    if (sentence.endsWith('?')) return true;
    final body = sentence.replaceAll(RegExp(r'[.!?]+$'), '').trim();
    return _interrogativeOpeners.hasMatch(body);
  }

  static bool _isDense(String sentence) {
    final body = sentence.replaceAll(RegExp(r'[.!?]+$'), '');
    final tokens = body.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.length < 3) return false;
    final shortCount = tokens.where(_shortToken.hasMatch).length;
    return shortCount >= 3;
  }
}
