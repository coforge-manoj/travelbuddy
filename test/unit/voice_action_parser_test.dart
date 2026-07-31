import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/data/datasource/voice_action_remote_datasource.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_action_parser.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_action_resolver.dart';

class _ScriptedRemote implements VoiceActionRemoteDataSource {
  _ScriptedRemote(this.guess);

  VoiceActionGuess? guess;
  int calls = 0;

  @override
  Future<VoiceActionGuess?> detect({
    required String transcript,
    required VoiceContext context,
    VoiceAction? pendingConfirmation,
  }) async {
    calls++;
    return guess;
  }
}

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
    offer('DL2071', 'Delta Air Lines', 176, 12),
  ];

  group('HybridVoiceActionParser', () {
    test('uses rules first and never calls the model for a closed phrase', () async {
      final remote = _ScriptedRemote(
        const VoiceActionGuess(action: 'select_offer', offerId: 'UA482'),
      );
      final parser = HybridVoiceActionParser(remote: remote);

      final outcome = await parser.resolve(
        transcript: 'the cheapest one',
        context: VoiceContext.flightOffers(offers),
      );

      expect((outcome! as SelectOfferAction).offer.id, 'DL2071');
      expect(remote.calls, 0);
    });

    test('asks the model when rules miss and rebinds onto catalog ids', () async {
      final remote = _ScriptedRemote(
        const VoiceActionGuess(action: 'select_offer', offerId: 'UA482'),
      );
      final parser = HybridVoiceActionParser(
        remote: remote,
        timeout: const Duration(seconds: 2),
      );

      final outcome = await parser.resolve(
        transcript: 'go with the six thirty departure',
        context: VoiceContext.flightOffers(offers),
      );

      expect(remote.calls, 1);
      expect((outcome! as SelectOfferAction).offer.id, 'UA482');
    });

    test('discards invented offer ids from the model', () async {
      final remote = _ScriptedRemote(
        const VoiceActionGuess(action: 'select_offer', offerId: 'FAKE999'),
      );
      final parser = HybridVoiceActionParser(
        remote: remote,
        timeout: const Duration(seconds: 2),
      );

      final outcome = await parser.resolve(
        transcript: 'book the imaginary flight',
        context: VoiceContext.flightOffers(offers),
      );

      expect(outcome, isNull);
    });

    test('does not call the model with no card context', () async {
      final remote = _ScriptedRemote(const VoiceActionGuess(action: 'cancel'));
      final parser = HybridVoiceActionParser(remote: remote);

      final outcome = await parser.resolve(
        transcript: 'hello there',
        context: const VoiceContext.none(),
      );

      expect(outcome, isNull);
      expect(remote.calls, 0);
    });
  });

  group('MockVoiceActionRemoteDataSource', () {
    late MockVoiceActionRemoteDataSource mock;

    setUp(() {
      mock = MockVoiceActionRemoteDataSource(latency: Duration.zero);
    });

    test('recovers natural flight phrasing after stripping fillers', () async {
      final guess = await mock.detect(
        transcript: "I'd like the cheapest one please",
        context: VoiceContext.flightOffers(offers),
      );

      expect(guess?.action, 'select_offer');
      expect(guess?.offerId, 'DL2071');
    });

    test('soft-matches a window preference', () async {
      const seatMap = SeatMap(
        flightNumber: 'UA482',
        rows: 1,
        seats: [
          Seat(
            seatNumber: '1A',
            row: 1,
            column: 'A',
            type: SeatType.window,
            availability: SeatAvailability.available,
          ),
          Seat(
            seatNumber: '1C',
            row: 1,
            column: 'C',
            type: SeatType.aisle,
            availability: SeatAvailability.available,
            priceDelta: 15,
          ),
        ],
      );

      final guess = await mock.detect(
        transcript: 'put me by the window please',
        context: const VoiceContext.seatMap(seatMap),
      );

      expect(guess?.action, 'select_seat');
      expect(guess?.seatNumber, '1A');
    });

    test('soft-matches skipping extra bags', () async {
      final options = [
        const BaggageOption(id: 'bag10', extraWeightKg: 10, price: 40),
        const BaggageOption(id: 'bag20', extraWeightKg: 20, price: 70),
      ];

      final guess = await mock.detect(
        transcript: 'I do not need bags',
        context: VoiceContext.baggageOptions(options),
      );

      expect(guess?.action, 'skip_baggage');
    });
  });

  group('VoiceActionBinder', () {
    test('binds a seat selection and rejects occupied seats with a question', () {
      const seatMap = SeatMap(
        flightNumber: 'UA482',
        rows: 1,
        seats: [
          Seat(
            seatNumber: '1A',
            row: 1,
            column: 'A',
            type: SeatType.window,
            availability: SeatAvailability.occupied,
          ),
        ],
      );

      final outcome = VoiceActionBinder.bind(
        guess: const VoiceActionGuess(action: 'select_seat', seatNumber: '1A'),
        context: const VoiceContext.seatMap(seatMap),
      );

      expect(outcome, isA<VoiceAmbiguity>());
    });
  });
}
