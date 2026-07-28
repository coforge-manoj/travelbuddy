import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ai_travel_assistant/core/errors/failures.dart';
import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/intent.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat.dart';
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

    when(() => historyRepository.clearHistory()).thenAnswer((_) async => const Result.success(null));
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
    );

    // Let the constructor's initial session-start sequence (welcome message
    // + flight-offer search) fully settle before each test's own actions.
    await pumpEventQueue();
  });

  test('a new session starts with a welcome message and flight-offer suggestions', () {
    expect(viewModel.state.messages, hasLength(2));
    expect(viewModel.state.messages.first.text, contains('Hello'));
    expect(viewModel.state.messages.last.type, ChatMessageType.flightOffersCard);
    expect(viewModel.state.messages.last.payload, sampleOffers);
    verify(() => historyRepository.clearHistory()).called(1);
  });

  test('selecting a flight offer books it and renders a confirmation card', () async {
    final booking = Booking(
      pnr: 'TB123456',
      passengerName: 'Joe Traveler',
      flight: Flight(
        flightNumber: 'UA482',
        origin: 'EWR',
        destination: 'ORD',
        status: FlightStatus.scheduled,
        scheduledDeparture: DateTime(2026, 1, 2, 6, 45),
      ),
    );
    when(
      () => flightRepository.bookFlight(
        offerId: any(named: 'offerId'),
        passengerName: any(named: 'passengerName'),
      ),
    ).thenAnswer((_) async => Result.success(booking));

    await viewModel.selectFlightOffer('UA482');
    await pumpEventQueue();

    expect(viewModel.state.messages.last.type, ChatMessageType.bookingConfirmationCard);
    expect(viewModel.state.messages.last.payload, booking);
  });

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
