// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flight_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FlightModelImpl _$$FlightModelImplFromJson(Map<String, dynamic> json) =>
    _$FlightModelImpl(
      flightNumber: json['flightNumber'] as String,
      origin: json['origin'] as String,
      destination: json['destination'] as String,
      status: json['status'] as String,
      scheduledDeparture: json['scheduledDeparture'] as String,
      estimatedDeparture: json['estimatedDeparture'] as String?,
      gate: json['gate'] as String?,
      terminal: json['terminal'] as String?,
      checkInCounter: json['checkInCounter'] as String?,
      boardingTime: json['boardingTime'] as String?,
    );

Map<String, dynamic> _$$FlightModelImplToJson(_$FlightModelImpl instance) =>
    <String, dynamic>{
      'flightNumber': instance.flightNumber,
      'origin': instance.origin,
      'destination': instance.destination,
      'status': instance.status,
      'scheduledDeparture': instance.scheduledDeparture,
      'estimatedDeparture': instance.estimatedDeparture,
      'gate': instance.gate,
      'terminal': instance.terminal,
      'checkInCounter': instance.checkInCounter,
      'boardingTime': instance.boardingTime,
    };
