// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'airport_info_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AirportInfoModelImpl _$$AirportInfoModelImplFromJson(
        Map<String, dynamic> json) =>
    _$AirportInfoModelImpl(
      terminal: json['terminal'] as String,
      checkInCounter: json['checkInCounter'] as String,
      gate: json['gate'] as String,
      walkingTimeMinutes: (json['walkingTimeMinutes'] as num).toInt(),
      indoorMapAssetPath: json['indoorMapAssetPath'] as String?,
      directions: (json['directions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
    );

Map<String, dynamic> _$$AirportInfoModelImplToJson(
        _$AirportInfoModelImpl instance) =>
    <String, dynamic>{
      'terminal': instance.terminal,
      'checkInCounter': instance.checkInCounter,
      'gate': instance.gate,
      'walkingTimeMinutes': instance.walkingTimeMinutes,
      'indoorMapAssetPath': instance.indoorMapAssetPath,
      'directions': instance.directions,
    };
