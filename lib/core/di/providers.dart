import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'package:ai_travel_assistant/core/config/app_env.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/datasource/agent_remote_datasource.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/datasource/airport_remote_datasource.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/datasource/baggage_remote_datasource.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/datasource/chat_local_datasource.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/datasource/chat_remote_datasource.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/datasource/flight_remote_datasource.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/datasource/seat_remote_datasource.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/services/llm/custom_llm_service.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/services/llm/llm_service.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/services/llm/mock_llm_service.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/repositories/agent_repository_impl.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/repositories/airport_repository_impl.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/repositories/baggage_repository_impl.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/repositories/chat_history_repository_impl.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/repositories/chat_repository_impl.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/repositories/flight_repository_impl.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/repositories/seat_repository_impl.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/agent_repository.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/airport_repository.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/baggage_repository.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/chat_history_repository.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/chat_repository.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/flight_repository.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/seat_repository.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/change_seat_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/chat_history_usecases.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/classify_intent_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/escalate_to_agent_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/get_airport_details_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/get_baggage_options_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/get_flight_status_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/get_seat_map_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/purchase_baggage_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/run_assistant_turn_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/send_message_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_service.dart';

/// Toggle between the real Dio-backed data sources and the in-memory mocks.
/// Defaults to `true` because the mock backend (Phase 12) is the only one
/// available until the host app wires in real endpoints — override this
/// provider once real endpoints exist:
/// `ProviderScope(overrides: [useMockBackendProvider.overrideWithValue(false)])`.
final useMockBackendProvider = Provider<bool>((ref) => true);

final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: 'https://api.example-airline.com/v1',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
});

/// Wraps speech-to-text + text-to-speech for Phase 11's voice integration.
/// Disposed automatically when the provider scope is torn down.
final voiceServiceProvider = Provider<VoiceService>((ref) {
  final service = VoiceService();
  ref.onDispose(service.dispose);
  return service;
});

/// The Hive box backing local chat history. Must be overridden in `main()`
/// after `Hive.openBox<Map>(HiveChatLocalDataSource.boxName)` resolves — see
/// the setup guide for details.
final chatHistoryBoxProvider = Provider<Box<Map<dynamic, dynamic>>>((ref) {
  throw UnimplementedError(
    'chatHistoryBoxProvider must be overridden with an opened Hive box in main().',
  );
});

// ---------------------------------------------------------------------------
// Data sources
// ---------------------------------------------------------------------------

final flightRemoteDataSourceProvider = Provider<FlightRemoteDataSource>((ref) {
  return ref.watch(useMockBackendProvider)
      ? MockFlightRemoteDataSource()
      : DioFlightRemoteDataSource(ref.watch(dioProvider));
});

final seatRemoteDataSourceProvider = Provider<SeatRemoteDataSource>((ref) {
  return ref.watch(useMockBackendProvider)
      ? MockSeatRemoteDataSource()
      : DioSeatRemoteDataSource(ref.watch(dioProvider));
});

final baggageRemoteDataSourceProvider = Provider<BaggageRemoteDataSource>((ref) {
  return ref.watch(useMockBackendProvider)
      ? MockBaggageRemoteDataSource()
      : DioBaggageRemoteDataSource(ref.watch(dioProvider));
});

final airportRemoteDataSourceProvider = Provider<AirportRemoteDataSource>((ref) {
  return ref.watch(useMockBackendProvider)
      ? MockAirportRemoteDataSource()
      : DioAirportRemoteDataSource(ref.watch(dioProvider));
});

final chatRemoteDataSourceProvider = Provider<ChatRemoteDataSource>((ref) {
  return ref.watch(useMockBackendProvider)
      ? MockChatRemoteDataSource()
      : OpenAiChatRemoteDataSource(ref.watch(dioProvider));
});

final agentRemoteDataSourceProvider = Provider<AgentRemoteDataSource>((ref) {
  return ref.watch(useMockBackendProvider)
      ? MockAgentRemoteDataSource()
      : DioAgentRemoteDataSource(ref.watch(dioProvider));
});

final chatLocalDataSourceProvider = Provider<ChatLocalDataSource>((ref) {
  return HiveChatLocalDataSource(ref.watch(chatHistoryBoxProvider));
});

// ---------------------------------------------------------------------------
// Repositories
// ---------------------------------------------------------------------------

final flightRepositoryProvider = Provider<FlightRepository>((ref) {
  return FlightRepositoryImpl(ref.watch(flightRemoteDataSourceProvider));
});

final seatRepositoryProvider = Provider<SeatRepository>((ref) {
  return SeatRepositoryImpl(ref.watch(seatRemoteDataSourceProvider));
});

final baggageRepositoryProvider = Provider<BaggageRepository>((ref) {
  return BaggageRepositoryImpl(ref.watch(baggageRemoteDataSourceProvider));
});

final airportRepositoryProvider = Provider<AirportRepository>((ref) {
  return AirportRepositoryImpl(ref.watch(airportRemoteDataSourceProvider));
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(ref.watch(chatRemoteDataSourceProvider));
});

final agentRepositoryProvider = Provider<AgentRepository>((ref) {
  return AgentRepositoryImpl(ref.watch(agentRemoteDataSourceProvider));
});

final chatHistoryRepositoryProvider = Provider<ChatHistoryRepository>((ref) {
  return ChatHistoryRepositoryImpl(ref.watch(chatLocalDataSourceProvider));
});

// ---------------------------------------------------------------------------
// Use cases
// ---------------------------------------------------------------------------

final sendMessageUseCaseProvider = Provider<SendMessageUseCase>((ref) {
  return SendMessageUseCase(ref.watch(chatRepositoryProvider));
});

final classifyIntentUseCaseProvider = Provider<ClassifyIntentUseCase>((ref) {
  return ClassifyIntentUseCase(ref.watch(chatRepositoryProvider));
});

final getFlightStatusUseCaseProvider = Provider<GetFlightStatusUseCase>((ref) {
  return GetFlightStatusUseCase(ref.watch(flightRepositoryProvider));
});

final getSeatMapUseCaseProvider = Provider<GetSeatMapUseCase>((ref) {
  return GetSeatMapUseCase(ref.watch(seatRepositoryProvider));
});

final changeSeatUseCaseProvider = Provider<ChangeSeatUseCase>((ref) {
  return ChangeSeatUseCase(ref.watch(seatRepositoryProvider));
});

final getBaggageOptionsUseCaseProvider = Provider<GetBaggageOptionsUseCase>((ref) {
  return GetBaggageOptionsUseCase(ref.watch(baggageRepositoryProvider));
});

final getBaggageAllowanceUseCaseProvider = Provider<GetBaggageAllowanceUseCase>((ref) {
  return GetBaggageAllowanceUseCase(ref.watch(baggageRepositoryProvider));
});

final purchaseBaggageUseCaseProvider = Provider<PurchaseBaggageUseCase>((ref) {
  return PurchaseBaggageUseCase(ref.watch(baggageRepositoryProvider));
});

final getAirportDetailsUseCaseProvider = Provider<GetAirportDetailsUseCase>((ref) {
  return GetAirportDetailsUseCase(ref.watch(airportRepositoryProvider));
});

final escalateToAgentUseCaseProvider = Provider<EscalateToAgentUseCase>((ref) {
  return EscalateToAgentUseCase(ref.watch(agentRepositoryProvider));
});

final loadChatHistoryUseCaseProvider = Provider<LoadChatHistoryUseCase>((ref) {
  return LoadChatHistoryUseCase(ref.watch(chatHistoryRepositoryProvider));
});

final saveChatMessageUseCaseProvider = Provider<SaveChatMessageUseCase>((ref) {
  return SaveChatMessageUseCase(ref.watch(chatHistoryRepositoryProvider));
});

final clearChatHistoryUseCaseProvider = Provider<ClearChatHistoryUseCase>((ref) {
  return ClearChatHistoryUseCase(ref.watch(chatHistoryRepositoryProvider));
});

// ---------------------------------------------------------------------------
// LLM (Gemini) + assistant orchestrator
// ---------------------------------------------------------------------------

/// The LLM adapter behind the Generative-UI loop. Uses the custom
/// OpenAI-compatible gateway (Gemini Flash 2.5 via the Coforge QAG router) when
/// `CUSTOM_LLM_URL` + `CUSTOM_LLM_API_KEY` are set, and otherwise falls back to
/// [MockLlmService] so the assistant — and every rich card, including seat
/// selection — works fully offline with no API key. Force either one by
/// overriding this provider in a `ProviderScope`.
final llmServiceProvider = Provider<LlmService>((ref) {
  if (AppEnv.hasCustomLlm) {
    return CustomLlmService(
      url: AppEnv.customLlmUrl,
      model: AppEnv.customLlmModel,
    );
  }
  return MockLlmService();
});

/// Runs one assistant turn: Gemini picks a tool → the matching use case runs
/// against the (mock) backend → a summary + rich card message(s) come back.
/// Replaces the old keyword `ClassifyIntent` routing.
final runAssistantTurnUseCaseProvider = Provider<RunAssistantTurnUseCase>((ref) {
  return RunAssistantTurnUseCase(
    llmService: ref.watch(llmServiceProvider),
    apiKey: () => AppEnv.customLlmApiKey,
    getFlightStatus: ref.watch(getFlightStatusUseCaseProvider),
    getSeatMap: ref.watch(getSeatMapUseCaseProvider),
    getBaggageOptions: ref.watch(getBaggageOptionsUseCaseProvider),
    getBaggageAllowance: ref.watch(getBaggageAllowanceUseCaseProvider),
    getAirportDetails: ref.watch(getAirportDetailsUseCaseProvider),
    escalateToAgent: ref.watch(escalateToAgentUseCaseProvider),
  );
});

// Note: `chatViewModelProvider` itself lives in
// `presentation/viewmodels/chat_viewmodel.dart` (co-located with the
// ChatViewModel class it constructs) and reads the use case providers
// above, plus `voiceServiceProvider`, via `ref.watch`.
