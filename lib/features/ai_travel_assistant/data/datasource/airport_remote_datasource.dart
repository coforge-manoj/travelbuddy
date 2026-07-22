import 'package:dio/dio.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/models/airport_info_model.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/mock_backend/mock_backend_server.dart';

abstract interface class AirportRemoteDataSource {
  Future<AirportInfoModel> getAirportDetails({
    required String flightNumber,
    required String airportCode,
  });
}

class DioAirportRemoteDataSource implements AirportRemoteDataSource {
  DioAirportRemoteDataSource(this._dio);
  final Dio _dio;

  @override
  Future<AirportInfoModel> getAirportDetails({
    required String flightNumber,
    required String airportCode,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/airport/details',
      queryParameters: {'flightNumber': flightNumber, 'airportCode': airportCode},
    );
    return AirportInfoModel.fromJson(response.data!);
  }
}

class MockAirportRemoteDataSource implements AirportRemoteDataSource {
  MockAirportRemoteDataSource([MockBackendServer? server])
      : _server = server ?? MockBackendServer.instance;
  final MockBackendServer _server;

  @override
  Future<AirportInfoModel> getAirportDetails({
    required String flightNumber,
    required String airportCode,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (_server.simulateNetworkError) {
      throw DioException(
        requestOptions: RequestOptions(path: '/airport/details'),
        type: DioExceptionType.connectionError,
      );
    }
    return _server.airportInfo(flightNumber: flightNumber, airportCode: airportCode);
  }
}
