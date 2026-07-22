import 'package:equatable/equatable.dart';

enum SeatType { window, middle, aisle }

enum SeatAvailability { available, occupied, selected, blocked }

class Seat extends Equatable {
  const Seat({
    required this.seatNumber,
    required this.row,
    required this.column,
    required this.type,
    required this.availability,
    this.priceDelta = 0,
    this.isExitRow = false,
  });

  final String seatNumber; // e.g. "14A"
  final int row;
  final String column; // e.g. "A"
  final SeatType type;
  final SeatAvailability availability;

  /// Additional cost, in the booking's currency minor units, to select this
  /// seat over the default allocation. 0 for standard seats.
  final num priceDelta;
  final bool isExitRow;

  bool get isAvailable => availability == SeatAvailability.available;

  @override
  List<Object?> get props =>
      [seatNumber, row, column, type, availability, priceDelta, isExitRow];
}

class SeatMap extends Equatable {
  const SeatMap({
    required this.flightNumber,
    required this.rows,
    required this.seats,
    this.currency = 'USD',
  });

  final String flightNumber;
  final int rows;
  final List<Seat> seats;
  final String currency;

  @override
  List<Object?> get props => [flightNumber, rows, seats, currency];
}
