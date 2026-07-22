import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ai_travel_assistant/core/errors/failures.dart';
import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/intent.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/change_seat_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/chat_history_usecases.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/classify_intent_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/escalate_to_agent_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/get_airport_details_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/get_baggage_options_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/get_flight_status_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/get_seat_map_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/purchase_baggage_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/send_message_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_viewmodel.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_service.dart';

import '../mocks/mocks.dart';

// Note on voice: ChatViewModel wraps every VoiceService call in a try/catch
// (`_speakSafely`) precisely so a real `VoiceService()` — whose
// speech_to_text/flutter_tts plugins have no platform channel in
// `flutter_test` — can be used here without any special faking. A
// MissingPluginException is swallowed the same way a real TTS-engine
// failure would be in production.

void main() {
  late MockChatRepository chatRepository;
  late MockFlightRepository flightRepository;
  late MockSeatRepository seatRepository;
  late MockBaggageRepository baggageRepository;
  late MockAirportRepository airportRepository;
  late MockAgentRepository agentRepository;
  late MockChatHistoryRepository historyRepository;
  late ChatViewModel viewModel;

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

  setUp(() {
    chatRepository = MockChatRepository();
    flightRepository = MockFlightRepository();
    seatRepository = MockSeatRepository();
    baggageRepository = MockBaggageRepository();
    airportRepository = MockAirportRepository();
    agentRepository = MockAgentRepository();
    historyRepository = MockChatHistoryRepository();

    when(() => historyRepository.loadHistory()).thenAnswer((_) async => const Result.success([]));
    when(() => historyRepository.saveMessage(any()))
        .thenAnswer((_) async => const Result.success(null));

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
      loadChatHistoryUseCase: LoadChatHistoryUseCase(historyRepository),
      saveChatMessageUseCase: SaveChatMessageUseCase(historyRepository),
      voiceService: VoiceService(),
    );
  });

  Future<void> pumpEventQueue() => Future<void>.delayed(Duration.zero);

  test('seat-selection intent renders a seat map card', () async {
    when(() => chatRepository.classifyIntent(any())).thenAnswer(
      (_) async =>
          const Result.success(IntentResult(type: IntentType.seatSelection, confidence: 0.95)),
    );
    const seatMap = SeatMap(flightNumber: 'FZ123', rows: 1, seats: []);
    when(() => seatRepository.getSeatMap(any()))
        .thenAnswer((_) async => const Result.success(seatMap));

    await viewModel.sendMessage('I want a window seat');
    await pumpEventQueue();

    expect(viewModel.state.messages.last.type, ChatMessageType.seatMapCard);
    expect(viewModel.state.messages.last.payload, seatMap);
  });

  test('low-confidence intent offers human escalation instead of guessing', () async {
    when(() => chatRepository.classifyIntent(any())).thenAnswer(
      (_) async =>
          const Result.success(IntentResult(type: IntentType.seatSelection, confidence: 0.1)),
    );

    await viewModel.sendMessage('uhh something about my thing');
    await pumpEventQueue();

    expect(viewModel.state.messages.last.text, contains('customer support agent'));
    verifyNever(() => seatRepository.getSeatMap(any()));
  });

  test('baggage purchase confirmation renders a success card', () async {
    const option = BaggageOption(id: 'bag_10kg', extraWeightKg: 10, price: 45);
    const purchase = BaggagePurchase(
      id: 'purchase_1',
      option: option,
      status: BaggagePurchaseStatus.success,
      confirmationCode: 'BG12345',
    );
    when(
      () => baggageRepository.purchaseBaggage(
        pnr: any(named: 'pnr'),
        optionId: any(named: 'optionId'),
      ),
    ).thenAnswer((_) async => const Result.success(purchase));

    await viewModel.confirmBaggagePurchase('bag_10kg');
    await pumpEventQueue();

    expect(viewModel.state.messages.last.type, ChatMessageType.baggageSuccessCard);
    expect(viewModel.state.messages.last.payload, purchase);
  });

  test('a repository failure surfaces as an inline error message', () async {
    when(() => chatRepository.classifyIntent(any())).thenAnswer(
      (_) async =>
          const Result.success(IntentResult(type: IntentType.flightStatus, confidence: 0.9)),
    );
    when(() => flightRepository.getFlightStatus(any()))
        .thenAnswer((_) async => const Result.failure(NetworkFailure()));

    await viewModel.sendMessage('Is my flight delayed?');
    await pumpEventQueue();

    expect(viewModel.state.messages.last.type, ChatMessageType.error);
  });
}
