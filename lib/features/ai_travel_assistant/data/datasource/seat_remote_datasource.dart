import 'package:dio/dio.dart';
import 'package:ai_travel_assistant/core/errors/exceptions.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/models/seat_model.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/mock_backend/mock_backend_server.dart';

abstract interface class SeatRemoteDataSource {
  Future<SeatMapModel> getSeatMap(String flightNumber);
  Future<SeatModel> changeSeat({
    required String pnr,
    required String flightNumber,
    required String seatNumber,
  });
}

class DioSeatRemoteDataSource implements SeatRemoteDataSource {
  DioSeatRemoteDataSource(this._dio);
  final Dio _dio;

  @override
  Future<SeatMapModel> getSeatMap(String flightNumber) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/seatmap',
      queryParameters: {'flightNumber': flightNumber},
    );
    return SeatMapModel.fromJson(response.data!);
  }

  @override
  Future<SeatModel> changeSeat({
    required String pnr,
    required String flightNumber,
    required String seatNumber,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/seat/change',
      data: {'pnr': pnr, 'flightNumber': flightNumber, 'seatNumber': seatNumber},
    );
    return SeatModel.fromJson(response.data!);
  }
}

class MockSeatRemoteDataSource implements SeatRemoteDataSource {
  MockSeatRemoteDataSource([MockBackendServer? server])
      : _server = server ?? MockBackendServer.instance;
  final MockBackendServer _server;

  @override
  Future<SeatMapModel> getSeatMap(String flightNumber) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _maybeThrowNetworkFailure();
    return _server.seatMap(flightNumber);
  }

  @override
  Future<SeatModel> changeSeat({
    required String pnr,
    required String flightNumber,
    required String seatNumber,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _maybeThrowNetworkFailure();
    final updated = _server.changeSeat(flightNumber: flightNumber, seatNumber: seatNumber);
    if (updated == null) throw const SeatUnavailableException();
    return updated;
  }

  void _maybeThrowNetworkFailure() {
    if (_server.simulateNetworkError) {
      throw DioException(
        requestOptions: RequestOptions(path: '/seatmap'),
        type: DioExceptionType.connectionError,
      );
    }
    if (_server.simulateTimeout) {
      throw DioException(
        requestOptions: RequestOptions(path: '/seatmap'),
        type: DioExceptionType.connectionTimeout,
      );
    }
  }
}
