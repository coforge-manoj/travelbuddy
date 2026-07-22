import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/core/utils/safe_call.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/datasource/baggage_remote_datasource.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/baggage_repository.dart';

class BaggageRepositoryImpl implements BaggageRepository {
  const BaggageRepositoryImpl(this._remote);
  final BaggageRemoteDataSource _remote;

  @override
  Future<Result<BaggageAllowance>> getBaggageAllowance(String pnr) async {
    final result = await safeCall(() => _remote.getBaggageAllowance(pnr));
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Result<List<BaggageOption>>> getBaggageOptions(String flightNumber) async {
    final result = await safeCall(() => _remote.getBaggageOptions(flightNumber));
    return result.map((models) => models.map((m) => m.toEntity()).toList());
  }

  @override
  Future<Result<BaggagePurchase>> purchaseBaggage({
    required String pnr,
    required String optionId,
  }) async {
    final result = await safeCall(() => _remote.purchaseBaggage(pnr: pnr, optionId: optionId));
    return result.map((model) => model.toEntity());
  }
}
