import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/agent_escalation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/airport_info.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking_summary.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_summary_builder.dart';

ChatMessage _message(ChatMessageType type, {Object? payload, String text = 'caption'}) {
  return ChatMessage(
    id: 'id',
    role: ChatRole.assistant,
    type: type,
    timestamp: DateTime(2026, 3, 2, 9),
    text: text,
    payload: payload,
  );
}

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
    test('states the count, route, and cheapest option without listing them all', () {
      final spoken = VoiceSummaryBuilder.build(
        _message(ChatMessageType.flightOffersCard, payload: offers),
      )!;

      expect(spoken, contains('I found 2 flights from Newark to Chicago'));
      expect(spoken, contains('Delta Air Lines at 176 dollars'));
      expect(spoken, contains('12 30 in the afternoon'));
      expect(spoken, contains("You're welcome to name an airline"));
      // The other option should not be read out.
      expect(spoken, isNot(contains('United')));
    });

    test('a single result is offered directly', () {
      final spoken = VoiceSummaryBuilder.build(
        _message(ChatMessageType.flightOffersCard, payload: [offers.first]),
      )!;

      expect(spoken, contains('I found one flight'));
      expect(spoken, contains('Would you like me to book it for you?'));
    });

    test('an empty result says so politely', () {
      final spoken = VoiceSummaryBuilder.build(
        _message(ChatMessageType.flightOffersCard, payload: <FlightOffer>[]),
      );

      expect(
        spoken,
        "I'm sorry, I couldn't find any flights on that route. "
        'Would you like to try a different date or destination?',
      );
    });
  });

  group('flight status', () {
    test('leads with a gentle apology for a delay and the new departure time', () {
      final flight = Flight(
        flightNumber: 'FZ123',
        origin: 'DXB',
        destination: 'LHR',
        status: FlightStatus.delayed,
        scheduledDeparture: DateTime(2026, 3, 2, 15, 0),
        estimatedDeparture: DateTime(2026, 3, 2, 16, 40),
        gate: 'B12',
      );

      final spoken = VoiceSummaryBuilder.build(
        _message(ChatMessageType.flightStatusCard, payload: flight),
      )!;

      expect(spoken, startsWith("I'm sorry, flight F Z 1 2 3 is delayed."));
      expect(spoken, contains('The new departure is 4 40 in the afternoon'));
      expect(spoken, contains('Gate B 1 2'));
    });

    test('an on-time flight reads as on time', () {
      final flight = Flight(
        flightNumber: 'FZ123',
        origin: 'DXB',
        destination: 'LHR',
        status: FlightStatus.scheduled,
        scheduledDeparture: DateTime(2026, 3, 2, 15, 0),
      );

      expect(
        VoiceSummaryBuilder.build(_message(ChatMessageType.flightStatusCard, payload: flight)),
        'Flight F Z 1 2 3 is on time. Departure is 3 in the afternoon.',
      );
    });
  });

  group('seat map', () {
    const seatMap = SeatMap(
      flightNumber: 'UA482',
      rows: 2,
      seats: [
        Seat(
          seatNumber: '14A',
          row: 14,
          column: 'A',
          type: SeatType.window,
          availability: SeatAvailability.available,
        ),
        Seat(
          seatNumber: '14B',
          row: 14,
          column: 'B',
          type: SeatType.middle,
          availability: SeatAvailability.occupied,
        ),
      ],
    );

    test('offers a choice instead of reading the grid', () {
      final spoken = VoiceSummaryBuilder.build(
        _message(ChatMessageType.seatMapCard, payload: seatMap),
      )!;

      expect(
        spoken,
        "I've put the seat map on your screen. Would you like a window, "
        'an aisle, or a specific seat like 14 A?',
      );
      expect(spoken, isNot(contains('14B')));
    });

    test('a full cabin says nothing is free', () {
      const full = SeatMap(
        flightNumber: 'UA482',
        rows: 1,
        seats: [
          Seat(
            seatNumber: '14B',
            row: 14,
            column: 'B',
            type: SeatType.middle,
            availability: SeatAvailability.occupied,
          ),
        ],
      );

      expect(
        VoiceSummaryBuilder.build(_message(ChatMessageType.seatMapCard, payload: full)),
        contains("aren't any free seats"),
      );
    });
  });

  test('baggage options list the weights and ask', () {
    const options = [
      BaggageOption(id: 'bag_5kg', extraWeightKg: 5, price: 25),
      BaggageOption(id: 'bag_10kg', extraWeightKg: 10, price: 45),
      BaggageOption(id: 'bag_20kg', extraWeightKg: 20, price: 80),
    ];

    expect(
      VoiceSummaryBuilder.build(_message(ChatMessageType.baggageOptionsCard, payload: options)),
      "You're welcome to add 5, 10, or 20 kilos. Which would you prefer?",
    );
  });

  test('baggage success confirms the weight added', () {
    const purchase = BaggagePurchase(
      id: 'p1',
      option: BaggageOption(id: 'bag_10kg', extraWeightKg: 10, price: 45),
      status: BaggagePurchaseStatus.success,
    );

    expect(
      VoiceSummaryBuilder.build(_message(ChatMessageType.baggageSuccessCard, payload: purchase)),
      'All set, 10 extra kilos are confirmed.',
    );
  });

  test('booking confirmation speaks only the facts worth remembering', () {
    final summary = BookingSummary(
      booking: Booking(
        pnr: 'TB1234',
        passengerName: 'Joe Traveler',
        flight: Flight(
          flightNumber: 'UA482',
          origin: 'EWR',
          destination: 'ORD',
          status: FlightStatus.scheduled,
          scheduledDeparture: DateTime(2026, 3, 3, 6, 45),
        ),
      ),
      seatNumber: '14A',
      extraBaggageKg: 10,
    );

    final spoken = VoiceSummaryBuilder.build(
      _message(ChatMessageType.bookingConfirmationCard, payload: summary),
      now: DateTime(2026, 3, 2, 9),
    )!;

    expect(spoken, contains('confirmation is T B 1 2 3 4'));
    expect(spoken, contains('Seat 14 A'));
    expect(spoken, contains('10 extra kilos'));
    expect(spoken, contains('Departing tomorrow at 6 45 in the morning'));
    expect(spoken, contains('Have a wonderful trip'));
  });

  test('airport info gives terminal, gate, and one hint', () {
    const info = AirportInfo(
      terminal: '2',
      checkInCounter: '14-18',
      gate: 'B12',
      walkingTimeMinutes: 12,
      directions: ['Head left after security', 'Then take the escalator'],
    );

    final spoken = VoiceSummaryBuilder.build(
      _message(ChatMessageType.airportInfoCard, payload: info),
    )!;

    expect(spoken, contains("Here's what you'll need"));
    expect(spoken, contains('terminal 2'));
    expect(spoken, contains('gate B 1 2'));
    expect(spoken, contains("It's about a 12 minute walk"));
    expect(spoken, contains('Head left after security'));
    expect(spoken, isNot(contains('escalator')));
  });

  test('escalation states the queue position and wait', () {
    const escalation = EscalationResult(queuePosition: 2, estimatedWaitMinutes: 5);

    expect(
      VoiceSummaryBuilder.build(
        _message(ChatMessageType.agentEscalationCard, payload: escalation),
      ),
      "Of course, I'm connecting you to an agent now. "
      "You're number 2 in the queue, with about 5 minutes to wait.",
    );
  });

  test('plain text is cleaned for speech', () {
    expect(
      VoiceSummaryBuilder.build(_message(ChatMessageType.text, text: 'Seat **14A** confirmed. ✅')),
      'Seat 14A confirmed.',
    );
  });

  test('errors are spoken plainly', () {
    expect(
      VoiceSummaryBuilder.build(_message(ChatMessageType.error, text: 'No internet connection.')),
      'No internet connection.',
    );
  });

  test('a card with a missing or mistyped payload falls back to the caption', () {
    for (final type in [
      ChatMessageType.flightOffersCard,
      ChatMessageType.flightStatusCard,
      ChatMessageType.seatMapCard,
      ChatMessageType.baggageOptionsCard,
      ChatMessageType.baggageSuccessCard,
      ChatMessageType.bookingConfirmationCard,
      ChatMessageType.airportInfoCard,
      ChatMessageType.agentEscalationCard,
    ]) {
      expect(VoiceSummaryBuilder.build(_message(type)), isNull, reason: '$type with null payload');
      expect(
        VoiceSummaryBuilder.build(_message(type, payload: 'wrong')),
        isNull,
        reason: '$type with wrong payload type',
      );
    }
  });
}
