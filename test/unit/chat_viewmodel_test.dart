import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ai_travel_assistant/core/errors/failures.dart';
import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking_summary.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/intent.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/spoken_draft.dart';
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
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/booking_session_store.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_state.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_viewmodel.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/audio_cue_player.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/talk_back_preference_store.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_action_resolver.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_narrator.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_service.dart';

import '../mocks/mocks.dart';

// Note on voice: the narrator, cue player, and preference store are all
// faked below so these tests observe what *would* be spoken and played
// without needing platform channels. A real `VoiceService()` is still passed
// in — every call into it is guarded, so the MissingPluginException it throws
// under `flutter_test` is swallowed exactly as a real TTS-engine failure
// would be in production.

/// Records the utterances handed to the narrator instead of speaking them.
///
/// Card summaries arrive as [SpokenDraft]s whose final wording is the phrasing
/// layer's business (and is covered by its own tests); what matters here is
/// which facts the view model chose to narrate, so drafts are recorded as
/// their deterministic fallback text.
class _RecordingNarrator extends VoiceNarrator {
  _RecordingNarrator(VoiceService voiceService) : super(voiceService: voiceService);

  final List<String> utterances = [];
  final List<SpokenDraft> drafts = [];
  int stopAllCount = 0;

  @override
  void enqueue(String utterance) => utterances.add(utterance);

  @override
  void enqueueDraft(SpokenDraft draft) {
    drafts.add(draft);
    utterances.add(draft.fallbackText);
  }

  @override
  Future<void> stopAll() async => stopAllCount++;
}

class _RecordingCuePlayer extends AudioCuePlayer {
  final List<AudioCue> played = [];

  @override
  Future<void> play(AudioCue cue) async => played.add(cue);

  @override
  Future<void> playAndAwait(AudioCue cue, {Duration? timeout}) async =>
      played.add(cue);

  @override
  Future<void> tapFeedback() async {}
}

class _FakeTalkBackStore implements TalkBackPreferenceStore {
  _FakeTalkBackStore([this.stored]);

  bool? stored;
  final List<bool> writes = [];

  @override
  Future<bool?> read() async => stored;

  @override
  Future<void> write(bool enabled) async {
    stored = enabled;
    writes.add(enabled);
  }
}

/// Lets tests drive STT results and session-end without platform channels.
class _ControllableVoiceService extends VoiceService {
  void Function(String transcript, bool isFinal)? _onResult;
  void Function()? _onListeningEnded;
  int stopListeningCount = 0;
  bool startSucceeds = true;
  Duration? lastListenFor;
  Duration? lastPauseFor;

  @override
  Future<bool> startListening({
    required void Function(String transcript, bool isFinal) onResult,
    void Function()? onListeningEnded,
    String? localeId,
    Duration listenFor = const Duration(seconds: 15),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    if (!startSucceeds) return false;
    _onResult = onResult;
    _onListeningEnded = onListeningEnded;
    lastListenFor = listenFor;
    lastPauseFor = pauseFor;
    return true;
  }

  @override
  Future<void> stopListening() async {
    stopListeningCount++;
  }

  void emitResult(String transcript, {bool isFinal = true}) {
    _onResult?.call(transcript, isFinal);
  }

  void emitListeningEnded() {
    _onListeningEnded?.call();
  }
}

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
  late _RecordingNarrator narrator;
  late _RecordingCuePlayer cues;
  late _FakeTalkBackStore talkBack;
  late BookingSessionStore bookingStore;
  late ChatViewModel viewModel;

  /// Seat, baggage, status, and airport requests all resolve against the
  /// passenger's active booking; without one the view model offers to book a
  /// flight instead. Tests that exercise those paths seed this first.
  Booking demoBooking() => Booking(
        pnr: 'ABC123',
        passengerName: 'Joe Traveler',
        flight: Flight(
          flightNumber: 'FZ123',
          origin: 'EWR',
          destination: 'ORD',
          status: FlightStatus.scheduled,
          scheduledDeparture: DateTime(2026, 1, 2, 6, 45),
        ),
      );

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
    FlightOffer(
      id: 'DL2071',
      airline: 'Delta Air Lines',
      flightNumber: 'DL2071',
      origin: 'EWR',
      destination: 'ORD',
      departureTime: DateTime(2026, 1, 2, 12, 30),
      arrivalTime: DateTime(2026, 1, 2, 15, 40),
      price: 176,
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

    narrator = _RecordingNarrator(VoiceService());
    cues = _RecordingCuePlayer();
    talkBack = _FakeTalkBackStore();
    bookingStore = BookingSessionStore();

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
      voiceNarrator: narrator,
      audioCuePlayer: cues,
      bookingSessionStore: bookingStore,
      talkBackPreferenceStore: talkBack,
    );

    // Let the constructor's initial session-start sequence (welcome message
    // + flight-offer search) fully settle before each test's own actions.
    await pumpEventQueue();
  });

  test('a new session starts with just a welcome message', () {
    expect(viewModel.state.messages, hasLength(1));
    expect(viewModel.state.messages.single.text, contains('Hello'));
    verify(() => historyRepository.clearHistory()).called(1);
  });

  test('selecting a flight offer books it and starts the guided seat/baggage flow', () async {
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
    const seatMap = SeatMap(flightNumber: 'UA482', rows: 1, seats: []);
    when(() => seatRepository.getSeatMap(any()))
        .thenAnswer((_) async => const Result.success(seatMap));

    await viewModel.selectFlightOffer('UA482');
    await pumpEventQueue();

    expect(viewModel.state.messages.last.type, ChatMessageType.seatMapCard);
    expect(viewModel.state.messages.last.payload, seatMap);
    expect(viewModel.state.pendingBooking, booking);
  });

  test(
    'the guided flow ends with a complete itinerary card including terminal info',
    () async {
      final flight = Flight(
        flightNumber: 'UA482',
        origin: 'EWR',
        destination: 'ORD',
        status: FlightStatus.scheduled,
        scheduledDeparture: DateTime(2026, 1, 2, 6, 45),
        gate: 'B12',
        terminal: '2',
        checkInCounter: '14-18',
        boardingTime: DateTime(2026, 1, 2, 6, 5),
      );
      final booking = Booking(pnr: 'TB123456', passengerName: 'Joe Traveler', flight: flight);
      when(
        () => flightRepository.bookFlight(
          offerId: any(named: 'offerId'),
          passengerName: any(named: 'passengerName'),
        ),
      ).thenAnswer((_) async => Result.success(booking));
      const seatMap = SeatMap(
        flightNumber: 'UA482',
        rows: 1,
        seats: [
          Seat(
            seatNumber: '14A',
            row: 14,
            column: 'A',
            type: SeatType.window,
            availability: SeatAvailability.available,
            priceDelta: 15,
          ),
        ],
      );
      when(() => seatRepository.getSeatMap(any()))
          .thenAnswer((_) async => const Result.success(seatMap));
      const seat = Seat(
        seatNumber: '14A',
        row: 14,
        column: 'A',
        type: SeatType.window,
        availability: SeatAvailability.selected,
        priceDelta: 15,
      );
      when(
        () => seatRepository.changeSeat(
          pnr: any(named: 'pnr'),
          flightNumber: any(named: 'flightNumber'),
          seatNumber: any(named: 'seatNumber'),
        ),
      ).thenAnswer((_) async => const Result.success(seat));
      const options = [BaggageOption(id: 'bag_10kg', extraWeightKg: 10, price: 45)];
      when(() => baggageRepository.getBaggageOptions(any()))
          .thenAnswer((_) async => const Result.success(options));
      const purchase = BaggagePurchase(
        id: 'purchase_1',
        option: BaggageOption(id: 'bag_10kg', extraWeightKg: 10, price: 45),
        status: BaggagePurchaseStatus.success,
        confirmationCode: 'BG12345',
      );
      when(
        () => baggageRepository.purchaseBaggage(
          pnr: any(named: 'pnr'),
          optionId: any(named: 'optionId'),
        ),
      ).thenAnswer((_) async => const Result.success(purchase));

      await viewModel.selectFlightOffer('UA482');
      await pumpEventQueue();
      expect(viewModel.state.messages.last.type, ChatMessageType.seatMapCard);

      await viewModel.confirmSeatChange('14A');
      await pumpEventQueue();
      expect(viewModel.state.messages.last.type, ChatMessageType.baggageOptionsCard);
      expect(viewModel.state.pendingSeatNumber, '14A');

      await viewModel.confirmBaggagePurchase('bag_10kg');
      await pumpEventQueue();
      expect(viewModel.state.messages.last.type, ChatMessageType.baggageSuccessCard);
      expect(viewModel.state.pendingBaggagePurchases, [purchase]);

      await viewModel.finishBooking();
      await pumpEventQueue();

      final finalMessage = viewModel.state.messages.last;
      expect(finalMessage.type, ChatMessageType.bookingConfirmationCard);
      final summary = finalMessage.payload! as BookingSummary;
      expect(summary.booking, booking);
      expect(summary.seatNumber, '14A');
      expect(summary.extraBaggageKg, 10);
      expect(summary.booking.flight.terminal, '2');
      expect(summary.booking.flight.gate, 'B12');
      expect(viewModel.state.pendingBooking, isNull);
    },
  );

  test('seat-selection intent renders a seat map card', () async {
    bookingStore.confirmedBooking = demoBooking();
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
    bookingStore.confirmedBooking = demoBooking();
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

  group('narration', () {
    Future<void> showOffers() async {
      when(() => chatRepository.classifyIntent(any())).thenAnswer(
        (_) async =>
            const Result.success(IntentResult(type: IntentType.bookFlight, confidence: 0.95)),
      );
      await viewModel.sendMessage('I want to book a flight');
      await pumpEventQueue();
    }

    test('a rich card is spoken as a summary rather than its on-screen caption', () async {
      await showOffers();

      expect(viewModel.state.messages.last.type, ChatMessageType.flightOffersCard);
      expect(
        narrator.utterances.last,
        'I found 2 flights from Newark to Chicago. The cheapest is Delta Air Lines at '
        '176 dollars, departing 12 30 in the afternoon. '
        "You're welcome to name an airline, or ask for the cheapest one.",
      );
      // The card's own caption is never what gets spoken.
      expect(narrator.utterances, isNot(contains(viewModel.state.messages.last.text)));
    });

    test('the flight recap before a card is not spoken, to avoid saying the flight twice',
        () async {
      const seatMap = SeatMap(
        flightNumber: 'UA482',
        rows: 1,
        seats: [
          Seat(
            seatNumber: '14A',
            row: 14,
            column: 'A',
            type: SeatType.window,
            availability: SeatAvailability.available,
          ),
        ],
      );
      when(() => seatRepository.getSeatMap(any()))
          .thenAnswer((_) async => const Result.success(seatMap));
      when(
        () => flightRepository.bookFlight(
          offerId: any(named: 'offerId'),
          passengerName: any(named: 'passengerName'),
        ),
      ).thenAnswer(
        (_) async => Result.success(
          Booking(
            pnr: 'TB123456',
            passengerName: 'Joe Traveler',
            flight: Flight(
              flightNumber: 'UA482',
              origin: 'EWR',
              destination: 'ORD',
              status: FlightStatus.scheduled,
              scheduledDeparture: DateTime(2026, 1, 2, 6, 45),
            ),
          ),
        ),
      );

      // Establish a booking so the seat-selection intent has a flight to recap.
      await viewModel.selectFlightOffer('UA482');
      await pumpEventQueue();
      narrator.utterances.clear();

      when(() => chatRepository.classifyIntent(any())).thenAnswer(
        (_) async =>
            const Result.success(IntentResult(type: IntentType.seatSelection, confidence: 0.95)),
      );
      await viewModel.sendMessage('I want a window seat');
      await pumpEventQueue();

      expect(narrator.utterances.any((line) => line.contains('PNR')), isFalse);
      expect(narrator.utterances.last, contains("I've put the seat map on your screen"));
    });

    test('an error is spoken, cued, and persisted like any other message', () async {
      bookingStore.confirmedBooking = demoBooking();
      when(() => chatRepository.classifyIntent(any())).thenAnswer(
        (_) async =>
            const Result.success(IntentResult(type: IntentType.flightStatus, confidence: 0.9)),
      );
      when(() => flightRepository.getFlightStatus(any()))
          .thenAnswer((_) async => const Result.failure(NetworkFailure()));

      await viewModel.sendMessage('Is my flight delayed?');
      await pumpEventQueue();

      final error = viewModel.state.messages.last;
      expect(error.type, ChatMessageType.error);
      expect(narrator.utterances.last, error.text);
      expect(cues.played, contains(AudioCue.error));
      verify(() => historyRepository.saveMessage(error)).called(1);
    });

    test('turning talk back off silences the narrator and remembers the choice', () async {
      await showOffers();
      final spokenBefore = narrator.utterances.length;

      await viewModel.toggleVoiceOutput();
      await pumpEventQueue();

      expect(viewModel.state.isVoiceOutputEnabled, isFalse);
      expect(narrator.stopAllCount, greaterThan(0));
      expect(talkBack.writes, [false]);

      await viewModel.sendMessage('and another thing');
      await pumpEventQueue();

      expect(narrator.utterances, hasLength(spokenBefore), reason: 'nothing more should be queued');
    });

    test('a stored talk-back preference is restored on a new session', () async {
      final store = _FakeTalkBackStore(false);
      final restored = ChatViewModel(
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
        voiceNarrator: _RecordingNarrator(VoiceService()),
        audioCuePlayer: _RecordingCuePlayer(),
        bookingSessionStore: BookingSessionStore(),
        talkBackPreferenceStore: store,
      );
      await pumpEventQueue();

      expect(restored.state.isVoiceOutputEnabled, isFalse);
      restored.dispose();
    });
  });

  group('spoken confirmation gate', () {
    setUp(() async {
      when(() => chatRepository.classifyIntent(any())).thenAnswer(
        (_) async =>
            const Result.success(IntentResult(type: IntentType.bookFlight, confidence: 0.95)),
      );
      when(
        () => flightRepository.bookFlight(
          offerId: any(named: 'offerId'),
          passengerName: any(named: 'passengerName'),
        ),
      ).thenAnswer(
        (_) async => Result.success(
          Booking(
            pnr: 'TB123456',
            passengerName: 'Joe Traveler',
            flight: Flight(
              flightNumber: 'DL2071',
              origin: 'EWR',
              destination: 'ORD',
              status: FlightStatus.scheduled,
              scheduledDeparture: DateTime(2026, 1, 2, 12, 30),
            ),
          ),
        ),
      );
      when(() => seatRepository.getSeatMap(any())).thenAnswer(
        (_) async => const Result.success(SeatMap(flightNumber: 'DL2071', rows: 1, seats: [])),
      );

      await viewModel.sendMessage('I want to book a flight');
      await pumpEventQueue();
    });

    test('saying "book the cheapest" reads the price back instead of booking', () async {
      await viewModel.handleVoiceTranscript('book the cheapest one');
      await pumpEventQueue();

      verifyNever(
        () => flightRepository.bookFlight(
          offerId: any(named: 'offerId'),
          passengerName: any(named: 'passengerName'),
        ),
      );

      final readBack = viewModel.state.messages.last;
      expect(readBack.text, contains('176 dollars'));
      expect(readBack.text, contains('Would you like me to book it for you?'));
      expect(viewModel.state.pendingConfirmation, isA<SelectOfferAction>());
    });

    test('a following "yes" is what actually books it', () async {
      await viewModel.handleVoiceTranscript('book the cheapest one');
      await pumpEventQueue();
      await viewModel.handleVoiceTranscript('yes');
      await pumpEventQueue();

      verify(() => flightRepository.bookFlight(offerId: 'DL2071', passengerName: any(named: 'passengerName')))
          .called(1);
      expect(viewModel.state.pendingConfirmation, isNull);
    });

    test('saying "no" cancels and charges nothing', () async {
      await viewModel.handleVoiceTranscript('book the cheapest one');
      await pumpEventQueue();
      await viewModel.handleVoiceTranscript('no');
      await pumpEventQueue();

      verifyNever(
        () => flightRepository.bookFlight(
          offerId: any(named: 'offerId'),
          passengerName: any(named: 'passengerName'),
        ),
      );
      expect(viewModel.state.messages.last.text, contains('cancelled'));
      expect(viewModel.state.pendingConfirmation, isNull);
    });

    test('a read-back expires, so a much later "yes" cannot trigger the purchase', () async {
      await viewModel.handleVoiceTranscript('book the cheapest one');
      await pumpEventQueue();

      final state = viewModel.state;
      expect(state.confirmationValidAt(DateTime.now()), isNotNull);
      expect(
        state.confirmationValidAt(
          state.pendingConfirmationExpiresAt!.add(const Duration(seconds: 1)),
        ),
        isNull,
        reason: 'a stale yes must not resolve to a booking',
      );
    });

    test('tapping still books in one step, with no spoken confirmation', () async {
      await viewModel.selectFlightOffer('DL2071');
      await pumpEventQueue();

      verify(
        () => flightRepository.bookFlight(offerId: 'DL2071', passengerName: any(named: 'passengerName')),
      ).called(1);
    });
  });

  group('flight-offer silence ladder', () {
    setUp(() async {
      when(() => chatRepository.classifyIntent(any())).thenAnswer(
        (_) async =>
            const Result.success(IntentResult(type: IntentType.bookFlight, confidence: 0.95)),
      );
      await viewModel.sendMessage('I want to book a flight');
      await pumpEventQueue();
    });

    test('silence first offers the cheapest option for confirmation', () async {
      viewModel.debugFireProactivePrompt();
      await pumpEventQueue();

      final nudge = viewModel.state.messages.last;
      expect(nudge.text, contains('cheapest option is Delta Air Lines'));
      expect(nudge.text, contains('Would you like me to book that for you?'));
      expect(viewModel.state.pendingConfirmation, isA<SelectOfferAction>());
      expect(viewModel.state.proactivePromptStep, 1);
      expect(cues.played, contains(AudioCue.prompt));
    });

    test('continued silence asks about another date and clears the booking confirmation',
        () async {
      viewModel.debugFireProactivePrompt();
      await pumpEventQueue();
      expect(viewModel.state.pendingConfirmation, isNotNull);

      viewModel.debugFireProactivePrompt();
      await pumpEventQueue();

      expect(
        viewModel.state.messages.last.text,
        'If you want, I can look for flight availability on other days.',
      );
      expect(viewModel.state.pendingConfirmation, isNull);
      expect(viewModel.state.proactivePromptStep, 2);
    });

    test('a third silence politely offers any other help, then stops', () async {
      viewModel.debugFireProactivePrompt();
      await pumpEventQueue();
      viewModel.debugFireProactivePrompt();
      await pumpEventQueue();
      viewModel.debugFireProactivePrompt();
      await pumpEventQueue();

      expect(
        viewModel.state.messages.last.text,
        'Is there anything else I can help you with today?',
      );
      expect(viewModel.state.proactivePromptStep, 3);

      final messageCount = viewModel.state.messages.length;
      viewModel.debugFireProactivePrompt();
      await pumpEventQueue();
      expect(viewModel.state.messages, hasLength(messageCount));
    });
  });

  group('voice input session end', () {
    late _ControllableVoiceService voice;

    ChatViewModel buildViewModel() {
      voice = _ControllableVoiceService();
      narrator = _RecordingNarrator(voice);
      cues = _RecordingCuePlayer();
      talkBack = _FakeTalkBackStore();
      bookingStore = BookingSessionStore();

      return ChatViewModel(
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
        voiceService: voice,
        voiceNarrator: narrator,
        audioCuePlayer: cues,
        bookingSessionStore: bookingStore,
        talkBackPreferenceStore: talkBack,
      );
    }

    test('silence that ends the STT session clears listening UI', () async {
      final vm = buildViewModel();
      await pumpEventQueue();

      await vm.startVoiceInput();
      await pumpEventQueue();
      expect(vm.state.status, ChatStatus.listening);

      voice.emitListeningEnded();
      await pumpEventQueue();

      expect(vm.state.status, isNot(ChatStatus.listening));
      expect(vm.state.messages.last.text, "Sorry, I didn't catch that.");
      vm.dispose();
    });

    test('talkback uses a longer silence window before ending listen', () async {
      final vm = buildViewModel();
      await pumpEventQueue();
      expect(vm.state.isVoiceOutputEnabled, isTrue);

      await vm.startVoiceInput();
      await pumpEventQueue();

      expect(voice.lastPauseFor, const Duration(seconds: 5));
      expect(voice.lastListenFor, const Duration(seconds: 30));
      vm.dispose();
    });

    test('a final transcript arriving after session end is still handled', () async {
      when(() => chatRepository.classifyIntent(any())).thenAnswer(
        (_) async => const Result.success(
          IntentResult(type: IntentType.faq, confidence: 0.9),
        ),
      );
      when(
        () => chatRepository.generateReply(
          userUtterance: any(named: 'userUtterance'),
          history: any(named: 'history'),
        ),
      ).thenAnswer(
        (_) async => Result.success(
          ChatMessage(
            id: 'reply',
            role: ChatRole.assistant,
            type: ChatMessageType.text,
            timestamp: DateTime.now(),
            text: 'Sure, let me help with that.',
          ),
        ),
      );

      final vm = buildViewModel();
      await pumpEventQueue();

      await vm.startVoiceInput();
      await pumpEventQueue();

      // What the recognizer actually does on Android: stream partials, report
      // the session finished when the mic closes, then deliver the final a
      // couple of seconds later (speech_to_text's own finalTimeout).
      voice.emitResult('help me with booking a flight', isFinal: false);
      await pumpEventQueue();
      voice.emitListeningEnded();
      await pumpEventQueue();
      voice.emitResult('help me with booking a flight');
      await pumpEventQueue();

      expect(
        vm.state.messages.where((m) => m.role == ChatRole.user).map((m) => m.text),
        contains('help me with booking a flight'),
        reason: 'the late final must not be discarded as a stale callback',
      );
      expect(
        vm.state.messages.where((m) => m.text == "Sorry, I didn't catch that."),
        isEmpty,
      );
      vm.dispose();
    });

    test('manual stop leaves listening without the missed-speech apology', () async {
      final vm = buildViewModel();
      await pumpEventQueue();

      await vm.startVoiceInput();
      await pumpEventQueue();
      expect(vm.state.status, ChatStatus.listening);

      await vm.stopVoiceInput();
      await pumpEventQueue();
      // Late platform "done" after a manual stop must not resurrect listening
      // or append a duplicate apology.
      final count = vm.state.messages.length;
      voice.emitListeningEnded();
      await pumpEventQueue();

      expect(vm.state.status, ChatStatus.idle);
      expect(vm.state.messages, hasLength(count));
      expect(
        vm.state.messages.where((m) => m.text == "Sorry, I didn't catch that."),
        isEmpty,
      );
      vm.dispose();
    });

    test('a final transcript clears listening without waiting for session end', () async {
      when(() => chatRepository.classifyIntent(any())).thenAnswer(
        (_) async =>
            const Result.success(IntentResult(type: IntentType.seatSelection, confidence: 0.1)),
      );

      final vm = buildViewModel();
      await pumpEventQueue();

      await vm.startVoiceInput();
      await pumpEventQueue();
      expect(vm.state.status, ChatStatus.listening);

      voice.emitResult('hello there');
      await pumpEventQueue();

      expect(vm.state.status, isNot(ChatStatus.listening));
      expect(
        vm.state.messages.any((m) => m.role == ChatRole.user && m.text == 'hello there'),
        isTrue,
      );

      // Late session-end must not re-open listening or apologize.
      voice.emitListeningEnded();
      await pumpEventQueue();
      expect(vm.state.status, isNot(ChatStatus.listening));
      expect(
        vm.state.messages.where((m) => m.text == "Sorry, I didn't catch that."),
        isEmpty,
      );
      vm.dispose();
    });

    test('composer dictate fills the draft instead of sending', () async {
      final vm = buildViewModel();
      await pumpEventQueue();
      final messageCount = vm.state.messages.length;

      await vm.startVoiceInput(mode: VoiceInputMode.dictate);
      await pumpEventQueue();
      expect(vm.state.status, ChatStatus.listening);

      voice.emitResult('book a flight to chicago', isFinal: false);
      await pumpEventQueue();
      expect(vm.state.dictationDraft, 'book a flight to chicago');
      expect(vm.state.messages, hasLength(messageCount));

      voice.emitResult('book a flight to chicago', isFinal: true);
      await pumpEventQueue();

      expect(vm.state.status, isNot(ChatStatus.listening));
      expect(vm.state.dictationDraft, 'book a flight to chicago');
      expect(vm.state.messages, hasLength(messageCount), reason: 'must not auto-send');
      expect(
        vm.state.messages.where((m) => m.text == "Sorry, I didn't catch that."),
        isEmpty,
      );
      vm.dispose();
    });

    test('composer dictate silence ends quietly without an apology', () async {
      final vm = buildViewModel();
      await pumpEventQueue();
      final messageCount = vm.state.messages.length;

      await vm.startVoiceInput(mode: VoiceInputMode.dictate);
      await pumpEventQueue();

      voice.emitListeningEnded();
      await pumpEventQueue();

      expect(vm.state.status, isNot(ChatStatus.listening));
      expect(vm.state.messages, hasLength(messageCount));
      vm.dispose();
    });
  });
}
