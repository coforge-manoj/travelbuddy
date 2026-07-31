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
    return _verify(
      candidate,
      mustInclude: draft.mustInclude,
      numberSources: [...draft.clauses, ...draft.mustInclude, draft.fallbackText],
      fallbackLength: draft.fallbackText.length,
    );
  }

  /// Same fact checks for an on-screen caption, using readable must-include
  /// fragments ("5:05 AM", "$165") rather than speech spelling.
  static String? verifyDisplay(String candidate, SpokenDraft draft) {
    final fallback = draft.displayFallbackText ?? draft.fallbackText;
    final mustInclude =
        draft.displayMustInclude.isNotEmpty ? draft.displayMustInclude : draft.mustInclude;
    return _verify(
      candidate,
      mustInclude: mustInclude,
      numberSources: [fallback, ...mustInclude],
      fallbackLength: fallback.length,
    );
  }

  static String? _verify(
    String candidate, {
    required List<String> mustInclude,
    required List<String> numberSources,
    required int fallbackLength,
  }) {
    final cleaned = SpeechTextFormatter.clean(candidate);
    if (cleaned.isEmpty) return null;
    final generous = (fallbackLength * 1.7).round();
    final limit = generous.clamp(160, hardMaxChars);
    if (cleaned.length > limit) return null;

    if (RegExp(r'\?').allMatches(cleaned).length > 1) return null;

    final normalized = _normalize(cleaned);
    for (final fragment in mustInclude) {
      final needle = _normalize(fragment);
      if (needle.isEmpty) continue;
      if (!normalized.contains(needle)) return null;
    }

    final permitted = _numbersIn(numberSources);
    for (final number in _numbersIn([cleaned])) {
      if (!permitted.contains(number)) return null;
    }

    return cleaned;
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
