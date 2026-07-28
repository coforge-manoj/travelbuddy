import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/flight_repository.dart';

class SearchFlightsUseCase {
  const SearchFlightsUseCase(this._flightRepository);
  final FlightRepository _flightRepository;

  Future<Result<List<FlightOffer>>> call({required String origin, required String destination}) {
    return _flightRepository.searchFlights(origin: origin, destination: destination);
  }
}
