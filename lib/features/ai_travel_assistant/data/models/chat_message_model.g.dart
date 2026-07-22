// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChatMessageModelImpl _$$ChatMessageModelImplFromJson(
        Map<String, dynamic> json) =>
    _$ChatMessageModelImpl(
      id: json['id'] as String,
      role: json['role'] as String,
      type: json['type'] as String,
      timestamp: json['timestamp'] as String,
      text: json['text'] as String? ?? '',
      payload: json['payload'] as Map<String, dynamic>?,
      isStreaming: json['isStreaming'] as bool? ?? false,
    );

Map<String, dynamic> _$$ChatMessageModelImplToJson(
        _$ChatMessageModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'role': instance.role,
      'type': instance.type,
      'timestamp': instance.timestamp,
      'text': instance.text,
      'payload': instance.payload,
      'isStreaming': instance.isStreaming,
    };
