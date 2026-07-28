import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/flight_repository.dart';

class BookFlightUseCase {
  const BookFlightUseCase(this._flightRepository);
  final FlightRepository _flightRepository;

  Future<Result<Booking>> call({required String offerId, required String passengerName}) {
    return _flightRepository.bookFlight(offerId: offerId, passengerName: passengerName);
  }
}
