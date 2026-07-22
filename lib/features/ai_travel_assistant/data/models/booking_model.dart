import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/models/flight_model.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking.dart';

part 'booking_model.freezed.dart';
part 'booking_model.g.dart';

@freezed
class BookingModel with _$BookingModel {
  const BookingModel._();

  const factory BookingModel({
    required String pnr,
    required String passengerName,
    required FlightModel flight,
  }) = _BookingModel;

  factory BookingModel.fromJson(Map<String, dynamic> json) => _$BookingModelFromJson(json);

  Booking toEntity() =>
      Booking(pnr: pnr, passengerName: passengerName, flight: flight.toEntity());
}
