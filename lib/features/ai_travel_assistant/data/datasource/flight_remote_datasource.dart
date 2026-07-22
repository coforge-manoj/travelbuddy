import 'package:dio/dio.dart';
import 'package:ai_travel_assistant/core/errors/exceptions.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/models/booking_model.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/models/flight_model.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/mock_backend/mock_backend_server.dart';

abstract interface class FlightRemoteDataSource {
  Future<FlightModel> getFlightStatus(String flightNumber);
  Future<BookingModel> getBooking(String pnr);
}

/// Talks to `GET /flight/status` and `GET /booking` on the airline backend.
class DioFlightRemoteDataSource implements FlightRemoteDataSource {
  DioFlightRemoteDataSource(this._dio);
  final Dio _dio;

  @override
  Future<FlightModel> getFlightStatus(String flightNumber) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/flight/status',
      queryParameters: {'flightNumber': flightNumber},
    );
    return FlightModel.fromJson(response.data!);
  }

  @override
  Future<BookingModel> getBooking(String pnr) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/booking',
      queryParameters: {'pnr': pnr},
    );
    return BookingModel.fromJson(response.data!);
  }
}

/// In-memory mock backed by [MockBackendServer], used until the real
/// backend is wired up and in widget/unit tests.
class MockFlightRemoteDataSource implements FlightRemoteDataSource {
  MockFlightRemoteDataSource([MockBackendServer? server])
      : _server = server ?? MockBackendServer.instance;
  final MockBackendServer _server;

  @override
  Future<FlightModel> getFlightStatus(String flightNumber) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _maybeThrowNetworkFailure();
    return _server.flight(flightNumber);
  }

  @override
  Future<BookingModel> getBooking(String pnr) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _maybeThrowNetworkFailure();
    if (pnr.trim().isEmpty) throw const InvalidBookingException();
    return _server.booking(pnr);
  }

  void _maybeThrowNetworkFailure() {
    if (_server.simulateNetworkError) {
      throw DioException(
        requestOptions: RequestOptions(path: '/flight/status'),
        type: DioExceptionType.connectionError,
      );
    }
    if (_server.simulateTimeout) {
      throw DioException(
        requestOptions: RequestOptions(path: '/flight/status'),
        type: DioExceptionType.connectionTimeout,
      );
    }
  }
}
