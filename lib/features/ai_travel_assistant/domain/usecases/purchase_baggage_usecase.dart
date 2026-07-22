import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/baggage_repository.dart';

class PurchaseBaggageUseCase {
  const PurchaseBaggageUseCase(this._baggageRepository);
  final BaggageRepository _baggageRepository;

  Future<Result<BaggagePurchase>> call({
    required String pnr,
    required String optionId,
  }) {
    return _baggageRepository.purchaseBaggage(pnr: pnr, optionId: optionId);
  }
}
