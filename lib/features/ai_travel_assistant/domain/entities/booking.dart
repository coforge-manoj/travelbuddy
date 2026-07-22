import 'package:equatable/equatable.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight.dart';

class Booking extends Equatable {
  const Booking({
    required this.pnr,
    required this.passengerName,
    required this.flight,
  });

  final String pnr;
  final String passengerName;
  final Flight flight;

  @override
  List<Object?> get props => [pnr, passengerName, flight];
}
