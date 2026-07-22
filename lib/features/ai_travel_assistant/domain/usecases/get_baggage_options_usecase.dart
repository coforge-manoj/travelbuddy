import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/baggage_repository.dart';

class GetBaggageOptionsUseCase {
  const GetBaggageOptionsUseCase(this._baggageRepository);
  final BaggageRepository _baggageRepository;

  Future<Result<List<BaggageOption>>> call(String flightNumber) {
    return _baggageRepository.getBaggageOptions(flightNumber);
  }
}

class GetBaggageAllowanceUseCase {
  const GetBaggageAllowanceUseCase(this._baggageRepository);
  final BaggageRepository _baggageRepository;

  Future<Result<BaggageAllowance>> call(String pnr) {
    return _baggageRepository.getBaggageAllowance(pnr);
  }
}
