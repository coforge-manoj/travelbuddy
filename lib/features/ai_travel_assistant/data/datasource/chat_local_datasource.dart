import 'package:hive/hive.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/models/chat_message_model.dart';

abstract interface class ChatLocalDataSource {
  Future<List<ChatMessageModel>> loadHistory();
  Future<void> saveMessage(ChatMessageModel message);
  Future<void> clearHistory();
}

/// Hive-backed persistence for chat history. Expects a box named [boxName]
/// to have been opened during app start-up (see the module setup guide),
/// storing each message as its JSON map keyed by message id so writes are
/// idempotent.
class HiveChatLocalDataSource implements ChatLocalDataSource {
  HiveChatLocalDataSource(this._box);

  static const boxName = 'ai_travel_assistant_chat_history';
  final Box<Map<dynamic, dynamic>> _box;

  @override
  Future<List<ChatMessageModel>> loadHistory() async {
    final messages = _box.values
        .map((raw) => ChatMessageModel.fromJson(Map<String, dynamic>.from(raw)))
        .toList();
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  }

  @override
  Future<void> saveMessage(ChatMessageModel message) async {
    await _box.put(message.id, message.toJson());
  }

  @override
  Future<void> clearHistory() async {
    await _box.clear();
  }
}
