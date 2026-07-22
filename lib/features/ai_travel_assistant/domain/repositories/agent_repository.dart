import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/agent_escalation.dart';

abstract interface class AgentRepository {
  Future<Result<EscalationResult>> escalate(EscalationRequest request);
}
