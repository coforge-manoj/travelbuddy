import 'package:flutter/material.dart';

enum FlightStatus { scheduled, onTime, delayed, cancelled, departed, arrived }

class Flight {
  final String flightNumber;
  final String airline;
  final String airlineCode;
  final String departureAirport;
  final String departureCity;
  final String arrivalAirport;
  final String arrivalCity;
  final DateTime scheduledDeparture;
  final DateTime scheduledArrival;
  final DateTime? actualDeparture;
  final DateTime? actualArrival;
  final FlightStatus status;
  final String? terminal;
  final String? gate;
  final String? seatNumber;
  final String? bookingReference;
  final int delayMinutes;

  const Flight({
    required this.flightNumber,
    required this.airline,
    required this.airlineCode,
    required this.departureAirport,
    required this.departureCity,
    required this.arrivalAirport,
    required this.arrivalCity,
    required this.scheduledDeparture,
    required this.scheduledArrival,
    this.actualDeparture,
    this.actualArrival,
    required this.status,
    this.terminal,
    this.gate,
    this.seatNumber,
    this.bookingReference,
    this.delayMinutes = 0,
  });

  Duration get flightDuration =>
      scheduledArrival.difference(scheduledDeparture);

  String get statusLabel {
    switch (status) {
      case FlightStatus.scheduled:
        return 'Scheduled';
      case FlightStatus.onTime:
        return 'On Time';
      case FlightStatus.delayed:
        return 'Delayed ${delayMinutes}m';
      case FlightStatus.cancelled:
        return 'Cancelled';
      case FlightStatus.departed:
        return 'Departed';
      case FlightStatus.arrived:
        return 'Arrived';
    }
  }

  Color get statusColor {
    switch (status) {
      case FlightStatus.scheduled:
      case FlightStatus.onTime:
        return const Color(0xFF388E3C);
      case FlightStatus.delayed:
        return const Color(0xFFF57C00);
      case FlightStatus.cancelled:
        return const Color(0xFFD32F2F);
      case FlightStatus.departed:
      case FlightStatus.arrived:
        return const Color(0xFF1565C0);
    }
  }
}
