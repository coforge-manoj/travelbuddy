import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/core/utils/safe_call.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/datasource/flight_remote_datasource.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/flight_repository.dart';

class FlightRepositoryImpl implements FlightRepository {
  const FlightRepositoryImpl(this._remote);
  final FlightRemoteDataSource _remote;

  @override
  Future<Result<Flight>> getFlightStatus(String flightNumber) async {
    final result = await safeCall(() => _remote.getFlightStatus(flightNumber));
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Result<Booking>> getBooking(String pnr) async {
    final result = await safeCall(() => _remote.getBooking(pnr));
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Result<List<FlightOffer>>> searchFlights({
    required String origin,
    required String destination,
  }) async {
    final result = await safeCall(
      () => _remote.searchFlights(origin: origin, destination: destination),
    );
    return result.map((models) => models.map((m) => m.toEntity()).toList());
  }

  @override
  Future<Result<Booking>> bookFlight({required String offerId, required String passengerName}) async {
    final result = await safeCall(
      () => _remote.bookFlight(offerId: offerId, passengerName: passengerName),
    );
    return result.map((model) => model.toEntity());
  }
}
