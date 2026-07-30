import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/spoken_draft.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/speech_text_formatter.dart';

/// Decides whether a model-written utterance may be spoken.
///
/// The phrasing layer is allowed to choose words; it is not allowed to touch
/// facts. A passenger cannot rewind audio, so a fare read out one dollar
/// wrong, a dropped confirmation code, or a hallucinated gate is worse than a
/// repetitive-but-correct sentence. Anything this class rejects falls back to
/// [SpokenDraft.fallbackText].
///
/// Pure and side-effect free, so every rule below is directly testable.
class SpokenFactGuard {
  const SpokenFactGuard._();

  /// Never speak more than this, however long the draft is — long spoken turns
  /// are tiring and usually mean the model started padding. Roughly 20 seconds
  /// of speech, and comfortably above the longest deterministic summary (the
  /// booking confirmation, at around 150 characters).
  static const int hardMaxChars = 260;

  /// Returns the speech-ready utterance, or `null` when [candidate] must not
  /// be spoken.
  static String? verify(String candidate, SpokenDraft draft) {
    final cleaned = SpeechTextFormatter.clean(candidate);
    if (cleaned.isEmpty) return null;
    if (cleaned.length > _charLimitFor(draft)) return null;

    // More than one question in a spoken turn leaves the passenger unsure
    // which one to answer.
    if (RegExp(r'\?').allMatches(cleaned).length > 1) return null;

    final normalized = _normalize(cleaned);
    for (final fragment in draft.mustInclude) {
      final needle = _normalize(fragment);
      if (needle.isEmpty) continue;
      if (!normalized.contains(needle)) return null;
    }

    // Every number spoken has to come from the draft. Catches both invented
    // figures and quietly rounded ones ("about 180 dollars").
    final permitted = _numbersIn([...draft.clauses, ...draft.mustInclude, draft.fallbackText]);
    for (final number in _numbersIn([cleaned])) {
      if (!permitted.contains(number)) return null;
    }

    return cleaned;
  }

  /// A phrasing may be a little longer than the deterministic version — that
  /// is often what makes it sound human — but not unboundedly so.
  ///
  /// The floor matters as much as the cap: the shortest summaries are one
  /// clause long, and a warm rendering of one clause plus a closing question
  /// still runs to about 160 characters.
  static int _charLimitFor(SpokenDraft draft) {
    final generous = (draft.fallbackText.length * 1.7).round();
    return generous.clamp(160, hardMaxChars);
  }

  static Set<String> _numbersIn(Iterable<String> sources) {
    return {
      for (final source in sources)
        for (final match in RegExp(r'\d+').allMatches(source)) match.group(0)!,
    };
  }

  /// Case- and spacing-insensitive so "176 Dollars" still matches the
  /// "176 dollars" the formatter produced.
  static String _normalize(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}
