import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/acknowledgement_composer.dart';

void main() {
  /// Seeded, so a phrasing test asserts on one sentence rather than on every
  /// sentence the pools could have produced.
  AcknowledgementComposer composer([int seed = 7]) =>
      AcknowledgementComposer(random: Random(seed));

  group('reading the request back', () {
    test('turns a polite request into something it will go and do', () {
      final line = composer().compose('Can you help me with my trip details');

      // The passenger's own words, from the assistant's side of the
      // conversation: "help me with my" becomes "help you with your".
      expect(line, contains('help you with your trip details'));
    });

    test('reflects a first-person request', () {
      final line = composer().compose('I want to change my seat');

      expect(line, contains('change your seat'));
    });

    test('reflects a bare instruction as given', () {
      final line = composer().compose('Show me my bookings');

      expect(line, contains('show you your bookings'));
    });

    test('strips the fillers people open with', () {
      final line = composer().compose('Okay so can you book a flight to Delhi');

      expect(line, contains('book a flight to delhi'));
      expect(line, isNot(contains('okay so can you')));
    });
  });

  group('questions', () {
    test('names what was asked about', () {
      final line = composer().compose("What's my gate number");

      expect(line, contains('your gate number'));
    });

    test('keeps the verb out of the noun it repeats back', () {
      // The trap: "my flight leave" is a noun and a verb, and taking both
      // produces "you want to know about your flight leave".
      final line = composer().compose('When does my flight leave');

      expect(line, contains('your flight'));
      expect(line, isNot(contains('flight leave')));
    });

    test('says something plain when the question names nothing of theirs', () {
      final line = composer().compose("What's the weather in Paris");

      // No reflection is attempted rather than a mangled one, but the wait is
      // still filled — silence is the thing being fixed.
      expect(line, isNot(contains('you want')));
      expect(line.toLowerCase(), anyOf(contains('weather'), contains('forecast')));
    });
  });

  group('what it refuses to reword', () {
    test('leaves a long ramble unreflected', () {
      final line = composer().compose(
        'I want to fly from London to Tokyo next Tuesday morning but only if '
        'the aisle seats near the front are still free on the direct one',
      );

      expect(line, isNot(contains('you want me to')));
      expect(line.trim(), isNotEmpty);
    });

    test('says nothing at all for an empty transcript', () {
      expect(composer().compose('   '), isEmpty);
    });

    test('never leaves the passenger with a bare opener', () {
      // Every shape, reflected or not, ends with what happens next.
      for (final request in [
        'hmm',
        'the blue one',
        'tomorrow',
        'yes please do that thing we discussed',
      ]) {
        final line = composer().compose(request);
        expect(line.split(' ').length, greaterThan(3), reason: request);
        expect(line.trim(), endsWith('.'), reason: request);
      }
    });
  });

  group('confirmations', () {
    test('a yes is heard as landing, not as a new request', () {
      final line = composer().compose('yes go ahead', confirming: true);

      // Nothing to reflect in a "yes" — what matters is that the approval
      // registered, on the one turn that spends money.
      expect(line.toLowerCase(), anyOf(contains('confirm'), contains('ahead'),
          contains('putting that through')));
      expect(line, isNot(contains('you want me to')));
    });

    test('an upgrade quote names the yes and the no', () {
      final line = composer().composeConfirmationOptions(
        stageId: 'quote_upgrade',
      );

      expect(line.toLowerCase(), contains('yes to upgrade'));
      expect(line.toLowerCase(), contains('stay in your current cabin'));
    });

    test('checkout names booking, not a generic go ahead', () {
      final line = composer().composeConfirmationOptions(stageId: 'checkout');

      expect(line.toLowerCase(), contains('yes to book it'));
      expect(line.toLowerCase(), contains('leave it unbooked'));
    });
  });

  group('not sounding like a script', () {
    test('does not open two turns in a row the same way', () {
      final subject = composer();

      final lines = List.generate(
        8,
        (i) => subject.compose('what is my seat number'),
      );

      for (var i = 1; i < lines.length; i++) {
        expect(lines[i], isNot(equals(lines[i - 1])));
      }
    });

    test('the same request twice in a row is worded differently', () {
      final subject = composer();

      expect(
        subject.compose('check my baggage allowance'),
        isNot(equals(subject.compose('check my baggage allowance'))),
      );
    });

    test('names what it is about to look at when it can tell', () {
      expect(
        composer().compose('change my seat to 14C').toLowerCase(),
        contains('seat'),
      );
      expect(
        composer().compose('how much baggage can I take').toLowerCase(),
        contains('baggage'),
      );
    });
  });

  group('spoken suggestions', () {
    test('frames the follow-ups as words to say', () {
      // A chip is written in the passenger's voice, so "You could show me
      // cheaper options" asks the passenger to do the showing. Only the "say
      // it" frame keeps a passenger-voiced label grammatical in the
      // assistant's mouth.
      final line = composer().composeSuggestionLine(
        ['Check me in', 'Show me cheaper options'],
      );

      expect(line, contains('check me in, or show me cheaper options.'));
      expect(line, contains('say'));
    });

    test('a lone follow-up gets the same frame', () {
      final line = composer().composeSuggestionLine(['Check me in']);

      expect(line, endsWith('check me in.'));
      expect(line, contains('say'));
    });

    test('reads at most two, however many the backend sends', () {
      // The backend routinely sends four. Reading a menu back after every
      // answer turns a conversation into a phone tree.
      final line = composer().composeSuggestionLine([
        'Book the recommended one',
        'Show me cheaper options',
        'Check me in',
        'My trip details',
      ]);

      expect(line, isNot(contains('Check me in')));
      expect(line, isNot(contains('trip details')));
    });

    test('leaves an acronym alone', () {
      expect(
        composer().composeSuggestionLine(['PNR lookup']),
        endsWith('PNR lookup.'),
      );
    });

    test('says nothing when there is nothing to offer', () {
      expect(composer().composeSuggestionLine([]), '');
      expect(composer().composeSuggestionLine(['', '  ']), '');
    });
  });

  group('refusals', () {
    test('a decline is answered out loud', () {
      final line = composer().composeDecline();

      expect(line, isNotEmpty);
      expect(AcknowledgementComposer.declineLines, contains(line));
    });

    test('a lapsed approval is stated before the new request', () {
      final line = composer().composeDropped('Sure, let me check that.');

      expect(
        AcknowledgementComposer.droppedNotes.any(line.startsWith),
        isTrue,
        reason: 'got "$line"',
      );
      expect(line, endsWith('Sure, let me check that.'));
    });

    test('a lapsed approval stands alone when there is nothing to add', () {
      final line = composer().composeDropped('');
      expect(AcknowledgementComposer.droppedNotes, contains(line));
    });
  });
}
