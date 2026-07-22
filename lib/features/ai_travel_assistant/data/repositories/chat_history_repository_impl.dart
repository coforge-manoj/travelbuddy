import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/core/utils/safe_call.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/datasource/chat_local_datasource.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/models/chat_message_model.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/chat_history_repository.dart';

class ChatHistoryRepositoryImpl implements ChatHistoryRepository {
  const ChatHistoryRepositoryImpl(this._local);
  final ChatLocalDataSource _local;

  @override
  Future<Result<List<ChatMessage>>> loadHistory() async {
    final result = await safeCall(_local.loadHistory);
    return result.map((models) => models.map((m) => m.toEntity()).toList());
  }

  @override
  Future<Result<void>> saveMessage(ChatMessage message) {
    return safeCall(() => _local.saveMessage(ChatMessageModel.fromEntity(message)));
  }

  @override
  Future<Result<void>> clearHistory() {
    return safeCall(_local.clearHistory);
  }
}
