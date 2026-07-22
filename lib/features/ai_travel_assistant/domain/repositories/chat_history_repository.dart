import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';

/// Local persistence for chat history (Hive-backed), separate from
/// [ChatRepository] which talks to the remote AI provider.
abstract interface class ChatHistoryRepository {
  Future<Result<List<ChatMessage>>> loadHistory();
  Future<Result<void>> saveMessage(ChatMessage message);
  Future<Result<void>> clearHistory();
}
