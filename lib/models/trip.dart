import 'flight.dart';

enum TripStatus { upcoming, active, completed, cancelled }

class TripPassenger {
  final String firstName;
  final String lastName;
  final String? passportNumber;
  final DateTime? passportExpiry;
  final String? nationality;
  final String seatNumber;
  final String ticketClass;

  const TripPassenger({
    required this.firstName,
    required this.lastName,
    this.passportNumber,
    this.passportExpiry,
    this.nationality,
    required this.seatNumber,
    required this.ticketClass,
  });

  String get fullName => '$firstName $lastName';
}

class Trip {
  final String id;
  final String bookingReference;
  final List<Flight> flights;
  final List<TripPassenger> passengers;
  final TripStatus status;
  final DateTime createdAt;
  final String? notes;

  const Trip({
    required this.id,
    required this.bookingReference,
    required this.flights,
    required this.passengers,
    required this.status,
    required this.createdAt,
    this.notes,
  });

  Flight get firstFlight => flights.first;
  Flight get lastFlight => flights.last;

  String get origin => firstFlight.departureCity;
  String get destination => lastFlight.arrivalCity;
  String get originCode => firstFlight.departureAirport;
  String get destinationCode => lastFlight.arrivalAirport;

  DateTime get departureDate => firstFlight.scheduledDeparture;
  DateTime get arrivalDate => lastFlight.scheduledArrival;

  bool get isMultiCity => flights.length > 1;
}
