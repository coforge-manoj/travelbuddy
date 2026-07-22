import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/intent.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/change_seat_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/classify_intent_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/get_flight_status_usecase.dart';

import '../mocks/mocks.dart';

void main() {
  group('GetFlightStatusUseCase', () {
    test('delegates to FlightRepository.getFlightStatus', () async {
      final repository = MockFlightRepository();
      final useCase = GetFlightStatusUseCase(repository);
      final flight = Flight(
        flightNumber: 'FZ123',
        origin: 'DXB',
        destination: 'LHR',
        status: FlightStatus.delayed,
        scheduledDeparture: DateTime(2026, 1, 1, 10),
      );
      when(() => repository.getFlightStatus('FZ123'))
          .thenAnswer((_) async => Result.success(flight));

      final result = await useCase('FZ123');

      expect(result.valueOrNull, flight);
      verify(() => repository.getFlightStatus('FZ123')).called(1);
    });
  });

  group('ClassifyIntentUseCase', () {
    test('delegates to ChatRepository.classifyIntent', () async {
      final repository = MockChatRepository();
      final useCase = ClassifyIntentUseCase(repository);
      const expected = IntentResult(type: IntentType.seatSelection, confidence: 0.9);
      when(() => repository.classifyIntent('I want a window seat'))
          .thenAnswer((_) async => const Result.success(expected));

      final result = await useCase('I want a window seat');

      expect(result.valueOrNull, expected);
    });
  });

  group('ChangeSeatUseCase', () {
    test('delegates to SeatRepository.changeSeat with the right arguments', () async {
      final repository = MockSeatRepository();
      final useCase = ChangeSeatUseCase(repository);
      const seat = Seat(
        seatNumber: '14A',
        row: 14,
        column: 'A',
        type: SeatType.window,
        availability: SeatAvailability.selected,
      );
      when(
        () => repository.changeSeat(
          pnr: 'ABC123',
          flightNumber: 'FZ123',
          seatNumber: '14A',
        ),
      ).thenAnswer((_) async => const Result.success(seat));

      final result = await useCase(pnr: 'ABC123', flightNumber: 'FZ123', seatNumber: '14A');

      expect(result.valueOrNull, seat);
    });
  });
}
