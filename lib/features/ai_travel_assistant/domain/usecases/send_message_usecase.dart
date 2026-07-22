import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/chat_repository.dart';

/// Sends a raw user utterance to the AI provider and returns its reply.
/// Intent-specific data-fetching (flight status, seat map, etc.) is
/// orchestrated separately by the ChatViewModel once intent is known.
class SendMessageUseCase {
  const SendMessageUseCase(this._chatRepository);
  final ChatRepository _chatRepository;

  Future<Result<ChatMessage>> call({
    required String userUtterance,
    required List<ChatMessage> history,
  }) {
    return _chatRepository.generateReply(userUtterance: userUtterance, history: history);
  }
}
