import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';

abstract interface class BaggageRepository {
  /// GET /baggage (allowance view)
  Future<Result<BaggageAllowance>> getBaggageAllowance(String pnr);

  /// GET /baggage (options view)
  Future<Result<List<BaggageOption>>> getBaggageOptions(String flightNumber);

  /// POST /baggage/purchase
  Future<Result<BaggagePurchase>> purchaseBaggage({
    required String pnr,
    required String optionId,
  });
}
