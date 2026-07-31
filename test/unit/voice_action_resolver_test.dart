import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_action_resolver.dart';

void main() {
  FlightOffer offer(String id, String airline, num price, int hour) => FlightOffer(
        id: id,
        airline: airline,
        flightNumber: id,
        origin: 'EWR',
        destination: 'ORD',
        departureTime: DateTime(2026, 3, 3, hour, 30),
        arrivalTime: DateTime(2026, 3, 3, hour + 2, 30),
        price: price,
      );

  final offers = [
    offer('UA482', 'United Airlines', 189, 6),
    offer('AA1190', 'American Airlines', 214, 9),
    offer('DL2071', 'Delta Air Lines', 176, 12),
    offer('B6935', 'JetBlue', 165, 17),
  ];

  VoiceOutcome? resolveOffers(String transcript) => VoiceActionResolver.resolve(
        transcript: transcript,
        context: VoiceContext.flightOffers(offers),
      );

  group('flight offers', () {
    test('superlatives pick the right flight', () {
      expect(
        (resolveOffers('the cheapest one')! as SelectOfferAction).offer.id,
        'B6935',
      );
      expect(
        (resolveOffers('give me the earliest flight')! as SelectOfferAction).offer.id,
        'UA482',
      );
      expect(
        (resolveOffers('the latest one please')! as SelectOfferAction).offer.id,
        'B6935',
      );
    });

    test('JetBlue matches whether spoken as one word or two', () {
      expect((resolveOffers('book jetblue')! as SelectOfferAction).offer.id, 'B6935');
      expect((resolveOffers('book jet blue')! as SelectOfferAction).offer.id, 'B6935');
    });

    test('an airline name picks that flight', () {
      expect((resolveOffers('book delta')! as SelectOfferAction).offer.id, 'DL2071');
      expect((resolveOffers('JetBlue please')! as SelectOfferAction).offer.id, 'B6935');
    });

    test('the shared word "airlines" alone matches nothing', () {
      expect(resolveOffers('airlines'), isNull);
    });

    test('two flights on the same airline ask rather than guess', () {
      final ambiguous = [
        offer('UA482', 'United Airlines', 189, 6),
        offer('UA900', 'United Airlines', 250, 14),
      ];

      final outcome = VoiceActionResolver.resolve(
        transcript: 'united',
        context: VoiceContext.flightOffers(ambiguous),
      );

      expect(outcome, isA<VoiceAmbiguity>());
      expect((outcome! as VoiceAmbiguity).question, contains('2 United Airlines flights'));
      expect((outcome as VoiceAmbiguity).question, contains('6:30 AM'));
      expect(outcome.speechText, contains('6 30 in the morning'));
    });

    test('ordinals index the list as rendered', () {
      expect((resolveOffers('the second one')! as SelectOfferAction).offer.id, 'AA1190');
      expect((resolveOffers('the last one')! as SelectOfferAction).offer.id, 'B6935');
    });

    test('a flight number matches even when spoken with a space', () {
      expect((resolveOffers('book ua 482')! as SelectOfferAction).offer.id, 'UA482');
    });

    test('booking an offer always needs confirmation first', () {
      expect((resolveOffers('the cheapest one')! as VoiceAction).requiresConfirmation, isTrue);
      expect(
        (resolveOffers('the cheapest one')! as VoiceAction).confirmationPrompt,
        contains('165 dollars'),
      );
      expect(
        (resolveOffers('the cheapest one')! as VoiceAction).confirmationDisplayText,
        contains(r'$165'),
      );
    });

    test('unrelated speech falls through to intent classification', () {
      expect(resolveOffers('what is the baggage allowance on international routes'), isNull);
    });
  });

  group('seats', () {
    const seatMap = SeatMap(
      flightNumber: 'UA482',
      rows: 2,
      seats: [
        Seat(
          seatNumber: '14A',
          row: 14,
          column: 'A',
          type: SeatType.window,
          availability: SeatAvailability.occupied,
        ),
        Seat(
          seatNumber: '14C',
          row: 14,
          column: 'C',
          type: SeatType.aisle,
          availability: SeatAvailability.available,
        ),
        Seat(
          seatNumber: '15A',
          row: 15,
          column: 'A',
          type: SeatType.window,
          availability: SeatAvailability.available,
          priceDelta: 15,
        ),
        Seat(
          seatNumber: '15B',
          row: 15,
          column: 'B',
          type: SeatType.middle,
          availability: SeatAvailability.available,
        ),
      ],
    );

    VoiceOutcome? resolveSeat(String transcript) => VoiceActionResolver.resolve(
          transcript: transcript,
          context: const VoiceContext.seatMap(seatMap),
        );

    test('an explicit available seat is selected', () {
      expect((resolveSeat('seat 14 C')! as SelectSeatAction).seat.seatNumber, '14C');
      expect((resolveSeat('15b')! as SelectSeatAction).seat.seatNumber, '15B');
    });

    test('a taken seat is refused with a concrete alternative to accept', () {
      final outcome = resolveSeat('14A')! as VoiceAmbiguity;

      expect(outcome.question, contains('Seat 14A is taken'));
      expect(outcome.question, contains('14C is free'));
      expect(outcome.speechText, contains('Seat 14 A is taken'));
      expect((outcome.suggestion! as SelectSeatAction).seat.seatNumber, '14C');
    });

    test('a seat that is not on the aircraft is queried, not booked', () {
      final outcome = resolveSeat('seat 40 F')! as VoiceAmbiguity;

      expect(outcome.question, contains("I don't see seat 40F"));
      expect(outcome.speechText, contains("I don't see seat 40 F"));
      expect(outcome.suggestion, isNull);
    });

    test('a preference picks the cheapest matching free seat', () {
      expect((resolveSeat('window please')! as SelectSeatAction).seat.seatNumber, '15A');
      expect((resolveSeat('an aisle seat')! as SelectSeatAction).seat.seatNumber, '14C');
    });

    test('free seats skip confirmation but paid ones do not', () {
      expect((resolveSeat('an aisle seat')! as VoiceAction).requiresConfirmation, isFalse);

      final paid = resolveSeat('window please')! as SelectSeatAction;
      expect(paid.requiresConfirmation, isTrue);
      expect(paid.confirmationPrompt, contains('15 dollars'));
    });

    test('a seat spoken as words is selected, same as digits', () {
      // Recognizers routinely transcribe a short spoken row as a word, so a
      // digits-only match makes the assistant deaf to the most natural way
      // to say a seat out loud.
      expect((resolveSeat('fourteen C')! as SelectSeatAction).seat.seatNumber, '14C');
      expect((resolveSeat('seat fifteen b')! as SelectSeatAction).seat.seatNumber, '15B');
      expect((resolveSeat('row fifteen seat A')! as SelectSeatAction).seat.seatNumber, '15A');
      expect((resolveSeat('row 14, seat C')! as SelectSeatAction).seat.seatNumber, '14C');
    });

    test('word numbers outside a seat position are left alone', () {
      // "one" here is an ordinal about the card, not row 1 — it must not
      // become a seat.
      expect(resolveSeat('tell me about the first one'), isNull);
    });

    test('asking for a seat without naming one is answered, not ignored', () {
      // Falling through would re-classify this as a fresh seat-selection
      // intent and stack a second, identical seat map under the first.
      final outcome = resolveSeat('I want to select a seat')! as VoiceAmbiguity;
      expect(outcome.question, contains('Which seat would you like?'));
      expect(outcome.suggestion, isNull);

      expect(resolveSeat('book me a seat'), isA<VoiceAmbiguity>());
      expect(resolveSeat('let me pick a seat'), isA<VoiceAmbiguity>());
    });

    test('skipping is recognized', () {
      expect(resolveSeat('skip for now'), isA<SkipSeatAction>());
    });
  });

  group('baggage', () {
    const options = [
      BaggageOption(id: 'bag_5kg', extraWeightKg: 5, price: 25),
      BaggageOption(id: 'bag_10kg', extraWeightKg: 10, price: 45),
      BaggageOption(id: 'bag_20kg', extraWeightKg: 20, price: 80),
    ];

    VoiceOutcome? resolveBaggage(String transcript) => VoiceActionResolver.resolve(
          transcript: transcript,
          context: const VoiceContext.baggageOptions(options),
        );

    test('a weight picks the matching option, spoken as digits or as words', () {
      expect((resolveBaggage('10 kilos')! as SelectBaggageAction).option.id, 'bag_10kg');
      expect((resolveBaggage('add 20 kg')! as SelectBaggageAction).option.id, 'bag_20kg');
      // Recognizers are inconsistent about transcribing spoken numbers.
      expect((resolveBaggage('ten kilos')! as SelectBaggageAction).option.id, 'bag_10kg');
      expect((resolveBaggage('twenty kilos please')! as SelectBaggageAction).option.id, 'bag_20kg');
    });

    test('relative wording works too', () {
      expect((resolveBaggage('the smallest')! as SelectBaggageAction).option.id, 'bag_5kg');
      expect((resolveBaggage('the biggest one')! as SelectBaggageAction).option.id, 'bag_20kg');
      expect((resolveBaggage('the middle one')! as SelectBaggageAction).option.id, 'bag_10kg');
    });

    test('adding baggage always needs confirmation with the price', () {
      final action = resolveBaggage('10 kilos')! as VoiceAction;

      expect(action.requiresConfirmation, isTrue);
      expect(action.confirmationPrompt, contains('10 extra kilos for 45 dollars'));
    });

    test('declining is free and immediate', () {
      expect(resolveBaggage('no bags thanks'), isA<SkipBaggageAction>());
      expect(resolveBaggage('continue without'), isA<SkipBaggageAction>());
      expect((resolveBaggage('no bags thanks')! as VoiceAction).requiresConfirmation, isFalse);
    });
  });

  group('confirmation', () {
    final pending = SelectOfferAction(offers.first);

    test('yes only resolves when something is actually pending', () {
      expect(
        VoiceActionResolver.resolve(
          transcript: 'yes',
          context: VoiceContext.flightOffers(offers),
          pendingConfirmation: pending,
        ),
        isA<ConfirmPendingAction>(),
      );

      expect(
        VoiceActionResolver.resolve(
          transcript: 'yes',
          context: VoiceContext.flightOffers(offers),
        ),
        isNull,
      );
    });

    test('various affirmatives are accepted', () {
      for (final phrase in [
        'yes',
        'yep',
        'go ahead',
        'book it',
        'sounds good',
        'confirm',
        'yes please',
        'confirm the booking',
      ]) {
        expect(
          VoiceActionResolver.resolve(
            transcript: phrase,
            context: const VoiceContext.none(),
            pendingConfirmation: pending,
          ),
          isA<ConfirmPendingAction>(),
          reason: phrase,
        );
      }
    });

    test('no cancels instead of confirming', () {
      for (final phrase in ['no', 'nope', 'cancel', 'never mind']) {
        expect(
          VoiceActionResolver.resolve(
            transcript: phrase,
            context: const VoiceContext.none(),
            pendingConfirmation: pending,
          ),
          isA<CancelAction>(),
          reason: phrase,
        );
      }
    });

    test('a new request during a pending confirmation replaces it rather than confirming it', () {
      final outcome = VoiceActionResolver.resolve(
        transcript: 'actually the delta flight',
        context: VoiceContext.flightOffers(offers),
        pendingConfirmation: pending,
      );

      expect((outcome! as SelectOfferAction).offer.id, 'DL2071');
    });
  });

  test('with no card on screen, only cancellation is recognized', () {
    expect(
      VoiceActionResolver.resolve(transcript: 'cancel', context: const VoiceContext.none()),
      isA<CancelAction>(),
    );
    expect(
      VoiceActionResolver.resolve(transcript: 'the cheapest', context: const VoiceContext.none()),
      isNull,
    );
  });

  test('empty speech resolves to nothing', () {
    expect(
      VoiceActionResolver.resolve(transcript: '   ', context: VoiceContext.flightOffers(offers)),
      isNull,
    );
  });
}
