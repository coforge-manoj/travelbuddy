import 'package:mocktail/mocktail.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/agent_repository.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/airport_repository.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/baggage_repository.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/chat_history_repository.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/chat_repository.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/flight_repository.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/seat_repository.dart';

/// Mocktail doubles for every domain repository interface. Use-case tests
/// mock exactly one of these; [ChatViewModel] tests wire up all seven so
/// the whole intent-routing flow can be exercised without touching Dio,
/// Hive, or the mock backend.
class MockChatRepository extends Mock implements ChatRepository {}

class MockFlightRepository extends Mock implements FlightRepository {}

class MockSeatRepository extends Mock implements SeatRepository {}

class MockBaggageRepository extends Mock implements BaggageRepository {}

class MockAirportRepository extends Mock implements AirportRepository {}

class MockAgentRepository extends Mock implements AgentRepository {}

class MockChatHistoryRepository extends Mock implements ChatHistoryRepository {}
