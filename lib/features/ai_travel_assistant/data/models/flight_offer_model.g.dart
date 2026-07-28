// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flight_offer_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FlightOfferModelImpl _$$FlightOfferModelImplFromJson(
        Map<String, dynamic> json) =>
    _$FlightOfferModelImpl(
      id: json['id'] as String,
      airline: json['airline'] as String,
      flightNumber: json['flightNumber'] as String,
      origin: json['origin'] as String,
      destination: json['destination'] as String,
      departureTime: json['departureTime'] as String,
      arrivalTime: json['arrivalTime'] as String,
      price: json['price'] as num,
      currency: json['currency'] as String? ?? 'USD',
      stops: (json['stops'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$FlightOfferModelImplToJson(
        _$FlightOfferModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'airline': instance.airline,
      'flightNumber': instance.flightNumber,
      'origin': instance.origin,
      'destination': instance.destination,
      'departureTime': instance.departureTime,
      'arrivalTime': instance.arrivalTime,
      'price': instance.price,
      'currency': instance.currency,
      'stops': instance.stops,
    };
