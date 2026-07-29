import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:ai_travel_assistant/core/di/providers.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/agent_escalation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking_summary.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
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
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_state.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_service.dart';

const _uuid = Uuid();

/// Hard-codes the active booking context for this module's standalone demo.
/// In a real host app this comes from the passenger's active
/// booking/session — swap these for a real `currentBookingProvider` at
/// integration time.
const _demoFlightNumber = 'FZ123';
const _demoPnr = 'ABC123';
const _demoAirportCode = 'DXB';
const _demoTravelerFirstName = 'Joe';
const _demoTravelerFullName = 'Joe Traveler';
const _demoSearchOrigin = 'EWR';
const _demoSearchDestination = 'ORD';

/// The single orchestrator behind the chat screen: sends user text through
/// intent classification, then routes to the right use case (flight status,
/// seat map, baggage options, airport info, or human escalation) and turns
/// the result into a rich [ChatMessage] the UI can render. Falls back to a
/// free-form AI reply for FAQ/unknown intents.
class ChatViewModel extends StateNotifier<ChatState> {
  ChatViewModel({
    required SendMessageUseCase sendMessageUseCase,
    required ClassifyIntentUseCase classifyIntentUseCase,
    required GetFlightStatusUseCase getFlightStatusUseCase,
    required GetSeatMapUseCase getSeatMapUseCase,
    required ChangeSeatUseCase changeSeatUseCase,
    required GetBaggageOptionsUseCase getBaggageOptionsUseCase,
    required PurchaseBaggageUseCase purchaseBaggageUseCase,
    required GetAirportDetailsUseCase getAirportDetailsUseCase,
    required EscalateToAgentUseCase escalateToAgentUseCase,
    required SearchFlightsUseCase searchFlightsUseCase,
    required BookFlightUseCase bookFlightUseCase,
    required ClearChatHistoryUseCase clearChatHistoryUseCase,
    required SaveChatMessageUseCase saveChatMessageUseCase,
    required VoiceService voiceService,
  })  : _sendMessageUseCase = sendMessageUseCase,
        _classifyIntentUseCase = classifyIntentUseCase,
        _getFlightStatusUseCase = getFlightStatusUseCase,
        _getSeatMapUseCase = getSeatMapUseCase,
        _changeSeatUseCase = changeSeatUseCase,
        _getBaggageOptionsUseCase = getBaggageOptionsUseCase,
        _purchaseBaggageUseCase = purchaseBaggageUseCase,
        _getAirportDetailsUseCase = getAirportDetailsUseCase,
        _escalateToAgentUseCase = escalateToAgentUseCase,
        _searchFlightsUseCase = searchFlightsUseCase,
        _bookFlightUseCase = bookFlightUseCase,
        _clearChatHistoryUseCase = clearChatHistoryUseCase,
        _saveChatMessageUseCase = saveChatMessageUseCase,
        _voiceService = voiceService,
        super(const ChatState()) {
    _startNewSession();
  }

  final SendMessageUseCase _sendMessageUseCase;
  final ClassifyIntentUseCase _classifyIntentUseCase;
  final GetFlightStatusUseCase _getFlightStatusUseCase;
  final GetSeatMapUseCase _getSeatMapUseCase;
  final ChangeSeatUseCase _changeSeatUseCase;
  final GetBaggageOptionsUseCase _getBaggageOptionsUseCase;
  final PurchaseBaggageUseCase _purchaseBaggageUseCase;
  final GetAirportDetailsUseCase _getAirportDetailsUseCase;
  final EscalateToAgentUseCase _escalateToAgentUseCase;
  final SearchFlightsUseCase _searchFlightsUseCase;
  final BookFlightUseCase _bookFlightUseCase;
  final ClearChatHistoryUseCase _clearChatHistoryUseCase;
  final SaveChatMessageUseCase _saveChatMessageUseCase;
  final VoiceService _voiceService;

  /// Every fresh entry into the chat screen (including navigating back and
  /// re-opening it — see the `autoDispose` on [chatViewModelProvider], which
  /// tears this view model down when nothing is watching it) starts a clean
  /// session: any previous local history is discarded, and a welcome message
  /// plus a proactive flight-offer suggestion seed the conversation.
  Future<void> _startNewSession() async {
    unawaited(_clearChatHistoryUseCase());

    final welcome = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.assistant,
      type: ChatMessageType.text,
      timestamp: DateTime.now(),
      text: 'Hello $_demoTravelerFirstName! How can I help you today?',
    );
    state = state.copyWith(status: ChatStatus.sendingMessage, messages: [welcome]);
    unawaited(_saveChatMessageUseCase(welcome));

    final offersResult = await _searchFlightsUseCase(
      origin: _demoSearchOrigin,
      destination: _demoSearchDestination,
    );
    offersResult.fold(
      (failure) => _appendError(failure.message),
      (offers) => _appendMessage(
        ChatMessage(
          id: _uuid.v4(),
          role: ChatRole.assistant,
          type: ChatMessageType.flightOffersCard,
          timestamp: DateTime.now(),
          text: 'Here are a few flight options from Newark to Chicago — pick one to get started.',
          payload: offers,
        ),
      ),
    );
    state = state.copyWith(status: ChatStatus.idle);
  }

  /// Called once the passenger taps "Select" on a [FlightOffersCard] entry.
  /// Books the flight, then kicks off the guided seat → baggage flow that
  /// [confirmSeatChange], [confirmBaggagePurchase], [addMoreBaggage], and
  /// [finishBooking] carry forward.
  Future<void> selectFlightOffer(String offerId) async {
    state = state.copyWith(status: ChatStatus.sendingMessage);
    final result = await _bookFlightUseCase(offerId: offerId, passengerName: _demoTravelerFullName);
    await result.fold(
      (failure) async => _appendError(failure.message),
      (booking) async {
        state = state.copyWith(
          pendingBooking: booking,
          clearPendingSeatNumber: true,
          pendingBaggagePurchases: const [],
        );
        _appendMessage(
          ChatMessage(
            id: _uuid.v4(),
            role: ChatRole.assistant,
            type: ChatMessageType.text,
            timestamp: DateTime.now(),
            text: 'Flight ${booking.flight.flightNumber} is reserved — now pick your seat.',
          ),
        );
        final seatMapResult = await _getSeatMapUseCase(booking.flight.flightNumber);
        seatMapResult.fold(
          (failure) => _appendError(failure.message),
          (seatMap) => _appendMessage(
            ChatMessage(
              id: _uuid.v4(),
              role: ChatRole.assistant,
              type: ChatMessageType.seatMapCard,
              timestamp: DateTime.now(),
              text: 'Pick a seat below — window seats are highlighted.',
              payload: seatMap,
            ),
          ),
        );
      },
    );
    state = state.copyWith(status: ChatStatus.idle);
  }

  /// Entry point for the composer and suggested-prompt chips.
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isBusy) return;

    _appendMessage(
      ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.user,
        type: ChatMessageType.text,
        timestamp: DateTime.now(),
        text: trimmed,
      ),
    );
    state = state.copyWith(status: ChatStatus.sendingMessage, clearError: true);

    final intentResult = await _classifyIntentUseCase(trimmed);
    await intentResult.fold(
      (failure) async => _appendError(failure.message),
      (intent) async => _handleIntent(intent, trimmed),
    );

    state = state.copyWith(status: ChatStatus.idle);
  }

  Future<void> _handleIntent(IntentResult intent, String utterance) async {
    if (intent.isLowConfidence && intent.type != IntentType.faq) {
      _appendEscalationOffer();
      return;
    }

    switch (intent.type) {
      case IntentType.flightStatus:
      case IntentType.boardingTime:
        await _handleFlightStatus();
      case IntentType.seatSelection:
        await _handleSeatSelection();
      case IntentType.addBaggage:
      case IntentType.baggageAllowance:
        await _handleBaggage();
      case IntentType.terminalInformation:
      case IntentType.counterInformation:
      case IntentType.airportNavigation:
        await _handleAirportInfo();
      case IntentType.humanAgent:
        await _handleEscalation(utterance);
      case IntentType.faq:
      case IntentType.unknown:
        await _handleGenericReply(utterance);
    }
  }

  Future<void> _handleFlightStatus() async {
    final result = await _getFlightStatusUseCase(_demoFlightNumber);
    result.fold(
      (failure) => _appendError(failure.message),
      (flight) => _appendMessage(
        ChatMessage(
          id: _uuid.v4(),
          role: ChatRole.assistant,
          type: ChatMessageType.flightStatusCard,
          timestamp: DateTime.now(),
          text: 'Here is the latest status for ${flight.flightNumber}.',
          payload: flight,
        ),
      ),
    );
  }

  Future<void> _handleSeatSelection() async {
    final result = await _getSeatMapUseCase(_demoFlightNumber);
    result.fold(
      (failure) => _appendError(failure.message),
      (seatMap) => _appendMessage(
        ChatMessage(
          id: _uuid.v4(),
          role: ChatRole.assistant,
          type: ChatMessageType.seatMapCard,
          timestamp: DateTime.now(),
          text: 'Pick a seat below — window seats are highlighted.',
          payload: seatMap,
        ),
      ),
    );
  }

  /// Called by the seat-selection UI once the passenger taps a seat. Applies
  /// to whichever booking is active: the one just made via
  /// [selectFlightOffer], if the guided flow is in progress, otherwise the
  /// demo passenger's existing reservation.
  Future<void> confirmSeatChange(String seatNumber) async {
    state = state.copyWith(status: ChatStatus.sendingMessage);
    final booking = state.pendingBooking;
    final result = await _changeSeatUseCase(
      pnr: booking?.pnr ?? _demoPnr,
      flightNumber: booking?.flight.flightNumber ?? _demoFlightNumber,
      seatNumber: seatNumber,
    );
    await result.fold(
      (failure) async => _appendError(failure.message),
      (seat) async {
        if (booking != null) {
          state = state.copyWith(pendingSeatNumber: seat.seatNumber);
          _appendMessage(
            ChatMessage(
              id: _uuid.v4(),
              role: ChatRole.assistant,
              type: ChatMessageType.text,
              timestamp: DateTime.now(),
              text: 'Seat ${seat.seatNumber} confirmed. ✅ Want to add any baggage?',
            ),
          );
          await _showBaggageOptions(booking.flight.flightNumber);
        } else {
          _appendMessage(
            ChatMessage(
              id: _uuid.v4(),
              role: ChatRole.assistant,
              type: ChatMessageType.text,
              timestamp: DateTime.now(),
              text: 'You are all set in seat ${seat.seatNumber}. ✅',
            ),
          );
        }
      },
    );
    state = state.copyWith(status: ChatStatus.idle);
  }

  Future<void> _handleBaggage() => _showBaggageOptions(_demoFlightNumber);

  Future<void> _showBaggageOptions(String flightNumber) async {
    final result = await _getBaggageOptionsUseCase(flightNumber);
    result.fold(
      (failure) => _appendError(failure.message),
      (options) => _appendMessage(
        ChatMessage(
          id: _uuid.v4(),
          role: ChatRole.assistant,
          type: ChatMessageType.baggageOptionsCard,
          timestamp: DateTime.now(),
          text: 'Here are your extra baggage options.',
          payload: options,
        ),
      ),
    );
  }

  /// Called by the baggage UI once the passenger picks an option. Applies to
  /// the active booking's PNR the same way [confirmSeatChange] does.
  Future<void> confirmBaggagePurchase(String optionId) async {
    state = state.copyWith(status: ChatStatus.sendingMessage);
    final booking = state.pendingBooking;
    final result = await _purchaseBaggageUseCase(pnr: booking?.pnr ?? _demoPnr, optionId: optionId);
    result.fold(
      (failure) => _appendError(failure.message),
      (purchase) {
        if (booking != null) {
          state = state.copyWith(
            pendingBaggagePurchases: [...state.pendingBaggagePurchases, purchase],
          );
        }
        _appendMessage(
          ChatMessage(
            id: _uuid.v4(),
            role: ChatRole.assistant,
            type: ChatMessageType.baggageSuccessCard,
            timestamp: DateTime.now(),
            text: 'Your extra baggage is confirmed.',
            payload: purchase,
          ),
        );
      },
    );
    state = state.copyWith(status: ChatStatus.idle);
  }

  /// Called from the "Add more baggage" action on [BaggageSuccessCard] while
  /// the guided flow is active — re-shows the baggage options so the
  /// passenger can add another bag.
  Future<void> addMoreBaggage() async {
    final booking = state.pendingBooking;
    if (booking == null) return;
    state = state.copyWith(status: ChatStatus.sendingMessage);
    await _showBaggageOptions(booking.flight.flightNumber);
    state = state.copyWith(status: ChatStatus.idle);
  }

  /// Called from the "Skip"/"Finish" actions on the baggage cards once the
  /// passenger is done adding bags — renders the complete itinerary,
  /// including terminal/gate/boarding info, and closes out the guided flow.
  Future<void> finishBooking() async {
    final booking = state.pendingBooking;
    if (booking == null) return;

    final extraBaggageKg = state.pendingBaggagePurchases
        .fold<num>(0, (sum, purchase) => sum + purchase.option.extraWeightKg);

    _appendMessage(
      ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.assistant,
        type: ChatMessageType.bookingConfirmationCard,
        timestamp: DateTime.now(),
        text: "You're all set! Here's your complete itinerary.",
        payload: BookingSummary(
          booking: booking,
          seatNumber: state.pendingSeatNumber,
          extraBaggageKg: extraBaggageKg,
        ),
      ),
    );
    state = state.copyWith(
      clearPendingBooking: true,
      clearPendingSeatNumber: true,
      pendingBaggagePurchases: const [],
    );
  }

  Future<void> _handleAirportInfo() async {
    final result = await _getAirportDetailsUseCase(
      flightNumber: _demoFlightNumber,
      airportCode: _demoAirportCode,
    );
    result.fold(
      (failure) => _appendError(failure.message),
      (info) => _appendMessage(
        ChatMessage(
          id: _uuid.v4(),
          role: ChatRole.assistant,
          type: ChatMessageType.airportInfoCard,
          timestamp: DateTime.now(),
          text: 'Here is how to get to your gate.',
          payload: info,
        ),
      ),
    );
  }

  void _appendEscalationOffer() {
    _appendMessage(
      ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.assistant,
        type: ChatMessageType.text,
        timestamp: DateTime.now(),
        text: "I'm not fully sure I understood that. Would you like to chat "
            'with a customer support agent instead?',
      ),
    );
  }

  Future<void> _handleEscalation(String utterance) async {
    final result = await _escalateToAgentUseCase(
      EscalationRequest(
        reason: 'Passenger requested a human agent',
        conversationSummary: utterance,
      ),
    );
    result.fold(
      (failure) => _appendError(failure.message),
      (escalation) => _appendMessage(
        ChatMessage(
          id: _uuid.v4(),
          role: ChatRole.assistant,
          type: ChatMessageType.agentEscalationCard,
          timestamp: DateTime.now(),
          text: "You're connected to support.",
          payload: escalation,
        ),
      ),
    );
  }

  Future<void> _handleGenericReply(String utterance) async {
    final result = await _sendMessageUseCase(userUtterance: utterance, history: state.messages);
    result.fold((failure) => _appendError(failure.message), _appendMessage);
  }

  /// Starts voice input. On a final transcript, feeds it straight into
  /// [sendMessage] — the same path suggested prompts and the composer use.
  Future<void> startVoiceInput() async {
    if (state.isBusy || state.status == ChatStatus.listening) return;
    final started = await _voiceService.startListening(
      onResult: (transcript, isFinal) {
        if (isFinal && transcript.trim().isNotEmpty) {
          state = state.copyWith(status: ChatStatus.idle);
          unawaited(sendMessage(transcript));
        }
      },
    );
    state = started
        ? state.copyWith(status: ChatStatus.listening, clearError: true)
        : state.copyWith(
            status: ChatStatus.error,
            errorMessage: "Sorry, I didn't catch that.",
          );
  }

  Future<void> stopVoiceInput() async {
    await _voiceService.stopListening();
    if (state.status == ChatStatus.listening) {
      state = state.copyWith(status: ChatStatus.idle);
    }
  }

  /// Toggles whether assistant text replies are read aloud.
  void toggleVoiceOutput() {
    state = state.copyWith(isVoiceOutputEnabled: !state.isVoiceOutputEnabled);
    if (!state.isVoiceOutputEnabled) {
      unawaited(_voiceService.stopSpeaking());
    }
  }

  @override
  void dispose() {
    _voiceService.dispose();
    super.dispose();
  }

  void _appendMessage(ChatMessage message) {
    state = state.copyWith(messages: [...state.messages, message]);
    unawaited(_saveChatMessageUseCase(message));

    final shouldSpeak = message.role == ChatRole.assistant &&
        message.type == ChatMessageType.text &&
        state.isVoiceOutputEnabled;
    if (shouldSpeak) {
      unawaited(_speakSafely(message.text));
    }
  }

  /// Voice output is a nice-to-have; a plugin/platform failure here (e.g. no
  /// TTS engine installed) should never break the chat flow itself.
  Future<void> _speakSafely(String text) async {
    try {
      await _voiceService.speak(text);
    } catch (_) {
      // Intentionally swallowed — see doc comment above.
    }
  }

  void _appendError(String message) {
    state = state.copyWith(
      status: ChatStatus.error,
      errorMessage: message,
      messages: [
        ...state.messages,
        ChatMessage(
          id: _uuid.v4(),
          role: ChatRole.assistant,
          type: ChatMessageType.error,
          timestamp: DateTime.now(),
          text: message,
        ),
      ],
    );
  }
}

/// `autoDispose` so every fresh push of `ChatPage` (e.g. navigating back to
/// the host app and re-opening the assistant) gets a brand-new
/// [ChatViewModel] — and therefore a reset session — instead of resuming
/// whatever state the previous visit left behind.
final chatViewModelProvider = StateNotifierProvider.autoDispose<ChatViewModel, ChatState>((ref) {
  return ChatViewModel(
    sendMessageUseCase: ref.watch(sendMessageUseCaseProvider),
    classifyIntentUseCase: ref.watch(classifyIntentUseCaseProvider),
    getFlightStatusUseCase: ref.watch(getFlightStatusUseCaseProvider),
    getSeatMapUseCase: ref.watch(getSeatMapUseCaseProvider),
    changeSeatUseCase: ref.watch(changeSeatUseCaseProvider),
    getBaggageOptionsUseCase: ref.watch(getBaggageOptionsUseCaseProvider),
    purchaseBaggageUseCase: ref.watch(purchaseBaggageUseCaseProvider),
    getAirportDetailsUseCase: ref.watch(getAirportDetailsUseCaseProvider),
    escalateToAgentUseCase: ref.watch(escalateToAgentUseCaseProvider),
    searchFlightsUseCase: ref.watch(searchFlightsUseCaseProvider),
    bookFlightUseCase: ref.watch(bookFlightUseCaseProvider),
    clearChatHistoryUseCase: ref.watch(clearChatHistoryUseCaseProvider),
    saveChatMessageUseCase: ref.watch(saveChatMessageUseCaseProvider),
    voiceService: ref.watch(voiceServiceProvider),
  );
});
