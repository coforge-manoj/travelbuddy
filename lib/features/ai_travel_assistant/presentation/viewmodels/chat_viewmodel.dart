import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:ai_travel_assistant/core/di/providers.dart';
import 'package:ai_travel_assistant/core/services/local_notification_service.dart';
import 'package:ai_travel_assistant/core/services/reminder_delay_store.dart';
import 'package:ai_travel_assistant/core/services/voice_output_setting_store.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/chat_card_mapper.dart';
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

  /// One per view model, so every fresh chat session gets its own
  /// `x-session-id` and therefore a clean journey on the backend — matching
  /// the local history reset in [_startNewSession].
  final FlightServices _flightService = FlightServices();

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
      suggestions: const [],
      clearPendingConfirmation: true,
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

  /// Every interactive control on a journey card — "Select" on a flight,
  /// "Add" on an extra, a seat on the map — goes back through `/chat` as the
  /// sentence the passenger could have typed instead.
  ///
  /// That is deliberate: the backend holds the basket and the booking
  /// against the session, so a tap and a typed message have to arrive the
  /// same way for the next turn to resolve. It also means the transcript
  /// reads as a conversation either way.
  Future<void> _sendJourneyMessage(String text) async {
    stopSpeaking();
    if (state.isBusy) return;

    _appendMessage(
      ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.user,
        type: ChatMessageType.text,
        timestamp: DateTime.now(),
        text: text,
      ),
    );
    state = state.copyWith(
      status: ChatStatus.sendingMessage,
      clearError: true,
      suggestions: const [],
      clearPendingConfirmation: true,
    );

    await _handleTravelBuddyChat(userMessage: text, apiMessage: text);

    state = state.copyWith(status: ChatStatus.idle);
  }

  /// Called once the passenger taps "Select" on a [FlightOffersCard] entry,
  /// optionally in a specific [cabin] from that flight's `cabin_prices` and
  /// for a party of [pax].
  ///
  /// The passenger count is only stated when it is more than one — the
  /// backend defaults to a single traveller, and "for 1 passenger" reads
  /// oddly in a transcript that is meant to sound like a conversation.
  Future<void> selectFlightOffer(
    String flightNumber, {
    String? cabin,
    int pax = 1,
  }) {
    final buffer = StringBuffer('Select flight $flightNumber');
    if (cabin != null && cabin.isNotEmpty) buffer.write(' in $cabin');
    if (pax > 1) buffer.write(' for $pax passengers');
    return _sendJourneyMessage(buffer.toString());
  }

  /// "Add" on an `extras_list` row.
  Future<void> addExtra(String extraName) =>
      _sendJourneyMessage('Add $extraName');

  /// A seat tapped on a `seat_map` card. Worded the way the backend's own
  /// examples are, so it resolves against the live map.
  Future<void> selectSeat(String seatNumber) =>
      _sendJourneyMessage('Change my seat to $seatNumber');

  /// Entry point for the composer and suggested-prompt chips.
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    stopSpeaking();
    if (state.isBusy) return;

    _appendMessage(
      ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.user,
        type: ChatMessageType.text,
        timestamp: DateTime.now(),
        text: trimmed,
      ),
    );
    state = state.copyWith(
      status: ChatStatus.sendingMessage,
      clearError: true,
      suggestions: const [],
      // Whatever the passenger typed supersedes a confirmation they were
      // asked for and did not answer — including a plain "yes", which the
      // backend accepts as the approval in its own right.
      clearPendingConfirmation: true,
    );

    // If a conversation is already active, first check whether
// the user is continuing it or switching topics.
    if (state.activeIntent != null) {
      // TravelBuddy /chat sessions (search → select → extras) must keep
      // posting follow-ups to the same endpoint — including suggestion taps
      // like "take the cheapest one".
      if (state.activeIntent != IntentType.tripDiscovery) {
        await _handleTravelBuddyChat(
          userMessage: trimmed,
          apiMessage: trimmed,
        );
        state = state.copyWith(status: ChatStatus.idle);
        return;
      }

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
        // Keep the TravelBuddy /chat session alive for follow-ups
        // (suggestions like "take the cheapest one", "Book it", etc.).
        await _handleTravelBuddyChat(
          userMessage: message,
          apiMessage: message,
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
    final apiMessage = intent.qnPromt.trim().isNotEmpty
        ? intent.qnPromt
        : intent.originalMessage;
    await _handleTravelBuddyChat(
      userMessage: intent.originalMessage,
      apiMessage: apiMessage,
    );
  }

  /// Posts to TravelBuddy `/api/v1/chat`, shows `reply` in the bubble,
  /// speaks the humanized copy, and renders every card the turn came back
  /// with.
  ///
  /// [confirm] re-sends [apiMessage] as an approval, which is how the
  /// Confirm button completes a booking, upgrade or cancellation.
  Future<void> _handleTravelBuddyChat({
    required String userMessage,
    required String apiMessage,
    bool confirm = false,
  }) async {
    try {
      final response = await _flightService.getFlightResponse(
        apiMessage,
        confirm: confirm,
      );
      final data = response is Map ? response['data'] : null;
      if (data is! Map) {
        _appendError('Unexpected response from flight assistant.');
        return;
      }

      final backendData = Map<String, dynamic>.from(data);
      final suggestionsData = backendData['suggestions'];
      final suggestions = suggestionsData is List
          ? suggestionsData.map((e) => e.toString()).toList(growable: false)
          : const <String>[];
      final reply = backendData['reply']?.toString() ?? '';
      final needsConfirmation =
          backendData['needsConfirmation'] == true;

      final humanized = await ResponseHumanizerService.instance.humanize(
        userMessage: userMessage,
        backendResponse: backendData,
        suggestions: suggestions,
      );

      final displayText = reply.isNotEmpty ? reply : humanized.message;

      // Anything the backend still wants approved is parked here rather than
      // acted on: the passenger approves it from the confirmation bar, which
      // re-sends this same message with `confirm: true`.
      state = state.copyWith(
        suggestions: suggestions,
        pendingConfirmationMessage: needsConfirmation ? apiMessage : null,
        pendingConfirmationPrompt: needsConfirmation ? displayText : null,
        clearPendingConfirmation: !needsConfirmation,
      );

      if (displayText.isNotEmpty) {
        _appendMessage(
          ChatMessage(
            id: _uuid.v4(),
            role: ChatRole.assistant,
            type: ChatMessageType.text,
            timestamp: DateTime.now(),
            text: displayText,
          ),
          speakAs: humanized.message,
        );
      }

      // Dispatch is on each card's own `type` — a turn can carry more than
      // one card, and the same type shows up under different tools (a
      // `basket` arrives both from adding extras and as the "book it"
      // preview).
      final cards = ChatCardMapper.fromResponse(
        backendData['cards'],
        needsConfirmation: needsConfirmation,
      );
      for (final card in cards) {
        _appendMessage(
          ChatMessage(
            id: _uuid.v4(),
            role: ChatRole.assistant,
            type: card.type,
            timestamp: DateTime.now(),
            text: displayText,
            payload: card.payload,
          ),
        );
      }
    } catch (e) {
      _appendError('Sorry, I could not reach the flight assistant. ($e)');
    }
  }

  /// The affirmation the Confirm button sends.
  ///
  /// The integration guide offers two ways to approve a pending action —
  /// resend the original message with `confirm: true`, or send the
  /// passenger's plain "yes" — but only the second works for every flow.
  /// Resending "cancel my booking" with the flag set gets re-parsed as a
  /// fresh request and answered "Left it as it was", so the booking stays
  /// put while the UI reports it confirmed. "yes" is honoured by checkout,
  /// upgrade and cancellation alike.
  static const _affirmation = 'yes';

  /// Approves the action the last turn asked about.
  Future<void> confirmPendingAction() async {
    stopSpeaking();
    if (!state.needsConfirmation || state.isBusy) return;

    _appendMessage(
      ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.user,
        type: ChatMessageType.text,
        timestamp: DateTime.now(),
        text: 'Yes, go ahead',
      ),
    );
    state = state.copyWith(
      status: ChatStatus.sendingMessage,
      clearError: true,
      clearPendingConfirmation: true,
      suggestions: const [],
    );

    await _handleTravelBuddyChat(
      userMessage: 'Yes, go ahead',
      apiMessage: _affirmation,
      confirm: true,
    );

    state = state.copyWith(status: ChatStatus.idle);
  }

  /// Drops the pending action without telling the backend anything — it only
  /// ever acts on an explicit confirmation, so leaving it unanswered is
  /// enough, and the passenger can keep typing.
  void declinePendingAction() {
    stopSpeaking();
    state = state.copyWith(clearPendingConfirmation: true);
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
    // Also keeps the recognizer from picking the assistant's own voice up as
    // the passenger's next utterance.
    stopSpeaking();
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
      stopSpeaking();
    }
  }

  @override
  void dispose() {
    _voiceService.dispose();
    super.dispose();
  }

  void _appendMessage(ChatMessage message, {String? speakAs}) {
    state = state.copyWith(messages: [...state.messages, message]);
    unawaited(_saveChatMessageUseCase(message));

    final shouldSpeak = message.role == ChatRole.assistant &&
        message.type == ChatMessageType.text &&
        state.isVoiceOutputEnabled;
    if (shouldSpeak) {
      final speechText =
          (speakAs != null && speakAs.trim().isNotEmpty) ? speakAs : message.text;
      unawaited(_speakSafely(speechText));
    }
  }

  /// Cuts the assistant off mid-sentence. Called from every deliberate
  /// passenger interaction — a typed message, a suggestion chip, a tap on a
  /// journey card, an answer to a confirmation, the mic — because carrying on
  /// reading out a reply the passenger has already moved past reads as the
  /// assistant not listening. Deliberately fires even when the interaction is
  /// then dropped (e.g. a tap that lands while [ChatState.isBusy]): the
  /// passenger acted either way.
  ///
  /// Fire-and-forget: nothing downstream waits on the audio actually having
  /// stopped, and the reply for the new turn is spoken by [_appendMessage]
  /// well after this resolves.
  void stopSpeaking() {
    unawaited(_stopSpeakingSafely());
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

  Future<void> _stopSpeakingSafely() async {
    try {
      await _voiceService.stopSpeaking();
    } catch (_) {
      // Intentionally swallowed — see [_speakSafely].
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
