import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/proactive_prompt_builder.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_action_resolver.dart';

void main() {
  final offers = [
    FlightOffer(
      id: 'UA482',
      airline: 'United Airlines',
      flightNumber: 'UA482',
      origin: 'EWR',
      destination: 'ORD',
      departureTime: DateTime(2026, 3, 3, 6, 45),
      arrivalTime: DateTime(2026, 3, 3, 8, 58),
      price: 189,
    ),
    FlightOffer(
      id: 'DL2071',
      airline: 'Delta Air Lines',
      flightNumber: 'DL2071',
      origin: 'EWR',
      destination: 'ORD',
      departureTime: DateTime(2026, 3, 3, 12, 30),
      arrivalTime: DateTime(2026, 3, 3, 15, 40),
      price: 176,
    ),
  ];

  group('flight offers', () {
    test('the first nudge offers the cheapest option and arms it for a yes', () {
      final prompt = ProactivePromptBuilder.build(VoiceContext.flightOffers(offers), 0)!;

      expect(prompt.text, contains('Delta Air Lines at \$176'));
      expect(prompt.speechText, contains('Delta Air Lines at 176 dollars'));
      expect((prompt.suggestedAction! as SelectOfferAction).offer.id, 'DL2071');
    });

    test('later nudges are conversational, so a yes cannot book anything', () {
      final otherDates = ProactivePromptBuilder.build(VoiceContext.flightOffers(offers), 1)!;
      final anythingElse = ProactivePromptBuilder.build(VoiceContext.flightOffers(offers), 2)!;

      expect(otherDates.suggestedAction, isNull);
      expect(anythingElse.suggestedAction, isNull);
      expect(ProactivePromptBuilder.build(VoiceContext.flightOffers(offers), 3), isNull);
      expect(ProactivePromptBuilder.hasMoreSteps(VoiceContextKind.flightOffers, 3), isFalse);
    });
  });

  group('seat map', () {
    const seatMap = SeatMap(
      flightNumber: 'UA482',
      rows: 2,
      seats: [
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
      ],
    );

    test('a nudge never proposes a seat the passenger would be charged for', () {
      final prompt = ProactivePromptBuilder.build(const VoiceContext.seatMap(seatMap), 0)!;

      expect((prompt.suggestedAction! as SelectSeatAction).seat.seatNumber, '14C');
    });

    test('seat and baggage stop after a single nudge', () {
      expect(ProactivePromptBuilder.hasMoreSteps(VoiceContextKind.seatMap, 1), isFalse);
      expect(ProactivePromptBuilder.build(const VoiceContext.seatMap(seatMap), 1), isNull);

      const options = [BaggageOption(id: 'bag_5kg', extraWeightKg: 5, price: 25)];
      expect(ProactivePromptBuilder.build(const VoiceContext.baggageOptions(options), 1), isNull);
    });
  });

  test('there is nothing to nudge about without a choice on screen', () {
    expect(ProactivePromptBuilder.hasMoreSteps(VoiceContextKind.none, 0), isFalse);
    expect(ProactivePromptBuilder.build(const VoiceContext.none(), 0), isNull);
  });
}
