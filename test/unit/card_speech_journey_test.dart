import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/chat_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/card_speech_text_builder.dart';

/// Narration of the live journey cards.
///
/// Payloads are put through [ChatCardMapper] rather than constructed directly,
/// and are the same captures pinned in `journey_live_payloads_test.dart` — so a
/// backend field that moves breaks the narration test too, instead of the
/// narration quietly describing an entity nobody builds any more.
void main() {
  const builder = CardSpeechTextBuilder();

  /// Builds a card the way a real turn does and returns what would be spoken.
  ///
  /// [needsConfirmation] is the turn-level flag, not a card field — it is what
  /// decides whether a cancellation reads as "shall I?" or "done".
  String? speak(
    Map<String, Object?> card, {
    String caption = '',
    bool needsConfirmation = false,
  }) {
    final cards = ChatCardMapper.fromResponse(
      [card],
      needsConfirmation: needsConfirmation,
    );
    if (cards.isEmpty) return null;
    return builder
        .build(
          ChatMessage(
            id: 'x',
            role: ChatRole.assistant,
            type: cards.single.type,
            timestamp: DateTime(2026),
            text: caption,
            payload: cards.single.payload,
          ),
        )
        ?.text;
  }

  group('booking', () {
    const bookingCard = <String, Object?>{
      'type': 'booking_confirmed',
      'ok': true,
      'pnr': 'FCLD3Q',
      'bookingId': 167,
      'flight': {
        'flightNo': 'AA50',
        'origin': 'DFW',
        'dest': 'LHR',
        'date': '2027-06-10',
        'dep': '17:55',
        'arr': '09:05',
      },
      'cabin': 'Main Cabin Extra',
      'pax': 1,
      'seat': '12A',
      'total': 1189.50,
      'milesEarned': 3200,
    };

    test('spells the PNR out letter by letter', () {
      final spoken = speak(bookingCard)!;

      // "5QW08HB" read as letter/digit groups is unwritable-down. Every
      // character has to stand alone.
      expect(spoken, contains('F C L D 3 Q'));
      expect(spoken, isNot(contains('FCLD3Q')));
    });

    test('speaks the fare including cents', () {
      final spoken = speak(bookingCard)!;

      // Rounding a fare to whole units quietly misstates the price.
      expect(spoken, contains('1189 dollars and 50 cents'));
    });

    test('never derives a duration from the departure and arrival times', () {
      final spoken = speak(bookingCard)!;

      // DFW 17:55 → LHR 09:05 are each local to their own airport. Subtracting
      // them gives 15h10 for a flight that takes 9h05.
      expect(spoken, isNot(contains('hour')));
      expect(spoken, isNot(contains('minute')));
      expect(spoken, isNot(contains('15')));
    });

    test('reads the seat as a seat, not as a word', () {
      expect(speak(bookingCard)!, contains('12 A'));
    });
  });

  group('boarding pass', () {
    // Verbatim capture: this card carries no route at all, and several fields
    // that are optional everywhere else.
    const boardingPassCard = <String, Object?>{
      'type': 'boarding_pass',
      'pnr': 'FCLD3Q',
      'flightNo': 'AA50',
      'date': '2027-06-10',
      'seat': '12A',
      'cabin': 'Main Cabin Extra',
      'gate': '25',
      'terminal': 'B',
      'boardingTime': '17:15',
      'boardingGroup': 'Group 2',
      'sequence': 4,
      'barcode': 'M1FCLD3Q504717',
    };

    test('speaks gate, terminal, seat and boarding time', () {
      final spoken = speak(boardingPassCard)!;

      expect(spoken, contains('gate 25'));
      expect(spoken, contains('Terminal B'));
      expect(spoken, contains('Seat 12 A'));
      expect(spoken, contains('17:15'));
      // "Group 2" is a phrase, not a code — spelling it out gives "G r o u p".
      expect(spoken, contains('group 2'));
      expect(spoken, isNot(contains('G r o u p')));
    });

    test('copes with a capture that has no passenger name and no route', () {
      // This is the real captured shape: the boarding pass card carries
      // neither, so the sentence must not open with a stray comma or say
      // "to" with nothing either side of it.
      final spoken = speak(boardingPassCard)!;

      expect(spoken, startsWith('flight A A 50'));
      expect(spoken, isNot(contains(' to  ')));
      expect(spoken, isNot(contains(', ,')));
    });

    test('never reads out the barcode or sequence number', () {
      final spoken = speak(boardingPassCard)!;

      // Unspeakable, and useless out loud — the passenger scans it.
      expect(spoken, isNot(contains('M1FCLD3Q504717')));
      expect(spoken.toLowerCase(), isNot(contains('sequence')));
    });

    test('omits missing fields rather than saying "null"', () {
      final spoken = speak(<String, Object?>{
        'type': 'boarding_pass',
        'pnr': 'FCLD3Q',
        'flightNo': 'AA50',
        'cabin': 'Main',
      })!;

      expect(spoken.toLowerCase(), isNot(contains('null')));
      expect(spoken.toLowerCase(), isNot(contains('gate')));
      expect(spoken.toLowerCase(), isNot(contains('terminal')));
    });
  });

  group('travel history', () {
    test('summarizes the count and names only the most recent flights', () {
      final spoken = speak(<String, Object?>{
        'type': 'travel_history',
        'count': 105,
        'scope': 'all time',
        'totalSpendUSD': 48250,
        'flights': [
          {
            'date': '2026-07-02',
            'flightNo': 'AA50',
            'route': 'DFW→LHR',
            'cabin': 'Business',
            'fareUSD': 2400,
            'milesEarned': 5200,
            'seat': '2A',
          },
          {
            'date': '2026-05-11',
            'flightNo': 'AA100',
            'route': 'JFK→LHR',
            'cabin': 'Main',
            'fareUSD': 800,
            'milesEarned': 1800,
            'seat': '14C',
          },
          {
            'date': '2026-03-01',
            'flightNo': 'AA9',
            'route': 'ORD→NRT',
            'cabin': 'Main',
            'fareUSD': 950,
            'milesEarned': 2100,
            'seat': '30F',
          },
        ],
      })!;

      expect(spoken, contains('105'));
      expect(spoken, contains('all time'));
      // 105 flights cannot be read out. Only the newest couple are named.
      expect(spoken, contains('A A 50'));
      expect(spoken, isNot(contains('ORD')));
      expect(spoken.length, lessThan(400));
      // The arrow in "DFW→LHR" is silent to a listener, and the codes are
      // nonsense words unless spelled.
      expect(spoken, contains('D F W to L H R'));
      expect(spoken, isNot(contains('→')));
    });
  });

  group('seat map', () {
    test('summarizes availability instead of enumerating the cabin', () {
      final seats = List<Map<String, Object?>>.generate(
        60,
        (i) => {
          'seatNo': '${(i ~/ 6) + 10}${String.fromCharCode(65 + i % 6)}',
          'available': i.isEven,
          'price': 45,
          'type': i % 6 == 0 ? 'window' : 'aisle',
        },
      );
      final spoken = speak(<String, Object?>{
        'type': 'seat_map',
        'flightNo': 'AA50',
        'currency': 'USD',
        'cabins': [
          {'name': 'Main Cabin', 'seats': seats},
        ],
      });

      if (spoken == null) return; // mapper rejected the shape; covered elsewhere
      // A seat map read aloud row by row is unusable. What a passenger
      // choosing by voice needs is a count and one seat they could ask for.
      expect(spoken.length, lessThan(300));
    });
  });

  group('upgrade quote', () {
    test('asks before applying, and names both prices', () {
      final spoken = speak({
        'type': 'upgrade_quote',
        'from': 'Main Cabin',
        'to': 'Flagship Business',
        'difference': 2439,
        'payWithMiles': {
          'miles': 243900,
          'affordable': true,
        },
        'flightNo': 'AA50',
      })!;

      expect(spoken, contains('Main Cabin'));
      expect(spoken, contains('Flagship Business'));
      expect(spoken, contains('2439 dollars'));
      expect(spoken, contains('243900 miles'));
      expect(spoken, contains('Shall I go ahead?'));
    });
  });

  group('cancellation', () {
    const cancellationCard = <String, Object?>{
      'type': 'cancellation',
      'pnr': 'FCLD3Q',
      'flightNo': 'AA50',
      'refundTotal': 950,
      'penalty': 200,
      'currency': 'USD',
    };

    test('asks before cancelling, and names the refund and the fee', () {
      final spoken = speak(cancellationCard, needsConfirmation: true)!;

      expect(spoken, contains('F C L D 3 Q'));
      expect(spoken, contains('950 dollars'));
      expect(spoken, contains('200 dollars'));
      expect(spoken, contains('Shall I go ahead?'));
    });

    test('reports a completed cancellation in the past tense', () {
      final spoken = speak(cancellationCard)!;

      expect(spoken, contains('Cancelled'));
      expect(spoken, contains('950 dollars'));
      expect(spoken, isNot(contains('Shall I go ahead?')));
    });
  });

  group('the factual/prose split', () {
    test('a card composed from a payload is marked factual', () {
      final cards = ChatCardMapper.fromResponse([
        <String, Object?>{
          'type': 'boarding_pass',
          'pnr': 'FCLD3Q',
          'flightNo': 'AA50',
          'gate': '25',
          'cabin': 'Main',
        },
      ]);

      final line = builder.build(
        ChatMessage(
          id: 'x',
          role: ChatRole.assistant,
          type: cards.single.type,
          timestamp: DateTime(2026),
          text: "Here's your boarding pass",
          payload: cards.single.payload,
        ),
      )!;

      // Factual lines skip the LLM summarizer, so a gate or PNR can never be
      // reworded into a different one.
      expect(line.isFactual, isTrue);
    });

    test('a plain reply is prose, and stays eligible for rewording', () {
      final line = builder.build(
        ChatMessage(
          id: 'x',
          role: ChatRole.assistant,
          type: ChatMessageType.text,
          timestamp: DateTime(2026),
          text: 'Sure, let me take a look at that for you.',
        ),
      )!;

      expect(line.isFactual, isFalse);
    });

    test('user messages and errors are never spoken', () {
      expect(
        builder.build(
          ChatMessage(
            id: 'x',
            role: ChatRole.user,
            type: ChatMessageType.text,
            timestamp: DateTime(2026),
            text: 'check me in',
          ),
        ),
        isNull,
      );
      expect(
        builder.build(
          ChatMessage(
            id: 'x',
            role: ChatRole.assistant,
            type: ChatMessageType.error,
            timestamp: DateTime(2026),
            text: 'Something went wrong',
          ),
        ),
        isNull,
      );
    });
  });
}
