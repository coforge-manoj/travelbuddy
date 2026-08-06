import 'package:equatable/equatable.dart';

/// A single bookable result from a flight search (as opposed to [Flight],
/// which represents the status of a flight the passenger has already
/// booked).
class FlightOffer extends Equatable {
  const FlightOffer({
    required this.id,
    required this.airline,
    required this.flightNumber,
    required this.origin,
    required this.destination,
    required this.departureTime,
    required this.arrivalTime,
    required this.price,
    this.currency = 'USD',
    this.stops = 0,
    this.aircraft,
    this.seatsLeft,
    this.durationLabel,
    this.recommended = false,
    this.lowest = false,
    this.arrivesNextDay = false,
    this.cabinPrices = const {},
  });

  final String id;
  final String airline;
  final String flightNumber;
  final String origin;
  final String destination;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final num price;
  final String currency;
  final int stops;

  /// Aircraft type from TravelBuddy `flight_list` (e.g. `B777-300ER`).
  final String? aircraft;

  /// Remaining seats reported by the search API.
  final int? seatsLeft;

  /// Human-readable duration from the API (e.g. `9h05`), preferred over
  /// [duration] when present so display matches the backend exactly.
  final String? durationLabel;

  final bool recommended;
  final bool lowest;
  final bool arrivesNextDay;

  /// Cabin → price map from `cabin_prices` on a `flight_list` item.
  final Map<String, num> cabinPrices;

  bool get isNonstop => stops == 0;

  Duration get duration => arrivalTime.difference(departureTime);

  @override
  List<Object?> get props => [
        id,
        airline,
        flightNumber,
        origin,
        destination,
        departureTime,
        arrivalTime,
        price,
        currency,
        stops,
        aircraft,
        seatsLeft,
        durationLabel,
        recommended,
        lowest,
        arrivesNextDay,
        cabinPrices,
      ];
}
