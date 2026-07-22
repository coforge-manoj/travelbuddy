// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BookingModelImpl _$$BookingModelImplFromJson(Map<String, dynamic> json) =>
    _$BookingModelImpl(
      pnr: json['pnr'] as String,
      passengerName: json['passengerName'] as String,
      flight: FlightModel.fromJson(json['flight'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$BookingModelImplToJson(_$BookingModelImpl instance) =>
    <String, dynamic>{
      'pnr': instance.pnr,
      'passengerName': instance.passengerName,
      'flight': instance.flight,
    };
