import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/services/speech_prosody_planner.dart';

void main() {
  group('SpeechProsodyPlanner.plan', () {
    test('returns empty for blank input', () {
      expect(SpeechProsodyPlanner.plan(''), isEmpty);
      expect(SpeechProsodyPlanner.plan('   '), isEmpty);
    });

    test('splits on sentence boundaries and keeps terminators', () {
      final segments = SpeechProsodyPlanner.plan(
        'I found one flight. Would you like me to book it for you?',
      );

      expect(segments.map((s) => s.text), [
        'I found one flight.',
        'Would you like me to book it for you?',
      ]);
    });

    test('questions stay one segment with a light pitch nudge', () {
      final segment = SpeechProsodyPlanner.plan('Would you like a window seat?').single;

      expect(segment.pitch, SpeechProsodyPlanner.questionPitch);
      expect(segment.rate, SpeechProsodyPlanner.questionRate);
    });

    test('interrogatives without a question mark still get question prosody', () {
      final segment = SpeechProsodyPlanner.plan('Shall I go ahead and book that.').single;

      expect(segment.pitch, SpeechProsodyPlanner.questionPitch);
    });

    test('soft apology openers get a lower pitch and slower rate', () {
      final segment = SpeechProsodyPlanner.plan(
        "I'm sorry, I couldn't find any flights on that route.",
      ).single;

      expect(segment.pitch, SpeechProsodyPlanner.softPitch);
      expect(segment.rate, SpeechProsodyPlanner.softRate);
    });

    test('dense spelled codes get a slower rate', () {
      final segment = SpeechProsodyPlanner.plan(
        'Flight U A 4 8 2 is boarding.',
      ).single;

      expect(segment.pitch, SpeechProsodyPlanner.densePitch);
      expect(segment.rate, SpeechProsodyPlanner.denseRate);
    });

    test('plain statements use the default pitch and rate', () {
      final segment = SpeechProsodyPlanner.plan(
        'The cheapest is Emirates at 189 dollars.',
      ).single;

      expect(segment.pitch, SpeechProsodyPlanner.statementPitch);
      expect(segment.rate, SpeechProsodyPlanner.statementRate);
    });

    test('question ending wins over a soft opener', () {
      final segment = SpeechProsodyPlanner.plan(
        "I'm sorry, would you like to try another date?",
      ).single;

      expect(segment.pitch, SpeechProsodyPlanner.questionPitch);
    });

    test('a mixed turn gets per-sentence styles', () {
      final segments = SpeechProsodyPlanner.plan(
        "I'm sorry, that purchase didn't go through. "
        'Would you like to try again?',
      );

      expect(segments, hasLength(2));
      expect(segments[0].pitch, SpeechProsodyPlanner.softPitch);
      expect(segments[1].pitch, SpeechProsodyPlanner.questionPitch);
    });
  });
}
