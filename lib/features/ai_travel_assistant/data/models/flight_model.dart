import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight.dart';

part 'flight_model.freezed.dart';
part 'flight_model.g.dart';

@freezed
class FlightModel with _$FlightModel {
  const FlightModel._();

  const factory FlightModel({
    required String flightNumber,
    required String origin,
    required String destination,
    required String status,
    required String scheduledDeparture,
    String? estimatedDeparture,
    String? gate,
    String? terminal,
    String? checkInCounter,
    String? boardingTime,
  }) = _FlightModel;

  factory FlightModel.fromJson(Map<String, dynamic> json) => _$FlightModelFromJson(json);

  Flight toEntity() {
    return Flight(
      flightNumber: flightNumber,
      origin: origin,
      destination: destination,
      status: _mapStatus(status),
      scheduledDeparture: DateTime.parse(scheduledDeparture),
      estimatedDeparture: estimatedDeparture != null
          ? DateTime.parse(estimatedDeparture!)
          : null,
      gate: gate,
      terminal: terminal,
      checkInCounter: checkInCounter,
      boardingTime:
      boardingTime != null
          ? DateTime.parse(boardingTime!)
          : null,
    );

  }

  FlightStatus _mapStatus(String? status) {
    switch (status?.toLowerCase().trim()) {
      case 'scheduled':
        return FlightStatus.scheduled;

      case 'boarding':
        return FlightStatus.boarding;

      case 'delayed':
        return FlightStatus.delayed;

      case 'departed':
        return FlightStatus.departed;

      case 'cancelled':
        return FlightStatus.cancelled;

      case 'landed':
        return FlightStatus.landed;

      case 'on time':
        return FlightStatus.scheduled;

      default:
        return FlightStatus.unknown;
    }
  }
}
