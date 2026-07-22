// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'seat_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SeatModelImpl _$$SeatModelImplFromJson(Map<String, dynamic> json) =>
    _$SeatModelImpl(
      seatNumber: json['seatNumber'] as String,
      row: (json['row'] as num).toInt(),
      column: json['column'] as String,
      type: json['type'] as String,
      availability: json['availability'] as String,
      priceDelta: json['priceDelta'] as num? ?? 0,
      isExitRow: json['isExitRow'] as bool? ?? false,
    );

Map<String, dynamic> _$$SeatModelImplToJson(_$SeatModelImpl instance) =>
    <String, dynamic>{
      'seatNumber': instance.seatNumber,
      'row': instance.row,
      'column': instance.column,
      'type': instance.type,
      'availability': instance.availability,
      'priceDelta': instance.priceDelta,
      'isExitRow': instance.isExitRow,
    };

_$SeatMapModelImpl _$$SeatMapModelImplFromJson(Map<String, dynamic> json) =>
    _$SeatMapModelImpl(
      flightNumber: json['flightNumber'] as String,
      rows: (json['rows'] as num).toInt(),
      seats: (json['seats'] as List<dynamic>)
          .map((e) => SeatModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      currency: json['currency'] as String? ?? 'USD',
    );

Map<String, dynamic> _$$SeatMapModelImplToJson(_$SeatMapModelImpl instance) =>
    <String, dynamic>{
      'flightNumber': instance.flightNumber,
      'rows': instance.rows,
      'seats': instance.seats,
      'currency': instance.currency,
    };
