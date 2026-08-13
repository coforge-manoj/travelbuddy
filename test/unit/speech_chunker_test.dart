import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/speech_chunker.dart';

void main() {
  test('short lines are not split — one request is already fast', () {
    expect(chunkForSpeech('Booked. Your gate is B twelve.'), hasLength(1));
  });

  test('a long narration is split at a sentence boundary', () {
    final chunks = chunkForSpeech(
      '105 flights all time, 193325 dollars in total. Most recently flight '
      'A A 993 on 2026-07-21, D F W to L H R in Flagship Business.',
    );

    expect(chunks, hasLength(2));
    expect(chunks.first, endsWith('in total.'));
    expect(chunks.last, startsWith('Most recently'));
  });

  test('no chunk is large enough to underrun the one before it', () {
    // The device trace that prompted this: a 12-character opening sentence
    // bought 2.1s of playback while the 339-character remainder took 5.1s to
    // render — 28x larger — so the passenger heard 2.9s of silence mid-answer.
    // Each chunk's playback is the budget the next one's synthesis has to
    // finish in, so growth is what has to be bounded, not absolute size.
    final chunks = chunkForSpeech(
      'Booked. Your reference is F C L D 3 Q. American Airlines flight A A 50, '
      'D F W to L H R, Main Cabin Extra, seat 12 A, 1189 dollars and 50 cents. '
      'You earned 3200 miles. Boarding is at 17:15 from gate 25, terminal B, '
      'and your boarding group is group 2.',
    );

    expect(chunks.length, greaterThan(1));
    for (var i = 1; i < chunks.length; i++) {
      expect(
        chunks[i].length,
        lessThanOrEqualTo(chunks[i - 1].length * 4),
        reason: 'chunk ${i + 1} outgrows its predecessor: "${chunks[i]}"',
      );
    }
  });

  test('the opening chunk is small, so the first words arrive quickly', () {
    final chunks = chunkForSpeech(
      'Booked. Your reference is F C L D 3 Q. American Airlines flight A A 50, '
      'D F W to L H R, Main Cabin Extra, seat 12 A, 1189 dollars and 50 cents. '
      'You earned 3200 miles.',
    );

    // The wait before the first chunk is the only one heard as latency; every
    // later chunk renders while its predecessor plays.
    expect(chunks.first.length, lessThanOrEqualTo(70));
  });

  test('chunks stay near the target size so each renders ahead of playback', () {
    final chunks = chunkForSpeech(
      'One sentence here. Another sentence follows it. A third one arrives. '
      'A fourth continues the list. A fifth keeps going. A sixth finishes up.',
    );

    for (final chunk in chunks) {
      expect(chunk.length, lessThanOrEqualTo(200), reason: chunk);
    }
  });

  test('the split loses nothing', () {
    const line =
        'Booked. Your reference is F C L D 3 Q. American Airlines flight A A 50, '
        'D F W to L H R, Main Cabin Extra, seat 12 A, 1189 dollars and 50 cents.';
    final chunks = chunkForSpeech(line);

    final rejoined = chunks.join(' ');
    for (final fragment in ['F C L D 3 Q', '12 A', '1189 dollars']) {
      expect(rejoined, contains(fragment));
    }
  });

  test('a decimal point is not mistaken for the end of a sentence', () {
    final chunks = chunkForSpeech(
      'The total came to 1189.50 dollars for this booking, which covers the fare '
      'and every extra you added along the way.',
    );

    // Splitting at "1189." would speak a fragment ending mid-number.
    expect(chunks.first, isNot(endsWith('1189.')));
  });

  test('a line with no sentence boundary stays whole', () {
    final chunks = chunkForSpeech(
      'a very long line without any terminating punctuation at all which simply '
      'keeps going and going without ever stopping anywhere',
    );

    expect(chunks, hasLength(1));
  });

  test('a trailing period with nothing after it is not a split point', () {
    final chunks = chunkForSpeech(
      'This is one long single sentence that runs past the split threshold and '
      'then simply ends right here.',
    );

    // Splitting would leave an empty second chunk and a wasted request.
    expect(chunks, hasLength(1));
  });

  test('empty input produces nothing to say', () {
    expect(chunkForSpeech(''), isEmpty);
    expect(chunkForSpeech('   '), isEmpty);
  });
}
