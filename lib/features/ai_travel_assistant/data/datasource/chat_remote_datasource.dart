import 'package:dio/dio.dart';
import 'package:ai_travel_assistant/core/errors/exceptions.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/models/chat_message_model.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/intent.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/mock_backend/mock_backend_server.dart';

abstract interface class ChatRemoteDataSource {
  Future<IntentResult> classifyIntent(String userUtterance);

  Future<ChatMessageModel> generateReply({
    required String userUtterance,
    required List<ChatMessageModel> history,
  });
}

/// Provider-agnostic wrapper around an LLM chat-completions style endpoint.
/// Defaults to the shape of OpenAI's Responses API but only depends on
/// [Dio] + a configurable [model], so any compatible provider can be
/// substituted at the DI layer without touching the domain or repository.
class OpenAiChatRemoteDataSource implements ChatRemoteDataSource {
  OpenAiChatRemoteDataSource(this._dio, {this.model = 'gpt-4.1-mini'});
  final Dio _dio;
  final String model;

  @override
  Future<IntentResult> classifyIntent(String userUtterance) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/chat/message',
      data: {
        'model': model,
        'mode': 'intent_classification',
        'input': userUtterance,
      },
    );
    final data = response.data!;
    return IntentResult(
      type: IntentType.values.firstWhere(
        (t) => t.name == data['intent'],
        orElse: () => IntentType.unknown,
      ),
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0.0,
      entities: (data['entities'] as Map?)?.cast<String, String>() ?? const {},
    );
  }

  @override
  Future<ChatMessageModel> generateReply({
    required String userUtterance,
    required List<ChatMessageModel> history,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/chat/message',
      data: {
        'model': model,
        'mode': 'reply',
        'input': userUtterance,
        'history': history.map((m) => m.toJson()).toList(),
      },
    );
    return ChatMessageModel.fromJson(response.data!);
  }
}

/// Keyword-based mock, backed by [MockBackendServer], so the module runs
/// end-to-end before a real AI backend is wired in.
class MockChatRemoteDataSource implements ChatRemoteDataSource {
  MockChatRemoteDataSource([MockBackendServer? server])
      : _server = server ?? MockBackendServer.instance;
  final MockBackendServer _server;

  @override
  Future<IntentResult> classifyIntent(String userUtterance) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (_server.simulateAiTimeout) throw const AiTimeoutException();
    return _server.classifyIntent(userUtterance);
  }

  @override
  Future<ChatMessageModel> generateReply({
    required String userUtterance,
    required List<ChatMessageModel> history,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (_server.simulateAiTimeout) throw const AiTimeoutException();
    return ChatMessageModel(
      id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
      role: 'assistant',
      type: 'text',
      timestamp: DateTime.now().toIso8601String(),
      text: _server.generateReplyText(userUtterance),
    );
  }
}
