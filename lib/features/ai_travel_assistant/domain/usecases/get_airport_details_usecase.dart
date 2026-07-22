import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/airport_info.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/airport_repository.dart';

class GetAirportDetailsUseCase {
  const GetAirportDetailsUseCase(this._airportRepository);
  final AirportRepository _airportRepository;

  Future<Result<AirportInfo>> call({
    required String flightNumber,
    required String airportCode,
  }) {
    return _airportRepository.getAirportDetails(
      flightNumber: flightNumber,
      airportCode: airportCode,
    );
  }
}
