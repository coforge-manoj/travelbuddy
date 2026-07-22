import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat.dart';

part 'seat_model.freezed.dart';
part 'seat_model.g.dart';

@freezed
class SeatModel with _$SeatModel {
  const SeatModel._();

  const factory SeatModel({
    required String seatNumber,
    required int row,
    required String column,
    required String type,
    required String availability,
    @Default(0) num priceDelta,
    @Default(false) bool isExitRow,
  }) = _SeatModel;

  factory SeatModel.fromJson(Map<String, dynamic> json) => _$SeatModelFromJson(json);

  Seat toEntity() {
    return Seat(
      seatNumber: seatNumber,
      row: row,
      column: column,
      type: SeatType.values.firstWhere((t) => t.name == type, orElse: () => SeatType.middle),
      availability: SeatAvailability.values.firstWhere(
        (a) => a.name == availability,
        orElse: () => SeatAvailability.blocked,
      ),
      priceDelta: priceDelta,
      isExitRow: isExitRow,
    );
  }
}

@freezed
class SeatMapModel with _$SeatMapModel {
  const SeatMapModel._();

  const factory SeatMapModel({
    required String flightNumber,
    required int rows,
    required List<SeatModel> seats,
    @Default('USD') String currency,
  }) = _SeatMapModel;

  factory SeatMapModel.fromJson(Map<String, dynamic> json) => _$SeatMapModelFromJson(json);

  SeatMap toEntity() {
    return SeatMap(
      flightNumber: flightNumber,
      rows: rows,
      seats: seats.map((s) => s.toEntity()).toList(),
      currency: currency,
    );
  }
}
