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
      status: FlightStatus.values.firstWhere(
        (s) => s.name == status,
        orElse: () => FlightStatus.unknown,
      ),
      scheduledDeparture: DateTime.parse(scheduledDeparture),
      estimatedDeparture:
          estimatedDeparture != null ? DateTime.parse(estimatedDeparture!) : null,
      gate: gate,
      terminal: terminal,
      checkInCounter: checkInCounter,
      boardingTime: boardingTime != null ? DateTime.parse(boardingTime!) : null,
    );
  }
}
