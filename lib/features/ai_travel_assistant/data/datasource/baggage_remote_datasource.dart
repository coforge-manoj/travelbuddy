import 'package:dio/dio.dart';
import 'package:ai_travel_assistant/core/errors/exceptions.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/models/baggage_model.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/mock_backend/mock_backend_server.dart';

abstract interface class BaggageRemoteDataSource {
  Future<BaggageAllowanceModel> getBaggageAllowance(String pnr);
  Future<List<BaggageOptionModel>> getBaggageOptions(String flightNumber);
  Future<BaggagePurchaseModel> purchaseBaggage({required String pnr, required String optionId});
}

class DioBaggageRemoteDataSource implements BaggageRemoteDataSource {
  DioBaggageRemoteDataSource(this._dio);
  final Dio _dio;

  @override
  Future<BaggageAllowanceModel> getBaggageAllowance(String pnr) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/baggage',
      queryParameters: {'pnr': pnr, 'view': 'allowance'},
    );
    return BaggageAllowanceModel.fromJson(response.data!);
  }

  @override
  Future<List<BaggageOptionModel>> getBaggageOptions(String flightNumber) async {
    final response = await _dio.get<List<dynamic>>(
      '/baggage',
      queryParameters: {'flightNumber': flightNumber, 'view': 'options'},
    );
    return response.data!.cast<Map<String, dynamic>>().map(BaggageOptionModel.fromJson).toList();
  }

  @override
  Future<BaggagePurchaseModel> purchaseBaggage({
    required String pnr,
    required String optionId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/baggage/purchase',
      data: {'pnr': pnr, 'optionId': optionId},
    );
    return BaggagePurchaseModel.fromJson(response.data!);
  }
}

class MockBaggageRemoteDataSource implements BaggageRemoteDataSource {
  MockBaggageRemoteDataSource([MockBackendServer? server])
      : _server = server ?? MockBackendServer.instance;
  final MockBackendServer _server;

  @override
  Future<BaggageAllowanceModel> getBaggageAllowance(String pnr) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _maybeThrowNetworkFailure();
    return _server.baggageAllowance(pnr);
  }

  @override
  Future<List<BaggageOptionModel>> getBaggageOptions(String flightNumber) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _maybeThrowNetworkFailure();
    return _server.baggageOptions(flightNumber);
  }

  @override
  Future<BaggagePurchaseModel> purchaseBaggage({
    required String pnr,
    required String optionId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _maybeThrowNetworkFailure();
    final purchase = _server.purchaseBaggage(pnr: pnr, optionId: optionId);
    if (purchase == null) throw const PaymentDeclinedException();
    return purchase;
  }

  void _maybeThrowNetworkFailure() {
    if (_server.simulateNetworkError) {
      throw DioException(
        requestOptions: RequestOptions(path: '/baggage'),
        type: DioExceptionType.connectionError,
      );
    }
    if (_server.simulateTimeout) {
      throw DioException(
        requestOptions: RequestOptions(path: '/baggage'),
        type: DioExceptionType.connectionTimeout,
      );
    }
  }
}
