import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/chat_history_repository.dart';

class LoadChatHistoryUseCase {
  const LoadChatHistoryUseCase(this._repository);
  final ChatHistoryRepository _repository;

  Future<Result<List<ChatMessage>>> call() => _repository.loadHistory();
}

class SaveChatMessageUseCase {
  const SaveChatMessageUseCase(this._repository);
  final ChatHistoryRepository _repository;

  Future<Result<void>> call(ChatMessage message) => _repository.saveMessage(message);
}

class ClearChatHistoryUseCase {
  const ClearChatHistoryUseCase(this._repository);
  final ChatHistoryRepository _repository;

  Future<Result<void>> call() => _repository.clearHistory();
}
