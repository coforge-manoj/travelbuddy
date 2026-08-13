import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ai_travel_assistant/core/errors/failures.dart';
import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/intent.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/book_flight_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/change_seat_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/chat_history_usecases.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/classify_intent_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/escalate_to_agent_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/get_airport_details_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/get_baggage_options_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/get_flight_status_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/get_seat_map_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/purchase_baggage_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/search_flights_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/send_message_usecase.dart';
import 'package:ai_travel_assistant/core/services/local_notification_service.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/booking_session_store.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_viewmodel.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_service.dart';

import '../mocks/mocks.dart';

// Note on voice: ChatViewModel wraps every VoiceService call in a try/catch
// (`_speakSafely`) precisely so a real `VoiceService()` — whose
// speech_to_text/flutter_tts plugins have no platform channel in
// `flutter_test` — can be used here without any special faking. A
// MissingPluginException is swallowed the same way a real TTS-engine
// failure would be in production.

Future<void> pumpEventQueue() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockChatRepository chatRepository;
  late MockFlightRepository flightRepository;
  late MockSeatRepository seatRepository;
  late MockBaggageRepository baggageRepository;
  late MockAirportRepository airportRepository;
  late MockAgentRepository agentRepository;
  late MockChatHistoryRepository historyRepository;
  late ChatViewModel viewModel;

  final sampleOffers = [
    FlightOffer(
      id: 'UA482',
      airline: 'United Airlines',
      flightNumber: 'UA482',
      origin: 'EWR',
      destination: 'ORD',
      departureTime: DateTime(2026, 1, 2, 6, 45),
      arrivalTime: DateTime(2026, 1, 2, 8, 58),
      price: 189,
    ),
  ];

  setUpAll(() {
    registerFallbackValue(
      ChatMessage(
        id: 'fallback',
        role: ChatRole.user,
        type: ChatMessageType.text,
        timestamp: DateTime(2026),
      ),
    );
  });

  setUp(() async {
    chatRepository = MockChatRepository();
    flightRepository = MockFlightRepository();
    seatRepository = MockSeatRepository();
    baggageRepository = MockBaggageRepository();
    airportRepository = MockAirportRepository();
    agentRepository = MockAgentRepository();
    historyRepository = MockChatHistoryRepository();

    when(() => historyRepository.clearHistory())
        .thenAnswer((_) async => const Result.success(null));
    when(() => historyRepository.saveMessage(any()))
        .thenAnswer((_) async => const Result.success(null));
    when(
      () => flightRepository.searchFlights(
        origin: any(named: 'origin'),
        destination: any(named: 'destination'),
      ),
    ).thenAnswer((_) async => Result.success(sampleOffers));

    viewModel = ChatViewModel(
      sendMessageUseCase: SendMessageUseCase(chatRepository),
      classifyIntentUseCase: ClassifyIntentUseCase(chatRepository),
      getFlightStatusUseCase: GetFlightStatusUseCase(flightRepository),
      getSeatMapUseCase: GetSeatMapUseCase(seatRepository),
      changeSeatUseCase: ChangeSeatUseCase(seatRepository),
      getBaggageOptionsUseCase: GetBaggageOptionsUseCase(baggageRepository),
      purchaseBaggageUseCase: PurchaseBaggageUseCase(baggageRepository),
      getAirportDetailsUseCase: GetAirportDetailsUseCase(airportRepository),
      escalateToAgentUseCase: EscalateToAgentUseCase(agentRepository),
      searchFlightsUseCase: SearchFlightsUseCase(flightRepository),
      bookFlightUseCase: BookFlightUseCase(flightRepository),
      clearChatHistoryUseCase: ClearChatHistoryUseCase(historyRepository),
      saveChatMessageUseCase: SaveChatMessageUseCase(historyRepository),
      voiceService: VoiceService(),
      bookingSessionStore: BookingSessionStore(),
      notificationService: LocalNotificationService(),
      getReminderDelaySeconds: () => 5,
      getVoiceOutputEnabled: () => false,
      setPendingNextScenarioId: (_) {},
    );

    // Let the constructor's initial session-start sequence settle before each
    // test's own actions.
    await pumpEventQueue();
  });

  test('a new session starts with a welcome message and nothing else', () {
    // Flight options used to be searched and shown proactively here. They are
    // not any more — they only appear once the passenger asks to book — so a
    // fresh session is exactly one bubble.
    expect(viewModel.state.messages, hasLength(1));
    final welcome = viewModel.state.messages.single;
    expect(welcome.role, ChatRole.assistant);
    expect(welcome.type, ChatMessageType.text);
    expect(welcome.text, contains('Elena'));
    expect(viewModel.unspokenOpening, welcome.text);
    verify(() => historyRepository.clearHistory()).called(1);
    verifyNever(
      () => flightRepository.searchFlights(
        origin: any(named: 'origin'),
        destination: any(named: 'destination'),
      ),
    );
  });

  test('low-confidence intent offers human escalation instead of guessing',
      () async {
    when(() => chatRepository.classifyIntent(any())).thenAnswer(
      (_) async => const Result.success(
          IntentResult(type: IntentType.seatSelection, confidence: 0.1)),
    );

    await viewModel.sendMessage('uhh something about my thing');
    await pumpEventQueue();

    expect(
        viewModel.state.messages.last.text, contains('customer support agent'));
    verifyNever(() => seatRepository.getSeatMap(any()));
  });

  test('a repository failure surfaces as an inline error message', () async {
    when(() => chatRepository.classifyIntent(any())).thenAnswer(
      (_) async => const Result.success(
          IntentResult(type: IntentType.flightStatus, confidence: 0.9)),
    );
    when(() => flightRepository.getFlightStatus(any()))
        .thenAnswer((_) async => const Result.failure(NetworkFailure()));

    await viewModel.sendMessage('Is my flight delayed?');
    await pumpEventQueue();

    expect(viewModel.state.messages.last.type, ChatMessageType.error);
  });
}
