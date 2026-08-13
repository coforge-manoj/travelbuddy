/// Turns an on-screen assistant message into the line we actually speak.
///
/// Screen text and spoken text have different jobs: a bubble can carry
/// markdown, emoji and four sentences of detail, while speech needs one or
/// two plain sentences that land on first hearing.
abstract class SpeechSummarizer {
  Future<String> summarize(String text);
}

/// Deterministic, offline summarizer: strips anything that reads badly aloud
/// and keeps the opening sentences.
///
/// Used on its own when LLM summarization is disabled, and as the fallback
/// whenever the model call fails or times out — so speech never depends on
/// the network being healthy.
class FallbackSpeechSummarizer implements SpeechSummarizer {
  /// The caps are sized for a whole turn, not one bubble. They were originally
  /// 2 sentences / 240 characters, which fit a single reply — but a handler
  /// that posts a summary, a list and a follow-up question has those three
  /// joined into one input before it gets here, and the old caps then dropped
  /// the middle of the turn and cut the remainder mid-word.
  const FallbackSpeechSummarizer({
    this.maxSentences = 4,
    this.maxCharacters = 600,
  });

  final int maxSentences;
  final int maxCharacters;

  @override
  Future<String> summarize(String text) async => condense(text);

  /// Synchronous so other summarizers can reuse it to clean up model output.
  String condense(String text) {
    final cleaned = stripForSpeech(text);
    if (cleaned.isEmpty) return '';

    // Keep "Ok…" as one unit — ASCII `...` would otherwise split on each dot.
    final forSplit = cleaned.replaceAll('...', '…');
    final sentences = RegExp(r'[^.!?]+[.!?]*')
        .allMatches(forSplit)
        .map((match) => match.group(0)!.trim())
        .where((sentence) => sentence.isNotEmpty)
        .toList();

    final kept = sentences.isEmpty
        ? forSplit
        : _pickSentences(sentences);

    return _trimToMax(kept);
  }

  /// Keeps up to [maxSentences], preferring a trailing question when the input
  /// is longer than that — so a joined sync-burst (summary + options + ask)
  /// still ends with the passenger-facing question instead of only the opener.
  String _pickSentences(List<String> sentences) {
    if (sentences.length <= maxSentences) {
      return sentences.join(' ');
    }

    final trailing = sentences.last;
    if (trailing.endsWith('?') && maxSentences >= 2) {
      final lead = sentences.take(maxSentences - 1).join(' ');
      return '$lead $trailing';
    }

    return sentences.take(maxSentences).join(' ');
  }

  String _trimToMax(String kept) {
    if (kept.length <= maxCharacters) return kept;

    final hardCut = kept.substring(0, maxCharacters);

    // Prefer ending where a sentence ends. Stopping mid-clause is what makes
    // speech sound cut off — an ellipsis doesn't rescue it, it announces it.
    final lastSentenceEnd = hardCut.lastIndexOf(RegExp(r'[.!?]'));
    if (lastSentenceEnd > 0) {
      return hardCut.substring(0, lastSentenceEnd + 1).trim();
    }

    // No sentence ended in range — one very long run-on. Cut on a word
    // boundary and mark it, which is the honest option left.
    final lastSpace = hardCut.lastIndexOf(' ');
    return '${lastSpace > 0 ? hardCut.substring(0, lastSpace) : hardCut}…';
  }

  /// Removes markdown, emoji and list scaffolding — all of which either get
  /// read out literally ("asterisk asterisk delayed") or leave odd gaps.
  static String stripForSpeech(String text) {
    return text
        // Keep the link text, drop the target. `replaceAll` would insert a
        // literal "$1" here — group substitution needs the mapped variant.
        .replaceAllMapped(
          RegExp(r'\[(.*?)\]\(.*?\)'),
          (match) => match.group(1) ?? '',
        )
        // Separator rules between list items. Stripped before the bullet rule
        // below, which only ever removed the first dash of a run and left the
        // other twenty-nine sitting in the spoken text.
        .replaceAll(RegExp(r'[-_=]{3,}'), ' ')
        .replaceAll(RegExp(r'[*_`#>]'), '')
        .replaceAll(RegExp(r'^\s*[-•·]\s*', multiLine: true), '')
        .replaceAll(
          RegExp(
            r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{2190}-\u{21FF}]',
            unicode: true,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
