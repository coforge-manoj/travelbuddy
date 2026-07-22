import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/core/utils/safe_call.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/datasource/agent_remote_datasource.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/agent_escalation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/agent_repository.dart';

class AgentRepositoryImpl implements AgentRepository {
  const AgentRepositoryImpl(this._remote);
  final AgentRemoteDataSource _remote;

  @override
  Future<Result<EscalationResult>> escalate(EscalationRequest request) {
    return safeCall(() => _remote.escalate(request));
  }
}
