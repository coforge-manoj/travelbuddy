import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight.dart';

abstract interface class FlightRepository {
  /// GET /flight/status
  Future<Result<Flight>> getFlightStatus(String flightNumber);

  /// GET /booking
  Future<Result<Booking>> getBooking(String pnr);
}
