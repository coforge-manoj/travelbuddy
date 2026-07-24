import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/models/chat_payload_codec.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';

part 'chat_message_model.freezed.dart';
part 'chat_message_model.g.dart';

@freezed
class ChatMessageModel with _$ChatMessageModel {
  const ChatMessageModel._();

  const factory ChatMessageModel({
    required String id,
    required String role,
    required String type,
    required String timestamp,
    @Default('') String text,
    Map<String, dynamic>? payload,
    @Default(false) bool isStreaming,
  }) = _ChatMessageModel;

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageModelFromJson(json);

  factory ChatMessageModel.fromEntity(ChatMessage entity) {
    return ChatMessageModel(
      id: entity.id,
      role: entity.role.name,
      type: entity.type.name,
      timestamp: entity.timestamp.toIso8601String(),
      text: entity.text,
      payload: ChatPayloadCodec.encode(entity.type, entity.payload),
      isStreaming: entity.isStreaming,
    );
  }

  ChatMessage toEntity() {
    final messageType = ChatMessageType.values.byName(type);
    return ChatMessage(
      id: id,
      role: ChatRole.values.byName(role),
      type: messageType,
      timestamp: DateTime.parse(timestamp),
      text: text,
      payload: ChatPayloadCodec.decode(messageType, payload),
      isStreaming: isStreaming,
    );
  }
}
