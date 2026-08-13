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

  group('answering in the words of the question', () {
    const cancelling = 'cancel my booking';
    const booking = 'book it';
    const upgrading = 'upgrade to Business';

    test('approves a cancellation in its own words', () {
      // "Yes, cancel it" is the backend's own suggested chip for this turn.
      // Without the pending action it matched neither classifier and was posted
      // as a brand new request, silently dropping the cancellation.
      for (final said in [
        'yes cancel it',
        'yeah cancel it',
        'yes please cancel',
      ]) {
        expect(
          isAffirmation(said, pendingAction: cancelling),
          isTrue,
          reason: '"$said" should approve a pending cancellation',
        );
        expect(isDecline(said, pendingAction: cancelling), isFalse);
      }
    });

    test('approves an upgrade in its own words', () {
      expect(isAffirmation('yes upgrade me', pendingAction: upgrading), isTrue);
      expect(isAffirmation('yes upgrade it', pendingAction: upgrading), isTrue);
    });

    test('the action verb is allowed only for its own gate', () {
      // The dangerous direction. While a *booking* waits for approval, "yes,
      // cancel it" means the opposite of yes — it must not approve the booking
      // the passenger is trying to stop.
      expect(isAffirmation('yes cancel it', pendingAction: booking), isFalse);
      expect(isDecline('no cancel it', pendingAction: booking), isTrue);
    });

    test('refusing in the words of the question still declines', () {
      expect(isDecline('no dont cancel it', pendingAction: cancelling), isTrue);
      expect(isAffirmation('no dont cancel it', pendingAction: cancelling),
          isFalse);
    });

    test('a bare yes still works for every gate', () {
      for (final action in [cancelling, booking, upgrading]) {
        expect(isAffirmation('yes', pendingAction: action), isTrue);
        expect(isDecline('no', pendingAction: action), isTrue);
      }
    });

    test('a qualified yes is still not an approval', () {
      // The safety property the whole classifier exists for: any unrecognized
      // word disqualifies the utterance, and widening the vocabulary must not
      // erode it. This is the one place in the journey that spends money.
      expect(
        isAffirmation('yes but change the date first', pendingAction: booking),
        isFalse,
      );
      expect(
        isAffirmation('yes cancel it and rebook', pendingAction: cancelling),
        isFalse,
      );
    });

    test('with nothing pending it behaves exactly as before', () {
      expect(isAffirmation('yes cancel it'), isFalse);
      expect(isAffirmation('yes'), isTrue);
      expect(isDecline('no thanks'), isTrue);
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
