import 'package:dio/dio.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/agent_escalation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/mock_backend/mock_backend_server.dart';

abstract interface class AgentRemoteDataSource {
  Future<EscalationResult> escalate(EscalationRequest request);
}

class DioAgentRemoteDataSource implements AgentRemoteDataSource {
  DioAgentRemoteDataSource(this._dio);
  final Dio _dio;

  @override
  Future<EscalationResult> escalate(EscalationRequest request) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/chat/message',
      data: {
        'mode': 'escalate',
        'reason': request.reason,
        'summary': request.conversationSummary,
      },
    );
    final data = response.data!;
    return EscalationResult(
      queuePosition: data['queuePosition'] as int? ?? 1,
      estimatedWaitMinutes: data['estimatedWaitMinutes'] as int? ?? 3,
    );
  }
}

class MockAgentRemoteDataSource implements AgentRemoteDataSource {
  MockAgentRemoteDataSource([MockBackendServer? server])
      : _server = server ?? MockBackendServer.instance;
  final MockBackendServer _server;

  @override
  Future<EscalationResult> escalate(EscalationRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (_server.simulateNetworkError) {
      throw DioException(
        requestOptions: RequestOptions(path: '/chat/message'),
        type: DioExceptionType.connectionError,
      );
    }
    return EscalationResult(
      queuePosition: _server.queuePosition,
      estimatedWaitMinutes: _server.estimatedWaitMinutes,
    );
  }
}
