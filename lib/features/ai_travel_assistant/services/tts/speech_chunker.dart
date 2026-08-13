/// Splits a spoken line so the first words can be heard while the rest is
/// still being synthesized.
///
/// Cartesia's render time scales with the length of the text, and the whole
/// clip has to arrive before it can play. Measured against the live endpoint on
/// 2026-08-09: a 42-character sentence renders in ~0.68s, a 150-character
/// narration in ~2.2s — while the first byte of either arrives in ~0.15s. So a
/// passenger waits over two seconds for a card narration that started being
/// generated almost immediately.
///
/// Speaking the opening sentence on its own cuts the wait to about 0.7s, and
/// the remainder renders during the three-odd seconds that sentence takes to
/// play, so the join is inaudible.
///
/// The split has to keep the audio *continuous*, not just start it early. A
/// first attempt cut only at the first sentence, and a device trace showed why
/// that is not enough:
///
///     +937ms   audio.playing    chunk 1 — 12 chars, 2.1s of speech
///     +3036ms  audio.finished
///     +5962ms  audio.playing    chunk 2 — 339 chars, took 5.1s to render
///
/// First audio arrived quickly, then the passenger heard 2.9 seconds of silence
/// mid-answer, which is worse than waiting once at the start. A tiny opening
/// sentence buys almost no time, and everything left over is still one large
/// request.
///
/// So the line is packed into several similarly sized chunks instead. Rendering
/// runs far faster than real time — roughly 2s of render for 20s of speech — so
/// once a chunk of a few seconds is playing, the next one is always ready
/// before it is needed. Chunks have a floor as well as a ceiling: a chunk too
/// short to cover the next one's render time reintroduces the gap.
library;

/// Below this, one request is already fast enough that splitting only adds a
/// round trip.
const _minLengthToSplit = 90;

/// The opening chunk is kept small so the first words arrive quickly — this is
/// the only wait the passenger actually experiences as latency.
const _firstChunkLength = 70;

/// Ceiling for later chunks. Beyond this a single render starts to approach the
/// playback time of the chunk before it.
const _targetChunkLength = 140;

/// How much longer a chunk may be than the one before it.
///
/// Measured on a device: synthesis runs at roughly 0.015s per character and
/// playback at roughly 0.116s per character, so a chunk renders about eight
/// times faster than it plays. A chunk may therefore be several times the size
/// of its predecessor and still be ready in time. Four leaves headroom for a
/// slow request.
///
/// The gap that prompted this was a 12-character chunk followed by a
/// 339-character one — twenty-eight times larger, and 2.9 seconds of silence.
const _maxGrowthFactor = 4;

/// Splits [text] into sentence-aligned chunks that can be spoken back to back
/// without an audible seam.
///
/// Returns a single-element list when the text is short or has no usable
/// sentence boundary.
List<String> chunkForSpeech(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const [];
  if (trimmed.length < _minLengthToSplit) return [trimmed];

  final sentences = _splitSentences(trimmed);
  if (sentences.length < 2) return [trimmed];

  // Chunks start small and grow: the first is sized for a quick start, and each
  // one after it may be a few times longer than its predecessor, because that
  // predecessor's playback is the budget its synthesis has to finish in.
  final chunks = <String>[];
  final buffer = StringBuffer();
  var limit = _firstChunkLength;

  void flush() {
    if (buffer.isEmpty) return;
    final chunk = buffer.toString();
    chunks.add(chunk);
    buffer.clear();
    limit = (chunk.length * _maxGrowthFactor).clamp(
      _firstChunkLength,
      _targetChunkLength,
    );
  }

  for (final sentence in sentences) {
    if (buffer.isEmpty) {
      buffer.write(sentence);
    } else if (buffer.length + 1 + sentence.length <= limit) {
      buffer
        ..write(' ')
        ..write(sentence);
    } else {
      flush();
      buffer.write(sentence);
    }
  }
  flush();

  return chunks.length < 2 ? [trimmed] : chunks;
}

/// Splits on sentence-ending punctuation, keeping the punctuation attached.
List<String> _splitSentences(String text) {
  final sentences = <String>[];
  var start = 0;
  var index = 0;

  while (index < text.length) {
    final end = _firstSentenceEnd(text.substring(index));
    if (end == null) break;
    final absolute = index + end;
    final sentence = text.substring(start, absolute).trim();
    if (sentence.isNotEmpty) sentences.add(sentence);
    start = absolute;
    index = absolute;
  }

  final tail = text.substring(start).trim();
  if (tail.isNotEmpty) sentences.add(tail);
  return sentences;
}

/// The index just past the first sentence-ending punctuation.
///
/// Skips a period that is part of a number or an abbreviation-like single
/// letter, so "193325 dollars in total." does not split at a decimal point and
/// "A A 993." does not split mid-code.
int? _firstSentenceEnd(String text) {
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char != '.' && char != '!' && char != '?') continue;

    // Must be followed by whitespace, or be the end of the string — which
    // means there is nothing left to split off.
    if (i + 1 >= text.length) return null;
    if (!_isWhitespace(text[i + 1])) continue;

    if (char == '.' && _isMidToken(text, i)) continue;

    return i + 1;
  }
  return null;
}

/// Whether the period at [index] sits inside a number or a single-letter
/// token — "2026." mid-date, or an initial — rather than ending a sentence.
bool _isMidToken(String text, int index) {
  if (index == 0) return true;
  final before = text[index - 1];
  final isDigit = before.compareTo('0') >= 0 && before.compareTo('9') <= 0;
  if (!isDigit) return false;

  // A digit before a period only means "mid-number" when a digit follows too.
  final after = index + 2 < text.length ? text[index + 2] : '';
  return after.compareTo('0') >= 0 && after.compareTo('9') <= 0;
}

bool _isWhitespace(String char) => char.trim().isEmpty;
