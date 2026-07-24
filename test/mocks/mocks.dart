import 'package:mocktail/mocktail.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/agent_repository.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/airport_repository.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/baggage_repository.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/chat_history_repository.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/chat_repository.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/flight_repository.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/seat_repository.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/services/llm/llm_service.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/run_assistant_turn_usecase.dart';

/// Mocktail doubles for every domain repository interface. Use-case tests
/// mock exactly one of these; the orchestrator test wires a few together so
/// the tool loop can be exercised without touching Dio, Hive, or a real LLM.
class MockChatRepository extends Mock implements ChatRepository {}

class MockFlightRepository extends Mock implements FlightRepository {}

class MockSeatRepository extends Mock implements SeatRepository {}

class MockBaggageRepository extends Mock implements BaggageRepository {}

class MockAirportRepository extends Mock implements AirportRepository {}

class MockAgentRepository extends Mock implements AgentRepository {}

class MockChatHistoryRepository extends Mock implements ChatHistoryRepository {}

/// The Gemini adapter, so the orchestrator can be driven with scripted
/// tool-call / summary responses instead of hitting the network.
class MockLlmService extends Mock implements LlmService {}

/// The assistant orchestrator, so [ChatViewModel] tests can assert how it
/// appends the returned messages without exercising the LLM loop itself.
class MockRunAssistantTurnUseCase extends Mock
    implements RunAssistantTurnUseCase {}
