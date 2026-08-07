import 'package:equatable/equatable.dart';

/// The `seat_confirmed` card: the seat now held, and what it replaced.
class SeatConfirmation extends Equatable {
  const SeatConfirmation({
    required this.seatNumber,
    this.previousSeatNumber,
    this.cabin = '',
    this.flightNumber = '',
    this.price = 0,
    this.currency = 'USD',
    this.type,
  });

  final String seatNumber;
  final String? previousSeatNumber;
  final String cabin;
  final String flightNumber;

  /// What the change cost, if anything — often zero for a same-cabin move.
  final num price;
  final String currency;
  final String? type;

  @override
  List<Object?> get props => [
        seatNumber,
        previousSeatNumber,
        cabin,
        flightNumber,
        price,
        currency,
        type,
      ];
}
