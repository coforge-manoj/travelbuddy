import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ai_travel_assistant/core/services/local_notification_service.dart';
import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/intent.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/journey/journey_stage.dart';
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
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/services/flight_services.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/booking_session_store.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_viewmodel.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_service.dart';

import '../mocks/mocks.dart';

Future<void> pumpEventQueue() => Future<void>.delayed(Duration.zero);

/// Records every `/chat` post so repair behaviour can be asserted without a
/// tunnel. Overrides [getFlightResponse] only — construction still builds a
/// real [ApiService], which is never called.
class FakeFlightServices extends FlightServices {
  FakeFlightServices() : super(sessionId: 'tb-test');

  final posts = <({String message, bool confirm})>[];
  final responses = <Map<String, dynamic>>[];

  void enqueue(Map<String, dynamic> data) => responses.add(data);

  @override
  Future<dynamic> getFlightResponse(
    String message, {
    bool confirm = false,
  }) async {
    posts.add((message: message, confirm: confirm));
    if (responses.isEmpty) {
      throw StateError('FakeFlightServices has no queued responses');
    }
    return {'data': responses.removeAt(0)};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockChatRepository chatRepository;
  late MockFlightRepository flightRepository;
  late MockSeatRepository seatRepository;
  late MockBaggageRepository baggageRepository;
  late MockAirportRepository airportRepository;
  late MockAgentRepository agentRepository;
  late MockChatHistoryRepository historyRepository;
  late FakeFlightServices flightService;
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

  setUp(() async {
    chatRepository = MockChatRepository();
    flightRepository = MockFlightRepository();
    seatRepository = MockSeatRepository();
    baggageRepository = MockBaggageRepository();
    airportRepository = MockAirportRepository();
    agentRepository = MockAgentRepository();
    historyRepository = MockChatHistoryRepository();
    flightService = FakeFlightServices();

    when(() => historyRepository.clearHistory())
        .thenAnswer((_) async => const Result.success(null));
    when(() => historyRepository.saveMessage(any()))
        .thenAnswer((_) async => const Result.success(null));
    when(
      () => flightRepository.searchFlights(
        origin: any(named: 'origin'),
        destination: any(named: 'destination'),
      ),
    ).thenAnswer(
      (_) async => Result.success([
        FlightOffer(
          id: 'AA50',
          airline: 'American',
          flightNumber: 'AA50',
          origin: 'DFW',
          destination: 'LHR',
          departureTime: DateTime(2027, 6, 10, 18, 0),
          arrivalTime: DateTime(2027, 6, 11, 8, 0),
          price: 900,
        ),
      ]),
    );

    when(() => chatRepository.classifyIntent(any())).thenAnswer(
      (invocation) async {
        final utterance = invocation.positionalArguments.first as String;
        return Result.success(
          IntentResult(
            type: IntentType.searchFlights,
            confidence: 0.95,
            originalMessage: utterance,
            qnPromt: utterance,
          ),
        );
      },
    );

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
      flightService: flightService,
    );

    await pumpEventQueue();
  });

  test('a collecting search parks the stage for the next message', () async {
    flightService.enqueue({
      'reply': 'I need an origin, a destination and a date.',
      'tool': 'search_flights',
      'cards': <Object>[],
      'needsConfirmation': false,
      'suggestions': ['Book the recommended one'],
    });

    await viewModel.sendMessage('search for flight to london');
    await pumpEventQueue();

    expect(flightService.posts, hasLength(1));
    expect(viewModel.state.awaitingDetailsFor, same(JourneyStage.search));
    expect(viewModel.state.awaitingSearchDetails, isTrue);
    // Stock suggestions are suppressed on collecting turns.
    expect(viewModel.state.suggestions, isEmpty);
  });

  test('a non-mutating misfire posts exactly twice then renders', () async {
    flightService
      ..enqueue({
        'reply': 'Nothing to list yet.',
        'tool': 'list_extras',
        'cards': <Object>[],
        'needsConfirmation': false,
      })
      ..enqueue({
        'reply': 'Here are the extras.',
        'tool': 'list_extras',
        'cards': [
          {
            'type': 'extras_list',
            'extras': [
              {'name': 'Extra legroom', 'price': 45},
            ],
          },
        ],
        'needsConfirmation': false,
        'suggestions': <String>[],
      });

    await viewModel.sendMessage('what extras can I add');
    await pumpEventQueue();

    expect(flightService.posts, hasLength(2));
    expect(flightService.posts[0].message, 'what extras can I add');
    expect(flightService.posts[1].message, JourneyStage.listExtras.repairMessage);
    expect(viewModel.state.awaitingDetailsFor, isNull);
    expect(
      viewModel.state.messages.any((m) => m.text == 'Here are the extras.'),
      isTrue,
    );
  });

  test('a mutating misfire posts exactly once and offers a chip', () async {
    flightService.enqueue({
      'reply': 'Left it as it was.',
      'tool': 'cancel_booking',
      'cards': <Object>[],
      'needsConfirmation': false,
    });

    await viewModel.sendMessage('cancel my booking');
    await pumpEventQueue();

    expect(flightService.posts, hasLength(1));
    expect(flightService.posts.single.message, 'cancel my booking');
    expect(
      viewModel.state.suggestions,
      contains(JourneyStage.cancelBooking.correctiveChip),
    );
    expect(viewModel.state.awaitingSearchDetails, isFalse);
  });

  test('confirm-flag misfire repairs once with the alternate affirmation',
      () async {
    // First turn: cancel preview asking for approval.
    flightService.enqueue({
      'reply': "That's RLTYVL. Cancel it?",
      'tool': 'cancel_booking',
      'cards': <Object>[],
      'needsConfirmation': true,
    });
    await viewModel.sendMessage('cancel my booking');
    await pumpEventQueue();
    expect(viewModel.state.needsConfirmation, isTrue);

    // Confirm returns the documented no-op, then the alternate affirmation.
    flightService
      ..enqueue({
        'reply': 'Left it as it was.',
        'tool': 'cancel_booking',
        'cards': <Object>[],
        'needsConfirmation': false,
      })
      ..enqueue({
        'reply': 'Cancelled.',
        'tool': 'cancel_booking',
        'cards': [
          {
            'type': 'cancellation',
            'pnr': 'RLTYVL',
            'status': 'cancelled',
          },
        ],
        'needsConfirmation': false,
      });

    await viewModel.confirmPendingAction();
    await pumpEventQueue();

    // Original confirm post + one repair. Never a third.
    expect(flightService.posts, hasLength(3));
    expect(flightService.posts[1].message, 'yes');
    expect(flightService.posts[1].confirm, isTrue);
    expect(
      flightService.posts[2].message,
      JourneyStage.cancelBooking.repairMessage,
    );
    expect(flightService.posts[2].confirm, isTrue);
  });

  test('network errors hide the raw exception and offer a retry chip',
      () async {
    // No queued response → FakeFlightServices throws.
    await viewModel.sendMessage('flights from DFW to LHR');
    await pumpEventQueue();

    expect(
      viewModel.state.messages.last.text,
      'Sorry, I could not reach the flight assistant.',
    );
    expect(viewModel.state.messages.last.text.contains('StateError'), isFalse);
    expect(viewModel.state.suggestions, ['flights from DFW to LHR']);
  });
}
