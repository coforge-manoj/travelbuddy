import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/speech_summarizer.dart';

void main() {
  const summarizer = FallbackSpeechSummarizer();

  group('FallbackSpeechSummarizer.stripForSpeech', () {
    test('removes markdown emphasis that would otherwise be read aloud', () {
      final spoken = FallbackSpeechSummarizer.stripForSpeech(
        '**Flight UA482** is currently _delayed_.',
      );

      expect(spoken, 'Flight UA482 is currently delayed.');
    });

    test('keeps link text and drops the target', () {
      final spoken = FallbackSpeechSummarizer.stripForSpeech(
        'See the [baggage policy](https://example.com/bags) for details.',
      );

      expect(spoken, 'See the baggage policy for details.');
    });

    test('strips emoji and list bullets', () {
      final spoken = FallbackSpeechSummarizer.stripForSpeech(
        '- 📍 Tokyo, Japan\n- ✈️ Nonstop',
      );

      expect(spoken, 'Tokyo, Japan Nonstop');
    });

    test('removes separator rules between list items', () {
      final spoken = FallbackSpeechSummarizer.stripForSpeech(
        '📍 Kyoto, Japan\n'
        '------------------------------\n'
        '📍 Osaka, Japan',
      );

      expect(spoken, isNot(contains('-')));
      expect(spoken, 'Kyoto, Japan Osaka, Japan');
    });

    test('preserves the numbers that matter', () {
      final spoken = FallbackSpeechSummarizer.stripForSpeech(
        '**Seat 14A** · PNR TB417290 · \$189',
      );

      expect(spoken, contains('14A'));
      expect(spoken, contains('TB417290'));
      expect(spoken, contains(r'$189'));
    });
  });

  group('FallbackSpeechSummarizer.condense', () {
    test('speaks a whole multi-message turn rather than its first line', () {
      // What a burst-joined turn looks like: summary, list, follow-up. The
      // caps used to keep the first sentence and the question and silently
      // drop everything in between.
      final spoken = summarizer.condense(
        'Tokyo in April is lovely for cherry blossoms. '
        'Kyoto, Osaka and Tokyo are all strong picks that month. '
        'Late March to early April is the window. '
        'Would you like me to look at flights?',
      );

      expect(spoken, contains('Kyoto, Osaka and Tokyo'));
      expect(spoken, contains('Late March to early April'));
      expect(spoken, endsWith('Would you like me to look at flights?'));
    });

    test('keeps only the first sentences once past the sentence cap', () {
      const summarizer = FallbackSpeechSummarizer(maxSentences: 2);
      final spoken = summarizer.condense(
        'Your flight is on time. Boarding starts at 6:15. '
        'Gate C14 is on the upper level. Please arrive early.',
      );

      expect(spoken, 'Your flight is on time. Boarding starts at 6:15.');
    });

    test('leaves a short single-sentence reply untouched', () {
      final spoken = summarizer.condense('Pick a seat below.');

      expect(spoken, 'Pick a seat below.');
    });

    test('ends on a sentence boundary past the character cap', () {
      const summarizer = FallbackSpeechSummarizer(maxCharacters: 40);
      final spoken = summarizer.condense(
        'Your flight is on time. Boarding starts at 6:15 from gate C14.',
      );

      // Stops where a sentence stops — no dangling clause, no ellipsis.
      expect(spoken, 'Your flight is on time.');
      expect(spoken, isNot(endsWith('…')));
    });

    test('truncates on a word boundary when no sentence ends in range', () {
      const summarizer = FallbackSpeechSummarizer(maxCharacters: 20);
      final spoken = summarizer.condense(
        'Boarding begins shortly at the international terminal',
      );

      expect(spoken.length, lessThanOrEqualTo(21)); // + ellipsis
      expect(spoken, endsWith('…'));
      expect(spoken, isNot(contains('  ')));
      // Never cuts mid-word.
      expect(spoken, 'Boarding begins…');
    });

    test('empty and whitespace-only input yield nothing to speak', () {
      expect(summarizer.condense(''), '');
      expect(summarizer.condense('   \n  '), '');
      expect(summarizer.condense('**  **'), '');
    });

    test('summarize delegates to condense', () async {
      final spoken = await summarizer.summarize(
        '**Done!** Your bag is added. Seat 14A is confirmed. Anything else?',
      );

      expect(spoken, 'Done! Your bag is added. Seat 14A is confirmed. Anything else?');
    });

    test('prefers a trailing question over only the opening sentences', () {
      const summarizer = FallbackSpeechSummarizer(maxSentences: 2);
      final spoken = summarizer.condense(
        'Tokyo in April is lovely.\n\n'
        'Here are three destinations to consider.\n\n'
        'Would you like me to look at flights?',
      );

      expect(spoken, startsWith('Tokyo in April is lovely.'));
      expect(spoken, endsWith('Would you like me to look at flights?'));
      expect(spoken, isNot(contains('three destinations')));
    });

    test('keeps an ellipsis filler attached to the first sentence', () {
      const summarizer = FallbackSpeechSummarizer(maxSentences: 2);
      final spoken = summarizer.condense(
        'Ok... I found a few flights from Newark to Chicago. '
        'Which one looks good? Extra detail we do not need.',
      );

      expect(spoken, startsWith('Ok… I found a few flights'));
      expect(spoken, endsWith('Which one looks good?'));
      expect(spoken, isNot(contains('Extra detail')));
    });
  });
}
