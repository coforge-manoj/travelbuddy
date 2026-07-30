import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/spoken_draft.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/spoken_fact_guard.dart';

const _offers = SpokenDraft(
  topic: SpokenTopic.flightOffers,
  clauses: [
    'there are 2 flights from Newark to Chicago',
    'the lowest fare is Delta Air Lines at 176 dollars, departing 12 30 in the afternoon',
  ],
  invitation: SpokenInvitation.chooseOffer,
  mustInclude: ['Delta Air Lines', '176 dollars'],
  fallbackText: 'I found 2 flights from Newark to Chicago. The cheapest is Delta Air Lines '
      'at 176 dollars, departing 12 30 in the afternoon. '
      "You're welcome to name an airline, or ask for the cheapest one.",
);

void main() {
  group('accepts', () {
    test('a rewording that keeps every fact', () {
      const candidate = 'Good news — there are 2 flights from Newark to Chicago, and the '
          'lowest fare is Delta Air Lines at 176 dollars. Shall I book that one?';

      expect(SpokenFactGuard.verify(candidate, _offers), isNotNull);
    });

    test('a fragment whose case and spacing differ from the formatter output', () {
      const candidate = 'There are 2 flights to Chicago, the best being  delta air lines '
          'at 176   Dollars. Would you like it?';

      expect(SpokenFactGuard.verify(candidate, _offers), isNotNull);
    });

    test('numbers that appear only in the fallback text', () {
      const candidate = 'Delta Air Lines at 176 dollars leaves at 12 30 in the afternoon. '
          'Shall I take it?';

      expect(SpokenFactGuard.verify(candidate, _offers), isNotNull);
    });

    test('and returns speech-ready text with markdown stripped', () {
      const candidate = '**Delta Air Lines** at 176 dollars — a good fare. Book it?';

      expect(
        SpokenFactGuard.verify(candidate, _offers),
        'Delta Air Lines at 176 dollars, a good fare. Book it?',
      );
    });
  });

  group('rejects', () {
    test('a dropped fare', () {
      const candidate = 'There are 2 flights to Chicago, and Delta is the cheapest. '
          'Shall I book it?';

      expect(SpokenFactGuard.verify(candidate, _offers), isNull);
    });

    test('an invented number, even alongside the correct one', () {
      const candidate = 'Delta Air Lines at 176 dollars, or about 180 dollars with bags. '
          'Shall I book it?';

      expect(SpokenFactGuard.verify(candidate, _offers), isNull);
    });

    test('a second question, which leaves the passenger unsure what to answer', () {
      const candidate = 'Delta Air Lines at 176 dollars. Shall I book it? Or another airline?';

      expect(SpokenFactGuard.verify(candidate, _offers), isNull);
    });

    test('a phrasing that rambles well past the deterministic one', () {
      final candidate = 'Delta Air Lines at 176 dollars. ${'Lovely weather for it. ' * 12}';

      expect(SpokenFactGuard.verify(candidate, _offers), isNull);
    });

    test('nothing to say', () {
      expect(SpokenFactGuard.verify('   ', _offers), isNull);
      expect(SpokenFactGuard.verify('**', _offers), isNull);
    });
  });

  test('a spelled-out code has to survive intact', () {
    const confirmation = SpokenDraft(
      topic: SpokenTopic.bookingConfirmed,
      tone: SpokenTone.celebratory,
      clauses: ['your confirmation code is A B 7 4 Q Z'],
      mustInclude: ['A B 7 4 Q Z'],
      fallbackText: "You're all set. Your confirmation is A B 7 4 Q Z.",
    );

    expect(
      SpokenFactGuard.verify('Wonderful — your confirmation code is A B 7 4 Q Z.', confirmation),
      isNotNull,
    );
    // Run together, the engine reads this as an unintelligible word.
    expect(
      SpokenFactGuard.verify('Wonderful — your confirmation code is AB74QZ.', confirmation),
      isNull,
    );
  });
}
