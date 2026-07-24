import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/data/models/chat_message_model.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/agent_escalation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/airport_info.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat.dart';

/// Persistence round-trip for rich-card messages. Before payloads were
/// serialized, a saved card came back with a null payload and crashed its card
/// widget (Flutter's maroon error box). These assert the domain payload
/// survives entity → model → JSON → model → entity, which is exactly the path
/// Hive persistence takes.
void main() {
  ChatMessage roundTrip(ChatMessage message) {
    final json = ChatMessageModel.fromEntity(message).toJson();
    return ChatMessageModel.fromJson(json).toEntity();
  }

  ChatMessage card(ChatMessageType type, Object payload) => ChatMessage(
        id: 'id-1',
        role: ChatRole.assistant,
        type: type,
        timestamp: DateTime.parse('2026-07-24T12:00:00.000'),
        payload: payload,
      );

  test('flight status card payload survives persistence', () {
    final flight = Flight(
      flightNumber: 'FZ123',
      origin: 'DXB',
      destination: 'BOM',
      status: FlightStatus.delayed,
      scheduledDeparture: DateTime.parse('2026-07-24T18:00:00.000'),
      estimatedDeparture: DateTime.parse('2026-07-24T19:14:00.000'),
      gate: 'B12',
      terminal: '2',
      checkInCounter: 'G',
      boardingTime: DateTime.parse('2026-07-24T18:19:00.000'),
    );

    final restored = roundTrip(card(ChatMessageType.flightStatusCard, flight));

    expect(restored.payload, isA<Flight>());
    expect(restored.payload, flight);
  });

  test('seat map card payload survives persistence', () {
    const seatMap = SeatMap(
      flightNumber: 'FZ123',
      rows: 2,
      currency: 'AED',
      seats: [
        Seat(
          seatNumber: '1A',
          row: 1,
          column: 'A',
          type: SeatType.window,
          availability: SeatAvailability.available,
          priceDelta: 50,
        ),
        Seat(
          seatNumber: '1C',
          row: 1,
          column: 'C',
          type: SeatType.aisle,
          availability: SeatAvailability.occupied,
        ),
      ],
    );

    final restored = roundTrip(card(ChatMessageType.seatMapCard, seatMap));

    expect(restored.payload, isA<SeatMap>());
    expect(restored.payload, seatMap);
  });

  test('baggage options list payload survives persistence', () {
    const options = [
      BaggageOption(id: 'b1', extraWeightKg: 10, price: 75, currency: 'AED'),
      BaggageOption(id: 'b2', extraWeightKg: 20, price: 130, currency: 'AED'),
    ];

    final restored =
        roundTrip(card(ChatMessageType.baggageOptionsCard, options));

    expect(restored.payload, isA<List<BaggageOption>>());
    expect(restored.payload, options);
  });

  test('baggage success card payload survives persistence', () {
    const purchase = BaggagePurchase(
      id: 'p1',
      option: BaggageOption(id: 'b1', extraWeightKg: 10, price: 75),
      status: BaggagePurchaseStatus.success,
      confirmationCode: 'XYZ',
    );

    final restored =
        roundTrip(card(ChatMessageType.baggageSuccessCard, purchase));

    expect(restored.payload, isA<BaggagePurchase>());
    expect(restored.payload, purchase);
  });

  test('airport info card payload survives persistence', () {
    const info = AirportInfo(
      terminal: '2',
      checkInCounter: 'G',
      gate: 'B12',
      walkingTimeMinutes: 8,
      directions: ['Head left', 'Take escalator'],
    );

    final restored = roundTrip(card(ChatMessageType.airportInfoCard, info));

    expect(restored.payload, isA<AirportInfo>());
    expect(restored.payload, info);
  });

  test('agent escalation card payload survives persistence', () {
    const escalation =
        EscalationResult(queuePosition: 3, estimatedWaitMinutes: 12);

    final restored =
        roundTrip(card(ChatMessageType.agentEscalationCard, escalation));

    expect(restored.payload, isA<EscalationResult>());
    expect(restored.payload, escalation);
  });

  test('a legacy record with a null card payload decodes without throwing', () {
    // Simulates a message saved before payloads were persisted.
    final legacy = {
      'id': 'old-1',
      'role': 'assistant',
      'type': 'flightStatusCard',
      'timestamp': '2026-07-24T12:00:00.000',
      'text': '',
      'payload': null,
      'isStreaming': false,
    };

    final restored = ChatMessageModel.fromJson(legacy).toEntity();

    expect(restored.type, ChatMessageType.flightStatusCard);
    expect(restored.payload, isNull); // widget renders the fallback, no crash
  });
}
