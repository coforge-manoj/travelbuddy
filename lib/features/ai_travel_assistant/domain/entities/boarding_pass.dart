import 'package:equatable/equatable.dart';

/// The `boarding_pass` card issued by "check me in": seat, gate, group,
/// boarding time and the barcode payload.
class BoardingPass extends Equatable {
  const BoardingPass({
    required this.pnr,
    this.passengerName = '',
    this.flightNumber = '',
    this.origin = '',
    this.destination = '',
    this.date,
    this.departureTime,
    this.boardingTime,
    this.gate,
    this.terminal,
    this.seat,
    this.boardingGroup,
    this.cabin = '',
    this.barcode,
    this.sequenceNumber,
  });

  final String pnr;
  final String passengerName;
  final String flightNumber;
  final String origin;
  final String destination;

  /// Kept as the backend's own strings — these go straight onto the pass and
  /// are already formatted for the departure airport's local time, so
  /// parsing them into `DateTime` would only invite a timezone shift.
  final String? date;
  final String? departureTime;
  final String? boardingTime;

  final String? gate;
  final String? terminal;
  final String? seat;
  final String? boardingGroup;
  final String cabin;

  /// Payload to encode in the scannable code, when the backend supplies one.
  final String? barcode;
  final String? sequenceNumber;

  @override
  List<Object?> get props => [
        pnr,
        passengerName,
        flightNumber,
        origin,
        destination,
        date,
        departureTime,
        boardingTime,
        gate,
        terminal,
        seat,
        boardingGroup,
        cabin,
        barcode,
        sequenceNumber,
      ];
}
