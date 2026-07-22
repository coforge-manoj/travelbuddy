import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/agent_escalation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/agent_repository.dart';

class EscalateToAgentUseCase {
  const EscalateToAgentUseCase(this._agentRepository);
  final AgentRepository _agentRepository;

  Future<Result<EscalationResult>> call(EscalationRequest request) {
    return _agentRepository.escalate(request);
  }
}
