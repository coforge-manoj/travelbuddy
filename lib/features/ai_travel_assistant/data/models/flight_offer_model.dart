import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';

part 'flight_offer_model.freezed.dart';
part 'flight_offer_model.g.dart';

@freezed
class FlightOfferModel with _$FlightOfferModel {
  const FlightOfferModel._();

  const factory FlightOfferModel({
    required String id,
    required String airline,
    required String flightNumber,
    required String origin,
    required String destination,
    required String departureTime,
    required String arrivalTime,
    required num price,
    @Default('USD') String currency,
    @Default(0) int stops,
  }) = _FlightOfferModel;

  factory FlightOfferModel.fromJson(Map<String, dynamic> json) =>
      _$FlightOfferModelFromJson(json);

  FlightOffer toEntity() {
    return FlightOffer(
      id: id,
      airline: airline,
      flightNumber: flightNumber,
      origin: origin,
      destination: destination,
      departureTime: DateTime.parse(departureTime),
      arrivalTime: DateTime.parse(arrivalTime),
      price: price,
      currency: currency,
      stops: stops,
    );
  }
}
