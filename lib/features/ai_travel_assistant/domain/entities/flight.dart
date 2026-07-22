import 'package:equatable/equatable.dart';

enum FlightStatus { scheduled, boarding, delayed, departed, cancelled, landed, unknown }

class Flight extends Equatable {
  const Flight({
    required this.flightNumber,
    required this.origin,
    required this.destination,
    required this.status,
    required this.scheduledDeparture,
    this.estimatedDeparture,
    this.gate,
    this.terminal,
    this.checkInCounter,
    this.boardingTime,
  });

  final String flightNumber;
  final String origin;
  final String destination;
  final FlightStatus status;
  final DateTime scheduledDeparture;
  final DateTime? estimatedDeparture;
  final String? gate;
  final String? terminal;
  final String? checkInCounter;
  final DateTime? boardingTime;

  bool get isDelayed => status == FlightStatus.delayed;

  @override
  List<Object?> get props => [
        flightNumber,
        origin,
        destination,
        status,
        scheduledDeparture,
        estimatedDeparture,
        gate,
        terminal,
        checkInCounter,
        boardingTime,
      ];
}
