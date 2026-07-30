import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/data/datasource/voice_phrasing_remote_datasource.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/agent_escalation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/airport_info.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking_summary.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/spoken_draft.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/spoken_fact_guard.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_summary_builder.dart';

/// End-to-end check on the phrasing layer as the demo actually runs it:
/// card → [SpokenDraft] → mock phrasing model → [SpokenFactGuard].
///
/// Two properties matter, and they pull against each other. The point of the
/// layer is that repeated cards stop sounding word-for-word identical; the
/// point of the guard is that no amount of rewording may bend a fare, a gate,
/// or a confirmation code. Every case below asserts both.
ChatMessage _message(ChatMessageType type, Object payload) {
  return ChatMessage(
    id: 'id',
    role: ChatRole.assistant,
    type: type,
    timestamp: DateTime(2026, 3, 2, 9),
    text: 'on-screen caption',
    payload: payload,
  );
}

final _offers = [
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

const _seatMap = SeatMap(
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
      seatNumber: '14C',
      row: 14,
      column: 'C',
      type: SeatType.aisle,
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

final _bookingSummary = BookingSummary(
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

final _cards = <String, ChatMessage>{
  'flight offers': _message(ChatMessageType.flightOffersCard, _offers),
  'a single offer': _message(ChatMessageType.flightOffersCard, [_offers.last]),
  'no offers': _message(ChatMessageType.flightOffersCard, <FlightOffer>[]),
  'a delayed flight': _message(
    ChatMessageType.flightStatusCard,
    Flight(
      flightNumber: 'FZ123',
      origin: 'DXB',
      destination: 'LHR',
      status: FlightStatus.delayed,
      scheduledDeparture: DateTime(2026, 3, 2, 15, 0),
      estimatedDeparture: DateTime(2026, 3, 2, 16, 40),
      gate: 'B12',
      terminal: '3',
    ),
  ),
  'an on-time flight': _message(
    ChatMessageType.flightStatusCard,
    Flight(
      flightNumber: 'FZ123',
      origin: 'DXB',
      destination: 'LHR',
      status: FlightStatus.scheduled,
      scheduledDeparture: DateTime(2026, 3, 2, 15, 0),
    ),
  ),
  'a seat map': _message(ChatMessageType.seatMapCard, _seatMap),
  'baggage options': _message(ChatMessageType.baggageOptionsCard, const [
    BaggageOption(id: 'bag_5kg', extraWeightKg: 5, price: 25),
    BaggageOption(id: 'bag_10kg', extraWeightKg: 10, price: 45),
    BaggageOption(id: 'bag_20kg', extraWeightKg: 20, price: 80),
  ]),
  'a baggage purchase': _message(
    ChatMessageType.baggageSuccessCard,
    const BaggagePurchase(
      id: 'p1',
      option: BaggageOption(id: 'bag_10kg', extraWeightKg: 10, price: 45),
      status: BaggagePurchaseStatus.success,
    ),
  ),
  'a booking confirmation': _message(ChatMessageType.bookingConfirmationCard, _bookingSummary),
  'airport info': _message(
    ChatMessageType.airportInfoCard,
    const AirportInfo(
      terminal: '2',
      checkInCounter: '14-18',
      gate: 'B12',
      walkingTimeMinutes: 12,
      directions: ['Head left after security'],
    ),
  ),
  'an agent handover': _message(
    ChatMessageType.agentEscalationCard,
    const EscalationResult(queuePosition: 2, estimatedWaitMinutes: 4),
  ),
};

void main() {
  late MockVoicePhrasingRemoteDataSource phrasing;

  setUp(() {
    phrasing = MockVoicePhrasingRemoteDataSource(latency: Duration.zero);
  });

  for (final entry in _cards.entries) {
    group(entry.key, () {
      late SpokenDraft draft;

      setUp(() {
        draft = VoiceSummaryBuilder.draft(entry.value, now: DateTime(2026, 3, 2, 9))!;
      });

      test('is worded differently across a session, and always speakably', () async {
        final heard = <String>[];
        for (var turn = 0; turn < 6; turn++) {
          final phrased = await phrasing.phrase(draft: draft, recentlySpoken: List.of(heard));

          final speakable = SpokenFactGuard.verify(phrased, draft);
          expect(
            speakable,
            isNotNull,
            reason: 'the guard would silence this phrasing and fall back: "$phrased"',
          );
          heard.add(speakable!);
        }

        expect(
          heard.toSet().length,
          greaterThanOrEqualTo(3),
          reason: 'six turns produced only ${heard.toSet().length} distinct phrasings: $heard',
        );
      });

      test('never drops a fact that has to be stated exactly', () async {
        for (var turn = 0; turn < 6; turn++) {
          final phrased = await phrasing.phrase(draft: draft, recentlySpoken: const []);
          for (final fragment in draft.mustInclude) {
            expect(phrased.toLowerCase(), contains(fragment.toLowerCase()));
          }
        }
      });
    });
  }

  test('consecutive turns on the same card do not repeat themselves', () async {
    final draft = VoiceSummaryBuilder.draft(_cards['flight offers']!)!;

    final first = await phrasing.phrase(draft: draft, recentlySpoken: const []);
    final second = await phrasing.phrase(draft: draft, recentlySpoken: [first]);

    expect(second, isNot(first));
  });

  test('bad news keeps its apology however it is worded', () async {
    final draft = VoiceSummaryBuilder.draft(_cards['no offers']!)!;
    expect(draft.tone, SpokenTone.apologetic);

    for (var turn = 0; turn < 6; turn++) {
      final phrased = await phrasing.phrase(draft: draft, recentlySpoken: const []);
      expect(
        phrased.toLowerCase(),
        anyOf(contains('sorry'), contains('afraid'), contains('unfortunately')),
      );
    }
  });

  test('a draft with nothing to say falls back rather than inventing a frame', () async {
    const empty = SpokenDraft(
      topic: SpokenTopic.flightOffers,
      clauses: [],
      fallbackText: 'The details are on your screen.',
    );

    expect(
      await phrasing.phrase(draft: empty, recentlySpoken: const []),
      'The details are on your screen.',
    );
  });
}
