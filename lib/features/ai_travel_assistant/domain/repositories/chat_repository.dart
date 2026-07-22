import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/intent.dart';

/// Talks to the AI provider (OpenAI Responses API, or any other provider
/// hidden behind this interface) to classify intent and generate replies.
abstract interface class ChatRepository {
  Future<Result<IntentResult>> classifyIntent(String userUtterance);

  /// Generates the assistant's natural-language reply for a user message,
  /// given the recent conversation history for context.
  Future<Result<ChatMessage>> generateReply({
    required String userUtterance,
    required List<ChatMessage> history,
  });
}
