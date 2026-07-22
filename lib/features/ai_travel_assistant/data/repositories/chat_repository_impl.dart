import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/core/utils/safe_call.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/datasource/chat_remote_datasource.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/models/chat_message_model.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/intent.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  const ChatRepositoryImpl(this._remote);
  final ChatRemoteDataSource _remote;

  @override
  Future<Result<IntentResult>> classifyIntent(String userUtterance) {
    return safeCall(() => _remote.classifyIntent(userUtterance));
  }

  @override
  Future<Result<ChatMessage>> generateReply({
    required String userUtterance,
    required List<ChatMessage> history,
  }) async {
    final result = await safeCall(
      () => _remote.generateReply(
        userUtterance: userUtterance,
        history: history.map(ChatMessageModel.fromEntity).toList(),
      ),
    );
    return result.map((model) => model.toEntity());
  }
}
