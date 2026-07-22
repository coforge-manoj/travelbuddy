import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/intent.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/chat_repository.dart';

class ClassifyIntentUseCase {
  const ClassifyIntentUseCase(this._chatRepository);
  final ChatRepository _chatRepository;

  Future<Result<IntentResult>> call(String userUtterance) {
    return _chatRepository.classifyIntent(userUtterance);
  }
}
