import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/voice_transcript_rules.dart';

void main() {
  group('affirmations', () {
    test('plain approvals are recognized regardless of punctuation or case', () {
      for (final said in ['yes', 'Yes.', 'YEAH', 'go ahead', 'Book it!', 'ok']) {
        expect(isAffirmation(said), isTrue, reason: said);
      }
    });

    test('approvals with the words people actually use around them', () {
      // Nobody says a bare "yes". Matching only fixed phrases missed every one
      // of these, which would have sent them to the backend as fresh requests
      // and left the confirmation unanswered.
      for (final said in [
        'yes, go ahead',
        'yeah do it',
        'okay, book it',
        'yes please',
        'sure, that works',
        'yep sounds good',
        'ok go ahead please',
      ]) {
        expect(isAffirmation(said), isTrue, reason: said);
      }
    });

    test('a qualified yes is not an approval', () {
      // This is the case that costs money if it is got wrong: treating it as
      // approval books the flight the passenger was about to change.
      for (final said in [
        'yes but change the date first',
        'yes to the second one',
        'I think so',
        'yes if it is still under 200 dollars',
      ]) {
        expect(isAffirmation(said), isFalse, reason: said);
      }
    });

    test('declines are recognized', () {
      for (final said in ['no', 'Nope', 'not now', 'never mind', 'cancel that']) {
        expect(isDecline(said), isTrue, reason: said);
      }
    });

    test('nothing is both an approval and a decline', () {
      for (final said in ['yes', 'no', 'ok', 'stop', 'book it']) {
        expect(isAffirmation(said) && isDecline(said), isFalse, reason: said);
      }
    });
  });

  group('echo guard', () {
    const spoken = 'Your gate is B twelve and boarding starts at ten past five.';

    test('catches the assistant heard back immediately after speaking', () {
      expect(
        looksLikeEcho(
          'your gate is B twelve',
          spoken,
          sinceReopened: const Duration(milliseconds: 120),
        ),
        isTrue,
      );
    });

    test('lets a genuine reply through even if it shares words', () {
      expect(
        looksLikeEcho(
          'change my gate to something closer',
          spoken,
          sinceReopened: const Duration(milliseconds: 120),
        ),
        isFalse,
      );
    });

    test('does not suppress the passenger repeating themselves later', () {
      // Both signals are required. After the window, an overlapping phrase is
      // the passenger genuinely saying it, and dropping it would look like the
      // assistant ignoring them.
      expect(
        looksLikeEcho(
          'your gate is B twelve',
          spoken,
          sinceReopened: const Duration(seconds: 3),
        ),
        isFalse,
      );
    });

    test('is inert when the assistant has not said anything yet', () {
      expect(
        looksLikeEcho(
          'check me in',
          '',
          sinceReopened: const Duration(milliseconds: 50),
        ),
        isFalse,
      );
    });
  });

  group('silence errors', () {
    test('a passenger saying nothing is not treated as a fault', () {
      expect(isSilenceError('error_speech_timeout'), isTrue);
      expect(isSilenceError('error_no_match'), isTrue);
    });

    test('a real recognizer fault is', () {
      expect(isSilenceError('error_audio'), isFalse);
      expect(isSilenceError('error_client'), isFalse);
    });
  });
}
