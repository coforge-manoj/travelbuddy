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
      ];
}
