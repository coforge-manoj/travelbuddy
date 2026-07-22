import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ai_travel_assistant/core/errors/failures.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/datasource/flight_remote_datasource.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/models/flight_model.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/repositories/flight_repository_impl.dart';

class _MockFlightRemoteDataSource extends Mock implements FlightRemoteDataSource {}

void main() {
  late _MockFlightRemoteDataSource dataSource;
  late FlightRepositoryImpl repository;

  setUp(() {
    dataSource = _MockFlightRemoteDataSource();
    repository = FlightRepositoryImpl(dataSource);
  });

  test('maps a successful response to a Flight entity', () async {
    final model = FlightModel(
      flightNumber: 'FZ123',
      origin: 'DXB',
      destination: 'LHR',
      status: 'delayed',
      scheduledDeparture: DateTime(2026, 1, 1, 10).toIso8601String(),
    );
    when(() => dataSource.getFlightStatus('FZ123')).thenAnswer((_) async => model);

    final result = await repository.getFlightStatus('FZ123');

    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull?.flightNumber, 'FZ123');
  });

  test('maps a DioException connection error to NetworkFailure', () async {
    when(() => dataSource.getFlightStatus('FZ123')).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/flight/status'),
        type: DioExceptionType.connectionError,
      ),
    );

    final result = await repository.getFlightStatus('FZ123');

    expect(result.failureOrNull, isA<NetworkFailure>());
  });

  test('maps a DioException timeout to TimeoutFailure', () async {
    when(() => dataSource.getFlightStatus('FZ123')).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/flight/status'),
        type: DioExceptionType.connectionTimeout,
      ),
    );

    final result = await repository.getFlightStatus('FZ123');

    expect(result.failureOrNull, isA<TimeoutFailure>());
  });
}
