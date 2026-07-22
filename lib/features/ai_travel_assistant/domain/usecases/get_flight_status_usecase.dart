import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/flight_repository.dart';

class GetFlightStatusUseCase {
  const GetFlightStatusUseCase(this._flightRepository);
  final FlightRepository _flightRepository;

  Future<Result<Flight>> call(String flightNumber) {
    return _flightRepository.getFlightStatus(flightNumber);
  }
}
