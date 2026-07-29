import 'package:equatable/equatable.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking.dart';

/// Aggregates a completed [Booking] with the seat and extra baggage chosen
/// during the guided booking flow, for the final itinerary card.
class BookingSummary extends Equatable {
  const BookingSummary({
    required this.booking,
    this.seatNumber,
    this.extraBaggageKg = 0,
  });

  final Booking booking;
  final String? seatNumber;
  final num extraBaggageKg;

  @override
  List<Object?> get props => [booking, seatNumber, extraBaggageKg];
}
