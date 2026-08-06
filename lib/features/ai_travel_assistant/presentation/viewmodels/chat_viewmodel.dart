import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:ai_travel_assistant/core/di/providers.dart';
import 'package:ai_travel_assistant/core/services/local_notification_service.dart';
import 'package:ai_travel_assistant/core/services/reminder_delay_store.dart';
import 'package:ai_travel_assistant/core/services/voice_output_setting_store.dart';
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
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/search_flights_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/send_message_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/booking_session_store.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_state.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_service.dart';
import 'package:ai_travel_assistant/features/concierge_demo/data/scenario_catalog.dart';
import 'package:ai_travel_assistant/features/concierge_demo/domain/entities/proactive_scenario.dart';

import '../../../../core/services/ai_services/conversation_route/conversation_route_service.dart';
import '../../../../core/services/ai_services/humanized_response_service/response_humanizer_service.dart';
import '../../../../core/services/ai_services/trip_discovery/trip_discovery_service.dart';
import '../../data/models/conersation_route/trip_discovery_context.dart';
import '../services/flight_services.dart';

const _uuid = Uuid();

/// Hard-codes the active booking context for this module's standalone demo.
/// In a real host app this comes from the passenger's active
/// booking/session — swap these for a real `currentBookingProvider` at
/// integration time.
const _demoFlightNumber = 'FZ123';
const _demoPnr = 'ABC123';
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
    required BookingSessionStore bookingSessionStore,
    required LocalNotificationService notificationService,
    required int Function() getReminderDelaySeconds,
    required bool Function() getVoiceOutputEnabled,
    required void Function(String? scenarioId) setPendingNextScenarioId,
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
        _bookingSessionStore = bookingSessionStore,
        _notificationService = notificationService,
        _getReminderDelaySeconds = getReminderDelaySeconds,
        _getVoiceOutputEnabled = getVoiceOutputEnabled,
        _setPendingNextScenarioId = setPendingNextScenarioId,
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
  final BookingSessionStore _bookingSessionStore;
  final LocalNotificationService _notificationService;
  final int Function() _getReminderDelaySeconds;
  final bool Function() _getVoiceOutputEnabled;
  final void Function(String? scenarioId) _setPendingNextScenarioId;

  FlightServices _flightService = FlightServices();

  /// Every fresh entry into the chat screen (including navigating back and
  /// re-opening it — see the `autoDispose` on [chatViewModelProvider], which
  /// tears this view model down when nothing is watching it) starts a clean
  /// session: any previous local history is discarded and a welcome message
  /// seeds the conversation. Flight options are no longer shown proactively
  /// — they only appear once the passenger asks to book a flight (see
  /// [_handleBookFlight]). If [ChatPage] immediately follows up with
  /// [startScenarioById] — because the passenger opened straight into a use
  /// case rather than plain chat — that call replaces this welcome message
  /// rather than appending after it.
  Future<void> _startNewSession() async {
    unawaited(_clearChatHistoryUseCase());

    final welcome = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.assistant,
      type: ChatMessageType.text,
      timestamp: DateTime.now(),
      text: 'Hello $_demoTravelerFirstName! How can I help you today?',
    );
    state = state.copyWith(
      status: ChatStatus.idle,
      messages: [welcome],
      isVoiceOutputEnabled: _getVoiceOutputEnabled(),
    );
    unawaited(_saveChatMessageUseCase(welcome));
  }

  // /// The booking that seat/baggage/status/airport requests should apply to:
  // /// the one in progress in the guided post-selection flow, if any,
  // /// otherwise the passenger's last confirmed booking from
  // /// [_bookingSessionStore] (which survives across chat sessions).
  // Booking? get _activeBooking =>
  //     state.pendingBooking ?? _bookingSessionStore.confirmedBooking;
  //
  // /// Triggered by the "Book a Flight" quick action or free text like "I want
  // /// to book a flight". Searches (demo route) and shows the flight-offers
  // /// card so the passenger can pick one and enter the guided booking flow.
  // Future<void> _handleBookFlight() async {
  //   final offersResult = await _searchFlightsUseCase(
  //     origin: _demoSearchOrigin,
  //     destination: _demoSearchDestination,
  //   );
  //   offersResult.fold(
  //     (failure) => _appendError(failure.message),
  //     (offers) => _appendMessage(
  //       ChatMessage(
  //         id: _uuid.v4(),
  //         role: ChatRole.assistant,
  //         type: ChatMessageType.flightOffersCard,
  //         timestamp: DateTime.now(),
  //         text:
  //             'Here are a few flight options from Newark to Chicago — pick one to get started.',
  //         payload: offers,
  //       ),
  //     ),
  //   );
  // }

  // /// Called for seat/baggage/status/airport-info requests when there is no
  // /// [_activeBooking] to apply them to — lets the passenger know and offers
  // /// to start a booking instead of guessing at a flight.
  // Future<void> _offerToBookFlight() async {
  //   _appendMessage(
  //     ChatMessage(
  //       id: _uuid.v4(),
  //       role: ChatRole.assistant,
  //       type: ChatMessageType.text,
  //       timestamp: DateTime.now(),
  //       text: "You don't have a flight booked yet. I can help you book one — "
  //           'here are some options:',
  //     ),
  //   );
  //   await _handleBookFlight();
  // }

  /// Called once the passenger taps "Select" on a [FlightOffersCard] entry.
  /// Books the flight, then kicks off the guided seat → baggage flow that
  /// [confirmSeatChange], [confirmBaggagePurchase], [addMoreBaggage], and
  /// [finishBooking] carry forward.
  Future<void> selectFlightOffer(String offerId) async {
    state = state.copyWith(status: ChatStatus.sendingMessage);
    final result = await _bookFlightUseCase(
        offerId: offerId, passengerName: _demoTravelerFullName);
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
            text:
                'Flight ${booking.flight.flightNumber} is reserved — now pick your seat.',
          ),
        );
        final seatMapResult =
            await _getSeatMapUseCase(booking.flight.flightNumber);
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

    // If a conversation is already active, first check whether
// the user is continuing it or switching topics.
    if (state.activeIntent != null) {
      final lastAssistantMessage = state.messages
          .lastWhere(
            (e) => e.role == ChatRole.assistant,
          )
          .text;

      final routerResult = await ConversationRouterService.instance.route(
        activeIntent: state.activeIntent!,
        assistantMessage: lastAssistantMessage,
        userMessage: trimmed,
        context: state.conversationContext.toJson(),
      );

      if (routerResult.continueConversation) {
        state = state.copyWith(
          conversationContext: state.conversationContext.copyWith(
            data: routerResult.updatedContext,
          ),
        );

        await _continueCurrentFlow(
          routerResult.normalizedPrompt,
        );

        state = state.copyWith(
          status: ChatStatus.idle,
        );

        return;
      }

      // User changed topic.
      state = state.copyWith(
        clearActiveIntent: true,
      );
    }

// Normal intent classification
    final intentResult = await _classifyIntentUseCase(trimmed);

    await intentResult.fold(
      (failure) async => _appendError(failure.message),
      (intent) async => _handleIntent(intent, trimmed),
    );

    state = state.copyWith(status: ChatStatus.idle);
  }

  /// Looks for a [ProactiveScenario] whose opening line the free-typed
  /// [utterance] is reaching for, so any of the 12 Journey Concierge use
  /// cases can be triggered from the main chat — not only from the
  /// standalone `ScenarioChatPage` reached via the home-screen proactive
  /// feed. Scores every scenario by how many of its first turn's
  /// [ScenarioTurn.matchKeywords] appear in the utterance and returns the
  /// best match, or `null` if nothing scores above zero.
  ProactiveScenario? _matchScenario(String utterance) {
    final normalized = utterance.toLowerCase();
    ProactiveScenario? best;
    var bestScore = 0;
    for (final scenario in scenarioCatalog) {
      final score =
          scenario.turns.first.matchKeywords.where(normalized.contains).length;
      if (score > bestScore) {
        bestScore = score;
        best = scenario;
      }
    }
    return best;
  }

  /// Kicks off [scenario] the way the reminder notification does: no
  /// passenger message has matched anything yet, so this just posts the
  /// scenario's push-notification-style opening line and leaves turn zero
  /// waiting for a reply (via the suggested-reply chip or free text) — the
  /// same starting point as tapping its card on the home-screen feed.
  ///
  /// Called whenever the chat opens straight into a use case — whether the
  /// passenger tapped the reminder notification, or just opened the AI
  /// assistant directly while one was pending (see [ChatPage]'s handling of
  /// [pendingNextScenarioIdProvider]) — so it replaces whatever
  /// [_startNewSession] already seeded (the plain "Hello" welcome) rather
  /// than appending after it.
  Future<void> startScenarioById(String scenarioId) async {
    if (state.isBusy || state.hasActiveScenario) return;
    final scenario = scenarioById(scenarioId);
    if (scenario == null) return;

    state = state.copyWith(messages: const []);
    _appendMessage(
      ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.assistant,
        type: ChatMessageType.text,
        timestamp: DateTime.now(),
        text: scenario.notificationText,
      ),
    );
    state = state.copyWith(activeScenario: scenario, scenarioTurnIndex: 0);
  }

  /// Kicks off a scripted Journey Concierge conversation inline in the main
  /// chat: the passenger's message already matched [scenario]'s opening
  /// line, so this replies with that turn's concierge line (and, on a
  /// single-turn scenario, its concluding action) the same way
  /// [ScenarioChatViewModel] would in the standalone demo.
  Future<void> _startScenario(ProactiveScenario scenario) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _appendMessage(
      ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.assistant,
        type: ChatMessageType.text,
        timestamp: DateTime.now(),
        text: scenario.turns.first.conciergeReply,
      ),
    );
    final isLastTurn = scenario.turns.length == 1;
    if (isLastTurn) {
      _appendMessage(
        ChatMessage(
          id: _uuid.v4(),
          role: ChatRole.assistant,
          type: ChatMessageType.actionSummaryCard,
          timestamp: DateTime.now(),
          payload: scenario.concludingAction,
        ),
      );
      state = state.copyWith(clearActiveScenario: true, scenarioTurnIndex: 0);
      _scheduleNextUseCaseReminder(scenario.id);
    } else {
      state = state.copyWith(activeScenario: scenario, scenarioTurnIndex: 1);
    }
  }

  /// Advances the in-progress [ChatState.activeScenario] by one turn only
  /// when the reply is reaching for that turn's resolution — i.e. the
  /// utterance contains at least one of [ScenarioTurn.matchKeywords].
  /// Anything else is treated as not understood: the scenario stays put on
  /// the same turn (so the suggested-reply chip keeps offering the same
  /// line) rather than silently skipping ahead.
  Future<void> _advanceScenario(String utterance) async {
    final scenario = state.activeScenario;
    if (scenario == null) return;

    final turnIndex = state.scenarioTurnIndex;
    final turn = scenario.turns[turnIndex];
    final normalized = utterance.toLowerCase();
    final matchesTurn = turn.matchKeywords.any(normalized.contains);

    if (!matchesTurn) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      _appendMessage(
        ChatMessage(
          id: _uuid.v4(),
          role: ChatRole.assistant,
          type: ChatMessageType.text,
          timestamp: DateTime.now(),
          text: "Sorry, I didn't quite catch that — could you try again?",
        ),
      );
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 600));

    final isLastTurn = turnIndex == scenario.turns.length - 1;

    _appendMessage(
      ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.assistant,
        type: ChatMessageType.text,
        timestamp: DateTime.now(),
        text: turn.conciergeReply,
      ),
    );

    if (isLastTurn) {
      _appendMessage(
        ChatMessage(
          id: _uuid.v4(),
          role: ChatRole.assistant,
          type: ChatMessageType.actionSummaryCard,
          timestamp: DateTime.now(),
          payload: scenario.concludingAction,
        ),
      );
      state = state.copyWith(clearActiveScenario: true, scenarioTurnIndex: 0);
      _scheduleNextUseCaseReminder(scenario.id);
    } else {
      state = state.copyWith(scenarioTurnIndex: turnIndex + 1);
    }
  }

  /// Once [completedScenarioId] wraps up, nudges the passenger back with a
  /// notification worded exactly like that next moment's in-character push
  /// copy (e.g. "✈️ Family trip to Tokyo, April 4–15: award seats just
  /// opened...") — it's meant to read like the concierge is following up,
  /// not like a system reminder. Tapping it re-opens the chat page, which
  /// calls [startScenarioById]. Also records [next] as "pending" (see
  /// [pendingNextScenarioIdProvider]) — deliberately *not* cleared once
  /// shown, only once overwritten by the scenario after it, so that
  /// navigating back out before finishing it and reopening the assistant
  /// still resumes the same use case instead of falling back to the plain
  /// welcome message. Clears the pending marker after the last scenario in
  /// the catalog, since the trip is over.
  void _scheduleNextUseCaseReminder(String completedScenarioId) {
    final next = nextScenarioAfter(completedScenarioId);
    if (next == null) {
      _setPendingNextScenarioId(null);
      return;
    }
    _setPendingNextScenarioId(next.id);
    _notificationService.showAfterDelay(
      payload: next.id,
      title: 'Journey Concierge',
      body: next.notificationText,
      delay: Duration(seconds: _getReminderDelaySeconds()),
    );
  }

  Future<void> _handleIntent(IntentResult intent, String utterance) async {
    if (intent.isLowConfidence && intent.type != IntentType.faq) {
      _appendEscalationOffer();
      return;
    }

    switch (intent.type) {
      case IntentType.tripDiscovery:
        state = state.copyWith(
          activeIntent: IntentType.tripDiscovery,
          conversationContext: ConversationContext(
            data: intent.entities,
          ),
        );

        await _handleTripDiscovery(
          intent.originalMessage,
        );
        break;

      case IntentType.humanAgent:
        await _handleEscalation(utterance);

      case IntentType.faq:
      case IntentType.unknown:
        await _handleGenericReply(utterance);
      default:
        state = state.copyWith(
          activeIntent: intent.type,
          conversationContext: ConversationContext(
            data: intent.entities,
          ),
        );

        await _handleOthersRequest(intent);
    }
  }

  Future<void> _continueCurrentFlow(String message) async {
    switch (state.activeIntent) {
      case IntentType.tripDiscovery:
        await _handleTripDiscovery(message);
        break;
      default:
        state = state.copyWith(
          clearActiveIntent: true,
        );

        final intentResult = await _classifyIntentUseCase(message);

        await intentResult.fold(
          (failure) async => _appendError(failure.message),
          (intent) async => _handleIntent(intent, message),
        );
    }
  }

  Future<void> _handleTripDiscovery(String userMessage) async {
    // try {
//       final result = await TripDiscoveryService.instance.discover(
//         userMessage: userMessage,
//         context: state.conversationContext.toJson(),
//       );
//
//       state = state.copyWith(
//         conversationContext: ConversationContext.fromJson(
//           result.tripContext.toJson(),
//         ),
//       );
//       print("Trip Context");
//       print(result.tripContext.toJson());
//       // Summary
//       if (result.summary.isNotEmpty) {
//         _appendMessage(
//           ChatMessage(
//             id: _uuid.v4(),
//             role: ChatRole.assistant,
//             type: ChatMessageType.text,
//             timestamp: DateTime.now(),
//             text: result.summary,
//           ),
//         );
//       }
//
//       // Recommendations
//       if (result.recommendations.isNotEmpty) {
//         final recommendationText = result.recommendations
//             .map(
//               (e) => '''
// 📍 ${e.destination}, ${e.country}
//
// 💡 ${e.reason}
//
// 📅 Best Time: ${e.bestTime}
//
// 💰 Budget: ${e.estimatedBudget}
//
// 🗓 Duration: ${e.idealDuration}
// ''',
//             )
//             .join('\n------------------------------\n');
//
//         _appendMessage(
//           ChatMessage(
//             id: _uuid.v4(),
//             role: ChatRole.assistant,
//             type: ChatMessageType.text,
//             timestamp: DateTime.now(),
//             text: recommendationText,
//           ),
//         );
//       }
//
//       // Follow-up question
//       if (result.followUpQuestion.isNotEmpty) {
//         _appendMessage(
//           ChatMessage(
//             id: _uuid.v4(),
//             role: ChatRole.assistant,
//             type: ChatMessageType.text,
//             timestamp: DateTime.now(),
//             text: result.followUpQuestion,
//           ),
//         );
//       }
//     } catch (e) {
//       _appendMessage(
//         ChatMessage(
//           id: _uuid.v4(),
//           role: ChatRole.assistant,
//           type: ChatMessageType.text,
//           timestamp: DateTime.now(),
//           text: "Sorry, something went wrong while discovering trips.",
//         ),
//       );
//     }
  }

  Future<void> _handleOthersRequest(IntentResult intent) async {
    print(intent.originalMessage);
    var response = await _flightService.getFlightResponse(intent.qnPromt);

    final backendData = Map<String, dynamic>.from(
      response['data'] as Map,
    );

    final suggestionsData = backendData['suggestions'];

    final humanized = await ResponseHumanizerService.instance.humanize(
      userMessage: intent.originalMessage,
      backendResponse: backendData,
      suggestions: suggestionsData is List
          ? suggestionsData.map((e) => e.toString()).toList()
          : <String>[],
    );

    _appendMessage(
      ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.assistant,
        type: ChatMessageType.text,
        timestamp: DateTime.now(),
        text: humanized.message,
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
    final result = await _sendMessageUseCase(
        userUtterance: utterance, history: state.messages);
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

/// The scenario a scheduled reminder currently points at, if any — set by
/// [ChatViewModel._scheduleNextUseCaseReminder] and consumed by [ChatPage],
/// so that opening the AI assistant directly (instead of tapping the
/// notification) still resumes that next use case rather than showing the
/// plain welcome message. Deliberately not `autoDispose`: it's set from one
/// chat session and must survive to be read from a later, separate one.
final pendingNextScenarioIdProvider = StateProvider<String?>((ref) => null);

/// `autoDispose` so every fresh push of `ChatPage` (e.g. navigating back to
/// the host app and re-opening the assistant) gets a brand-new
/// [ChatViewModel] — and therefore a reset session — instead of resuming
/// whatever state the previous visit left behind.
final chatViewModelProvider =
    StateNotifierProvider.autoDispose<ChatViewModel, ChatState>((ref) {
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
    bookingSessionStore: ref.watch(bookingSessionStoreProvider),
    notificationService: ref.watch(localNotificationServiceProvider),
    getReminderDelaySeconds: () => ref.read(reminderDelayStoreProvider),
    getVoiceOutputEnabled: () => ref.read(voiceOutputEnabledProvider),
    setPendingNextScenarioId: (id) =>
        ref.read(pendingNextScenarioIdProvider.notifier).state = id,
  );
});
