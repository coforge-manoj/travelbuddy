import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:ai_travel_assistant/core/di/providers.dart';
import 'package:ai_travel_assistant/core/services/active_account_store.dart';
import 'package:ai_travel_assistant/core/services/local_notification_service.dart';
import 'package:ai_travel_assistant/core/services/reminder_delay_store.dart';
import 'package:ai_travel_assistant/core/services/voice_output_setting_store.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/chat_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/agent_escalation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking_summary.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
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
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/search_flights_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/send_message_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/booking_session_store.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_state.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/card_speech_text_builder.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/speech_chunker.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/speech_log.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/speech_synthesizer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/speech_trace.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/acknowledgement_composer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/small_talk.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_service.dart';
import 'package:ai_travel_assistant/features/concierge_demo/data/scenario_catalog.dart';
import 'package:ai_travel_assistant/features/concierge_demo/domain/entities/proactive_scenario.dart';

import '../../../../core/services/ai_services/conversation_route/conversation_route_service.dart';
import '../../../../core/services/ai_services/humanized_response_service/response_humanizer_service.dart';
import '../../../../core/services/ai_services/trip_discovery/trip_discovery_service.dart';
import '../../data/models/conersation_route/trip_discovery_context.dart';
import '../services/concierge_moments_service.dart';
import '../services/flight_services.dart';

const _uuid = Uuid();

/// Hard-codes the active booking context for this module's standalone demo.
/// In a real host app this comes from the passenger's active
/// booking/session — swap these for a real `currentBookingProvider` at
/// integration time.
const _demoFlightNumber = 'FZ123';
const _demoPnr = 'ABC123';
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
    FlightServices? flightService,
    ConciergeMomentsService? conciergeMoments,
    String? travelerFirstName,
    CardSpeechTextBuilder cardSpeechTextBuilder = const CardSpeechTextBuilder(),
  })  : _flightService = flightService ?? FlightServices(),
        _conciergeMoments = conciergeMoments,
        _travelerFirstName = travelerFirstName ?? demoAccounts.first.firstName,
        _cardSpeechTextBuilder = cardSpeechTextBuilder,
        _sendMessageUseCase = sendMessageUseCase,
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
  final CardSpeechTextBuilder _cardSpeechTextBuilder;

  /// Wording for the lines this class speaks but never shows — currently how to
  /// answer a pending approval. Held as an instance because its pools remember
  /// their last pick, which is what stops a booking's several confirmations
  /// from being read out in identical words.
  final AcknowledgementComposer _acknowledgements = AcknowledgementComposer();

  /// Wording for greetings and sign-offs. An instance for the same reason as
  /// [_acknowledgements]: its pools remember their last pick, and the greeting
  /// is the first line anyone hears in a demo.
  final SmallTalkComposer _smallTalk = SmallTalkComposer();

  /// The signed-in demo passenger's first name, used by the greeting. Comes
  /// from the account switcher on Home (see `activeAccountProvider`).
  final String _travelerFirstName;

  /// One per view model, so every fresh chat session gets its own
  /// `x-session-id` and therefore a clean journey on the backend — matching
  /// the local history reset in [_startNewSession].
  ///
  /// Built by [chatViewModelProvider] against the signed-in account's member
  /// number, and stood in for by tests. Left defaulted rather than required
  /// so tests that don't care about the `/api/v1/chat` path — which is
  /// otherwise unreachable, since the real client posts to a hardcoded
  /// tunnel — can skip it.
  final FlightServices _flightService;

  /// The proactive-moment endpoints. Nullable, and left null by tests that
  /// do not care: every call site treats "no service" the same as "nothing
  /// due", so the booking journey is identical either way.
  final ConciergeMomentsService? _conciergeMoments;

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
      text: _smallTalk.compose(
        SmallTalk.greeting,
        travelerFirstName: _travelerFirstName,
        offers: const [],
      ),
    );
    state = state.copyWith(
      status: ChatStatus.idle,
      messages: [welcome],
      isVoiceOutputEnabled: _getVoiceOutputEnabled(),
      suggestions: const [],
      clearPendingConfirmation: true,
      clearAwaitingDetailsFor: true,
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
      clearAwaitingDetailsFor: true,
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
  ///
  /// [acknowledgement] is a line to say straight away, before any work starts —
  /// what audio mode fills the wait with instead of a silent orb. It is spoken
  /// and never shown: it belongs to the moment, not to the transcript. See
  /// [_speakAside].
  Future<void> sendMessage(String text, {String? acknowledgement}) async {
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
    // After `stopSpeaking`, so the previous answer *and* its follow-up line
    // are dropped before this acknowledgement is queued.
    if (acknowledgement != null) _speakAside(acknowledgement);
    // Read before the reset below: this message is the answer to whatever
    // the backend last asked for (search details, which extra, which seat…).
    final continuesStage = state.awaitingDetailsFor;

    // Small talk is answered here, before any network call, and only when
    // nothing is under way — mid-journey, "that's all" and "no thanks" are
    // answers to the backend's question, not sign-offs, and belong on the
    // journey path.
    //
    // Answered from local copy rather than after classification because the
    // classifier is an LLM round trip: "hello" measured 3.6s to come back
    // `unknown`, which is 3.6 seconds of the passenger waiting to be greeted.
    // It is also why the acknowledgement stays silent for small talk — with
    // nothing to wait for, a "let me pull that up" would be talking over the
    // greeting a moment later.
    // A pending approval is deliberately excluded: "no thanks" with a payment
    // waiting is a refusal, and it has to reach the path that drops the
    // approval and says so — answering "Anytime." would leave the passenger
    // believing they had declined something that is still sitting there.
    if (state.activeIntent == null &&
        continuesStage == null &&
        !state.needsConfirmation &&
        classifySmallTalk(trimmed) != null) {
      _appendSmallTalkOrCapabilities(trimmed);
      state = state.copyWith(status: ChatStatus.idle);
      return;
    }

    state = state.copyWith(
      status: ChatStatus.sendingMessage,
      clearError: true,
      suggestions: const [],

      clearPendingConfirmation: true,
      // Cleared up front so it cannot go stale on a turn that never reaches
      // the backend (escalation, a plain AI reply); the next `/chat`
      // response sets it again from the wire.
      clearAwaitingDetailsFor: true,
    );

    // ============================================================
    // ACTIVE CONVERSATION
    // ============================================================
    // If a conversation is already active, first check whether the user is
    // continuing it or switching topics.
    if (state.activeIntent != null) {
      // Once a journey is under way, TravelBuddy `/chat` sessions (search →
      // select → extras → book) must keep posting follow-ups to the same
      // endpoint verbatim — including suggestion taps like "take the
      // cheapest one" and the plain "yes" that approves a payment. Routing
      // those through the conversation router would re-classify and reword
      // them, and the backend would lose the thread.
      //
      // The exception is a stage still collecting details: the backend has
      // asked for something (origin/date, which extra, which seat) and this
      // message carries the answer. That has to be merged rather than sent
      // on its own, so it goes down the router path below.
      if (state.activeIntent != IntentType.tripDiscovery &&
          continuesStage == null) {
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

      print("===== ROUTER INPUT =====");
      print({
        "currentIntent": state.activeIntent!.name,
        "currentContext": state.conversationContext.toJson(),
        "previousAssistantMessage": lastAssistantMessage,
        "latestUserMessage": trimmed,
      });

      final routerResult = await ConversationRouterService.instance.route(
        activeIntent: state.activeIntent!,
        assistantMessage: lastAssistantMessage,
        userMessage: trimmed,
        context: state.conversationContext.toJson(),
        stageHint: continuesStage == null
            ? null
            : '${continuesStage.id}: ${continuesStage.collectingHint ?? ''}',
      );

      print("===== ROUTER DECISION =====");
      print({
        "continueConversation": routerResult.continueConversation,
        "requiresReclassification": routerResult.requiresReclassification,
        "normalizedPrompt": routerResult.normalizedPrompt,
        "updatedContext": routerResult.updatedContext,
      });

      // ==========================================================
      // CASE 1:
      // SAME INTENT / SAME CONVERSATION
      // ==========================================================

      if (routerResult.continueConversation) {
        state = state.copyWith(
          conversationContext: state.conversationContext.copyWith(
            data: routerResult.updatedContext,
          ),
        );

        await _continueCurrentFlow(
          routerResult.normalizedPrompt,
          stage: continuesStage,
        );

        state = state.copyWith(
          status: ChatStatus.idle,
        );

        return;
      }

      // ==========================================================
      // CASE 2:
      // USER CHANGED TOPIC / INTENT
      // ==========================================================

      if (routerResult.requiresReclassification) {
        print(
          "🔄 Topic changed. Clearing active intent: "
          "${state.activeIntent!.name}",
        );

        state = state.copyWith(
          clearActiveIntent: true,
          conversationContext: ConversationContext(),
        );
      }
    }

    // ============================================================
    // NORMAL INTENT CLASSIFICATION
    // ============================================================
    //
    // This is reached when:
    //
    // 1. There was no active intent
    // OR
    // 2. Router detected an intent/topic switch.
    //
    // Example:
    //
    // activeIntent = searchFlights
    // user = "I want a trip to Australia"
    //
    // Router:
    //   continueConversation = false
    //   requiresReclassification = true
    //
    // Then classifier receives:
    //   "I want a trip to Australia"
    //
    // and can classify it as tripDiscovery.
    // ============================================================

    final intentResult = await _classifyIntentUseCase(trimmed);

    await intentResult.fold(
      (failure) async {
        _appendError(failure.message);
      },
      (intent) async {
        await _handleIntent(
          intent,
          trimmed,
        );
      },
    );

    state = state.copyWith(
      status: ChatStatus.idle,
    );
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
  /// [_startNewSession] already seeded (the greeting welcome) rather
  /// than appending after it.
  /// Opens the chat on a proactive moment the *backend* wrote, replacing the
  /// generic welcome with [openingLine].
  ///
  /// Deliberately not [startScenarioById]. That one sets `activeScenario`,
  /// which puts the chat into scripted mode — every following turn is matched
  /// against the playbook's lines and a `SuggestedReplyChip` offers the
  /// passenger's next scripted sentence. Here the notification is only an
  /// opening: what the passenger says next must go to `/chat` as free text
  /// like any other message, so no scenario is started.
  Future<void> startFromProactiveMessage(String openingLine) async {
    if (state.isBusy || state.hasActiveScenario) return;
    final trimmed = openingLine.trim();
    if (trimmed.isEmpty) return;

    final opening = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.assistant,
      type: ChatMessageType.text,
      timestamp: DateTime.now(),
      text: trimmed,
    );
    state = state.copyWith(messages: [opening]);
    unawaited(_saveChatMessageUseCase(opening));
  }

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
    // The classifier never answered — it timed out or errored. Post the
    // message to TravelBuddy `/chat` rather than apologizing for it: that
    // endpoint does its own routing, and it is where this message was headed
    // anyway on almost every intent. A router being slow is not a reason to
    // hand the passenger to a human agent.
    //
    // Checked before the confidence test, because a failed call reports
    // confidence 0.0 and would otherwise read as the passenger being unclear.
    if (intent.classifierFailed) {
      await _handleTravelBuddyChat(
        userMessage: utterance,
        apiMessage: utterance,
      );
      return;
    }

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
          intent.qnPromt,
        );
        break;

      case IntentType.humanAgent:
        await _handleEscalation(utterance);

      // Both land here because neither has a working answer path: the
      // generic-reply endpoint they used to share is a placeholder host.
      // Small talk is answered in kind; anything genuinely unplaceable gets
      // the capability offer, which is the honest reply and is strictly better
      // than the connection error it replaces.
      case IntentType.faq:
      case IntentType.unknown:
        _appendSmallTalkOrCapabilities(utterance);
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

  Future<void> _continueCurrentFlow(
    String message, {
    JourneyStage? stage,
  }) async {
    switch (state.activeIntent) {
      case IntentType.tripDiscovery:
        await _handleTripDiscovery(message);
        break;
      default:
        // Search still needs re-classification so a complete `qnPrompt` is
        // built. Every other collecting stage posts the router's normalized
        // prompt (or the raw message) straight to `/chat`.
        if (stage != null && !stage.isSearch) {
          final apiMessage = message.trim().isNotEmpty ? message : '';
          if (apiMessage.isEmpty) return;
          await _handleTravelBuddyChat(
            userMessage: apiMessage,
            apiMessage: apiMessage,
          );
          return;
        }

        // [message] is the router's normalized prompt, e.g. "flights from
        // Delhi to London on 2026-07-26".
        state = state.copyWith(clearActiveIntent: true);

        final intentResult = await _classifyIntentUseCase(message);

        await intentResult.fold(
          (failure) async => _appendError(failure.message),
          (intent) async => _handleIntent(intent, message),
        );
    }
  }

  Future<void> _handleTripDiscovery(String userMessage) async {
    try {
      final result = await TripDiscoveryService.instance.discover(
        userMessage: userMessage,
        context: state.conversationContext.toJson(),
      );

      final backendData = <String, dynamic>{
        'reply': result.answer,
        'answer': result.answer,
        'suggestions': result.suggestions,
      };

      final humanized = await ResponseHumanizerService.instance.humanize(
        userMessage: userMessage,
        backendResponse: backendData,
        suggestions: result.suggestions,
        intent: 'tripDiscovery',
      );

      final displayText = humanized.message.trim().isNotEmpty
          ? humanized.message
          : result.answer;

      state = state.copyWith(
        suggestions: result.suggestions,
      );

      if (displayText.trim().isNotEmpty) {
        _appendMessage(
          ChatMessage(
            id: _uuid.v4(),
            role: ChatRole.assistant,
            type: ChatMessageType.text,
            timestamp: DateTime.now(),
            text: displayText,
          ),
        );
      }
    } catch (e, stackTrace) {
      print("========== Trip Discovery Error ==========");
      print(e);
      print(stackTrace);

      _appendError(
        'Sorry, something went wrong while discovering trips.',
      );
    }
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

  /// Posts to TravelBuddy `/api/v1/chat`, shows `reply` in the bubble, and
  /// renders every card the turn came back with. Narration is handled by
  /// [_appendMessage], which coalesces the whole turn into one utterance.
  ///
  /// [confirm] re-sends [apiMessage] as an approval, which is how the
  /// Confirm button completes a booking, upgrade or cancellation.
  ///
  /// [isRepair] marks the one automatic re-post allowed after a misfire —
  /// tracked here rather than in state so it cannot leak across turns.
  Future<void> _handleTravelBuddyChat({
    required String userMessage,
    required String apiMessage,
    bool confirm = false,
    bool isRepair = false,
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
      final outcome = ChatCardMapper.outcomeOf(backendData);
      final stage = ChatCardMapper.stageOf(backendData);

      // Repair once before anything is rendered. Non-mutating misfires always
      // qualify; mutating ones only when this post was already a confirmation
      // (the documented "Left it as it was." case) — a fresh cancel/book is
      // never silently re-posted.
      if (outcome == TurnOutcome.misfire &&
          !isRepair &&
          stage != null &&
          stage.repairMessage != null &&
          (!stage.mutating || confirm)) {
        await _handleTravelBuddyChat(
          userMessage: userMessage,
          apiMessage: stage.repairMessage!,
          confirm: confirm,
          isRepair: true,
        );
        return;
      }

      final reply = backendData['reply']?.toString() ?? '';
      final needsConfirmation =
          ChatCardMapper.requiresConfirmation(backendData);

      // Empty on a turn that produced nothing to act on — see
      // [ChatCardMapper.followUpsFrom].
      var suggestions = ChatCardMapper.followUpsFrom(backendData);

      // After a failed repair (or a mutating misfire we refused to retry),
      // offer the stage's corrective chip so the passenger can decide.
      if (outcome == TurnOutcome.misfire &&
          stage?.correctiveChip != null &&
          !suggestions.contains(stage!.correctiveChip)) {
        suggestions = [...suggestions, stage.correctiveChip!];
      }

      // The reply is shown as the backend worded it. There used to be an
      // awaited `ResponseHumanizerService.humanize()` call here, rewording it
      // for speech — but `displayText` preferred the raw `reply` anyway, so on
      // every turn where the backend said anything at all (which is nearly all
      // of them) the app paid a full LLM round trip, measured at 1.9–3.3s,
      // for a string it then discarded. It also sat *before* the first render,
      // so that cost was time the passenger spent watching a typing indicator.
      //
      // Wording for the ear is now `SpeechSummaryService`'s job, downstream of
      // the bubble rather than in front of it, and it is bounded by a timeout
      // with an offline fallback — neither of which the humanizer had.
      final displayText = reply;

      // Anything the backend still wants approved is parked here rather than
      // acted on: the passenger approves it from the confirmation bar, which
      // re-sends this same message with `confirm: true`.
      state = state.copyWith(
        suggestions: suggestions,
        pendingConfirmationMessage: needsConfirmation ? apiMessage : null,
        pendingConfirmationPrompt:
            needsConfirmation ? _confirmationPrompt(displayText) : null,
        clearPendingConfirmation: !needsConfirmation,
        // Park collecting stages so the next message is merged rather than
        // posted on its own. Cleared explicitly on every other outcome.
        awaitingDetailsFor: outcome == TurnOutcome.collecting ? stage : null,
        clearAwaitingDetailsFor: outcome != TurnOutcome.collecting,
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

      // The follow-ups, spoken. On screen they are chips the passenger can
      // read; in audio mode there may be nothing in their eyeline at all, and
      // several steps of the journey — checking in, upgrading, trip details —
      // are only ever offered this way.
      //
      // Queued through `_speakAside`, so it lands after the answer and its
      // cards rather than racing them, and so the turn does not settle (and the
      // microphone does not reopen) until it has been said.
      //
      // Skipped while something awaits approval: the backend has just asked a
      // direct question, and offering alternatives on top of it invites an
      // answer to the wrong one. The approval gets its own line instead —
      // audio mode now shows the same Confirm bar as chat, but a passenger
      // who is not looking still has to hear the yes/no.
      _speakAside(
        needsConfirmation
            ? _acknowledgements.composeConfirmationOptions(
                stageId: ChatCardMapper.confirmationStageId(backendData),
              )
            : _acknowledgements.composeSuggestionLine(suggestions),
      );

      if (needsConfirmation && stage == JourneyStage.checkout) {
        await _raiseDocumentIssuesBeforePaying();
      }
    } catch (e) {
      debugPrint('TravelBuddy /chat failed: $e');
      _appendError(
        'Sorry, I could not reach the flight assistant.',
        retrySuggestion: apiMessage,
      );
    }
  }

  /// Wording for the confirmation bar (and the spoken "shall I?").
  ///
  /// Checkout already asks "Shall I go ahead?" in the backend reply. Upgrade
  /// quotes often do not — they state the price and stop — so without this
  /// the bar reads as a statement and voice mode never asks for a yes.
  static String _confirmationPrompt(String reply) {
    final trimmed = reply.trim();
    if (trimmed.isEmpty) return 'Shall I go ahead?';
    final ended = RegExp(r'[.!?]$').hasMatch(trimmed) ? trimmed : '$trimmed.';
    if (ended.endsWith('?')) return ended;
    return '$ended Shall I go ahead?';
  }

  /// Whether the document warning has already been raised this session, so a
  /// second trip through checkout does not repeat it.
  bool _documentInterruptRaised = false;

  /// Speaks up about passport problems *before* the passenger pays.
  ///
  /// This is the one proactive moment in the booking journey. It is a message
  /// in the conversation rather than a notification on purpose: the passenger
  /// is looking at the confirm bar with the app in front of them, and a push
  /// banner for something happening on screen would be theatre.
  ///
  /// Every failure path is silent. The copy is the backend's
  /// (`/trips/{id}/pending`), so if the trip has no document issue due — a
  /// member with no seeded trip, an unreachable tunnel — there is simply
  /// nothing to say, and the checkout the passenger asked for proceeds
  /// untouched.
  ///
  /// Deliberately **not** marked delivered on the backend. Doing so would
  /// drop it out of `/pending` permanently, so the moment would fire once per
  /// backend restart and a second rehearsal would silently lose it. The
  /// in-session [_documentInterruptRaised] flag is the right scope for "don't
  /// say this twice" — it stops the nag repeating in one conversation while
  /// leaving the demo re-runnable.
  Future<void> _raiseDocumentIssuesBeforePaying() async {
    if (_documentInterruptRaised) return;

    final copy = await _conciergeMoments?.pendingPushCopyFor(
      ConciergeMomentsService.documentReadinessUseCase,
    );
    if (copy == null || copy.isEmpty) return;

    _documentInterruptRaised = true;
    _appendMessage(
      ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.assistant,
        type: ChatMessageType.text,
        timestamp: DateTime.now(),
        text: copy,
      ),
    );
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
  ///
  /// [acknowledgement] is spoken immediately, as in [sendMessage] — and matters
  /// more here than anywhere else, because this is the turn that spends money
  /// and the passenger should hear that their "yes" landed.
  Future<void> confirmPendingAction({String? acknowledgement}) async {
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
    if (acknowledgement != null) _speakAside(acknowledgement);
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
  void declinePendingAction({String? acknowledgement}) {
    stopSpeaking();
    state = state.copyWith(clearPendingConfirmation: true);
    // Nothing is fetched for a refusal, so this line is the entire turn. In
    // audio mode there is no confirmation bar to visibly disappear, and without
    // it a "no" is answered by silence — which the passenger reads as not
    // having been heard.
    if (acknowledgement != null) _speakAside(acknowledgement);
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

  /// What the assistant can actually do, in journey order.
  ///
  /// Two wordings per capability, because the same fact is said from two
  /// mouths: [chip] is what the *passenger* would ask for, and is posted
  /// verbatim when tapped — so it has to be a phrase the backend routes, and
  /// matches the corrective chips on [JourneyStage]. [offer] is the
  /// *assistant* describing itself, which cannot reuse the chip: "I can check
  /// me in" is what happens when it does.
  static const _capabilities = <({String chip, String offer})>[
    (chip: 'Book a flight', offer: 'book you a flight'),
    (chip: 'Check me in', offer: 'check you in'),
    (chip: 'Show the seat map', offer: 'sort out your seat'),
    (chip: 'Quote an upgrade', offer: 'price up an upgrade'),
    (chip: 'Show my trip details', offer: 'pull up your trip details'),
  ];

  /// The reply to something the assistant could not place.
  ///
  /// This used to go to `_sendMessageUseCase`, which posts to
  /// `dioProvider`'s placeholder host (`api.example-airline.com`) — a domain
  /// that does not resolve. Every unplaceable utterance therefore ended in a
  /// connection error rendered as "No internet connection.", blaming the
  /// passenger's phone for an endpoint that was never stood up. Answering from
  /// the capability list needs no network at all, and tells the passenger the
  /// one thing that actually moves the conversation forward.
  ///
  /// The chips are set as well as spoken: on screen they are tappable, and in
  /// audio mode the first two are read out by the line itself.
  /// Answers a greeting as a greeting, and anything else the classifier could
  /// not place with the capability offer.
  ///
  /// "Hello" reaches this method as `IntentType.unknown` — the classifier looks
  /// for a travel action and a greeting contains none — so without this check
  /// the first thing a passenger hears is the assistant saying it cannot help
  /// with hello.
  ///
  /// The chips are set for the openers and left alone for the closers: someone
  /// saying thanks or goodbye is finishing, and putting a fresh menu in front
  /// of them is the conversational equivalent of not letting them leave.
  void _appendSmallTalkOrCapabilities(String utterance) {
    final kind = classifySmallTalk(utterance);
    if (kind == null) {
      _appendCapabilityOffer();
      return;
    }

    _appendMessage(
      ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.assistant,
        type: ChatMessageType.text,
        timestamp: DateTime.now(),
        text: _smallTalk.compose(
          kind,
          travelerFirstName: _travelerFirstName,
          offers: _capabilities.map((c) => c.offer).toList(),
        ),
      ),
    );

    if (kind == SmallTalk.thanks || kind == SmallTalk.farewell) return;
    state = state.copyWith(
      suggestions: _capabilities.map((c) => c.chip).toList(),
    );
  }

  /// Three of the five, not all of them: read aloud, a five-item list is a menu
  /// being recited, and the chips carry the rest for anyone looking at the
  /// screen.
  void _appendCapabilityOffer() {
    final offers = _capabilities.take(3).map((c) => c.offer).toList();

    _appendMessage(
      ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.assistant,
        type: ChatMessageType.text,
        timestamp: DateTime.now(),
        text: "I'm not sure I can help with that one. I can ${offers[0]}, "
            '${offers[1]}, or ${offers[2]} — among other things. '
            'What would you like to do?',
      ),
    );

    state = state.copyWith(
      suggestions: _capabilities.map((c) => c.chip).toList(),
    );
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
  void toggleVoiceOutput() =>
      setVoiceOutputEnabled(!state.isVoiceOutputEnabled);

  /// Turns chat read-aloud on or off for this session. Does not persist to
  /// the More-tab default — that is applied once, when the session starts.
  ///
  /// Voice mode borrows this flag while it is open (the hands-free loop
  /// cannot run muted) and restores it on the way out, so a passenger who
  /// left chat TTS off is not then read to on the transcript.
  void setVoiceOutputEnabled(bool enabled) {
    if (state.isVoiceOutputEnabled == enabled) return;
    state = state.copyWith(isVoiceOutputEnabled: enabled);
    if (!enabled) stopSpeaking();
  }

  @override
  void dispose() {
    _burstSpeechSources.clear();
    _speechActivity.close();
    _voiceService.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Speech
  // ---------------------------------------------------------------------------

  /// Where the assistant's voice is up to.
  ///
  /// Exists for the hands-free conversation loop, which reopens the microphone
  /// when the assistant stops talking and so needs a single "the turn has
  /// finished speaking" edge. It cannot use the individual playback futures:
  /// one turn appends a text bubble *and* several cards, so the first future to
  /// resolve is nowhere near the end of the answer.
  Stream<SpeechActivity> get speechActivity => _speechActivity.stream;
  final _speechActivity = StreamController<SpeechActivity>.broadcast();

  /// The session-opening line, when it has not been heard yet.
  ///
  /// A fresh chat is assistant bubbles and no passenger turn. Voice mode
  /// reads that bubble on entry so the greeting on screen is also the
  /// greeting in the ear; once the passenger has spoken, or the line has
  /// already been read out, this is null and the loop goes straight to the
  /// microphone.
  String? get unspokenOpening {
    final messages = state.messages;
    if (messages.isEmpty) return null;
    if (messages.any((m) => m.role == ChatRole.user)) return null;
    final text = messages.last.text.trim();
    if (text.isEmpty) return null;
    if (_lastSpokenLine.trim() == text) return null;
    return text;
  }

  /// Speaks [line] without appending it — the words are already on screen.
  void speakLine(String line) => _speakAside(line);

  /// Speech sources from the replies appended in the current synchronous
  /// burst, flushed as one narration by [_flushBurstSpeech].
  ///
  /// [fromCard] records whether a source was composed from a card payload,
  /// which decides two things: card narration supersedes the backend's reply
  /// for the same turn, and factual lines skip the LLM summarizer.
  final List<({String text, bool fromCard})> _burstSpeechSources = [];

  /// Whether a flush is already scheduled for the current burst.
  bool _burstFlushScheduled = false;

  /// Serializes utterances so a second reply's audio doesn't cut the first off
  /// mid-sentence. Each link awaits full prepare + playback.
  Future<void> _speechChain = Future<void>.value();

  /// The last line handed to the synthesizer, verbatim.
  ///
  /// This is what the passenger actually heard, which is not recoverable from
  /// the transcript: for a card turn the bubble holds the caption ("Here's your
  /// boarding pass") while the spoken line is the narration built from the
  /// payload ("Gate 25, seat 12 A…"). The echo guard compares against it, so
  /// reconstructing it from `messages.last` would compare the wrong words in
  /// exactly the case that matters.
  String get lastSpokenLine => _lastSpokenLine;
  String _lastSpokenLine = '';

  /// Utterances prepared or playing. [SpeechActivity.settled] is emitted when
  /// this returns to zero with no flush pending — that pair of conditions is
  /// what makes "the whole turn has been spoken" distinguishable from "the
  /// first of three messages has been spoken".
  int _pendingUtterances = 0;

  /// Bumped by [abortSpeechQueue] to abandon in-flight speech. Compared either
  /// side of the `await` in [_speakSafely], because synthesis outlives the turn
  /// that asked for it.
  int _speechEpoch = 0;

  /// Position in the speech queue, handed to each utterance as it is queued.
  int _queueSeq = 0;

  /// The queue position of the newest *answer*.
  ///
  /// An acknowledgement compares its own position against this to find out
  /// whether the thing it was covering has arrived. Answers only — a second
  /// filler is no reason to cut the first one short.
  int _answerSeq = 0;

  /// Emits [messages] as one burst, the way a turn that posts a reply and
  /// several cards does. Exists so burst coalescing can be tested without
  /// standing up a live backend.
  @visibleForTesting
  void debugAppendMessages(List<ChatMessage> messages) {
    for (final message in messages) {
      _appendMessage(message);
    }
  }

  /// Queues an aside the way a turn's follow-up line does, for speech tests.
  @visibleForTesting
  void debugSpeakAside(String line) => speakLine(line);

  /// Bubbles are never held back waiting on audio: the message is committed
  /// immediately and the speech catches up. Reading a reply that starts being
  /// spoken a moment later is far better than watching an empty typing
  /// indicator while a synthesizer works.
  ///
  /// A single turn emits a text bubble and every card it came back with, one
  /// after another with no `await` between them. Narrating each separately
  /// would talk over itself and, worse, would signal "finished speaking" at the
  /// first one. They are instead joined into a single narration: the flush runs
  /// in a microtask, which is exactly the window a synchronous burst occupies,
  /// so replies separated by real work land in different bursts and are each
  /// spoken — which is the intent, since they answer different steps.
  void _appendMessage(ChatMessage message) {
    _commitMessage(message);
    if (!_shouldSpeak(message)) return;

    final line = _speechLineFor(message);
    if (line == null) return;

    final source = _withoutRepetition(line.text.trim());
    if (source.isEmpty) {
      SpeechLog.dropped('repeats a line already in this burst', line.text);
      return;
    }

    SpeechLog.source(
      origin: message.type == ChatMessageType.text
          ? 'reply'
          : 'card:${message.type.name}',
      factual: line.isFactual,
      text: source,
    );

    // A card's narration supersedes the backend's one-line summary of the same
    // turn. Both describe the answer, in different words, so keeping the reply
    // means saying it twice — and the card's version is the better one aloud,
    // built from the payload with codes spelled out.
    if (line.isFactual) {
      for (final superseded in _burstSpeechSources.where((s) => !s.fromCard)) {
        SpeechLog.dropped('superseded by card narration', superseded.text);
      }
      _burstSpeechSources.removeWhere((source) => !source.fromCard);
    }

    _burstSpeechSources.add(
      (text: source, fromCard: line.isFactual),
    );

    if (_burstFlushScheduled) return;
    _burstFlushScheduled = true;
    scheduleMicrotask(_flushBurstSpeech);
  }

  /// Removes anything already queued in this burst from [source].
  ///
  /// A live turn hands every card the reply as its caption, and the card
  /// narration is built as caption-then-detail — so the reply would be spoken
  /// once by its own bubble and again at the head of every card. With two cards
  /// the passenger hears the same sentence three times, which is precisely how
  /// it sounded on a device.
  ///
  /// A backstop for two cards in one turn that restate each other verbatim.
  /// The reply-versus-card case is handled by precedence, not by string
  /// matching, because those two word the same facts differently.
  String _withoutRepetition(String source) {
    var result = source;
    for (final said in _burstSpeechSources) {
      if (said.text.isEmpty) continue;
      if (result == said.text) return '';
      if (result.startsWith(said.text)) {
        result = result.substring(said.text.length).trim();
      } else if (said.text.contains(result)) {
        return '';
      }
    }
    return result;
  }

  void _flushBurstSpeech() {
    _burstFlushScheduled = false;
    final joined = _burstSpeechSources.map((s) => s.text).join('\n\n');
    final factual = _burstSpeechSources.any((s) => s.fromCard);
    final sourceCount = _burstSpeechSources.length;
    _burstSpeechSources.clear();
    if (joined.isEmpty || !mounted || !state.isVoiceOutputEnabled) {
      _settleIfQuiet();
      return;
    }

    _lastSpokenLine = joined;
    _pendingUtterances++;
    _emitActivity(SpeechActivity.preparing);

    final id =
        SpeechLog.queued('burst', joined, detail: 'sources=$sourceCount');

    // Timed from here rather than inside `_speakSafely`: waiting for the
    // previous utterance to finish is part of the delay a passenger feels, and
    // it is invisible from inside the link that finally runs.
    final queued = Stopwatch()..start();
    final epoch = _speechEpoch;

    // Published before the render starts: this is the signal an acknowledgement
    // still playing is watching for, and it should see it the instant the
    // answer exists rather than once the answer is also rendered.
    final seq = ++_queueSeq;
    _answerSeq = seq;

    final rendering = _renderAhead(
      joined,
      summarize: !factual,
      epoch: epoch,
      logId: id,
      aside: false,
    );
    _speechChain = _speechChain.then(
      (_) => _speakSafely(
        rendering,
        epoch: epoch,
        seq: seq,
        queuedFor: queued,
        logId: id,
      ),
    );
  }

  /// Speaks [line] without putting it in the transcript.
  ///
  /// For the acknowledgement said while a turn is in flight. It is heard, not
  /// read: a bubble for it would leave the history full of "Sure, let me check
  /// that" with the answer somewhere below, and re-reading the conversation
  /// later would be twice as long for no more information.
  ///
  /// Never summarized — it is one short sentence already written for the ear,
  /// and the summarizer's round trip is longer than the wait this is filling.
  void _speakAside(String line) {
    final text = line.trim();
    if (text.isEmpty || !mounted || !state.isVoiceOutputEnabled) return;

    // The answer goes first, always.
    //
    // A burst is flushed from a microtask, which is a whole turn later than
    // this method runs — so an aside queued in the same synchronous stretch as
    // the reply and its cards would join the chain *ahead* of them. Measured on
    // a device: the follow-up line beat the flight card by 2ms, and the
    // passenger was told "you could book the recommended one" six seconds
    // before hearing what the options were.
    //
    // Flushing here rather than deferring the aside, because an aside is also
    // queued at the *start* of a turn (the acknowledgement) when there is
    // nothing pending — that one must stay immediate, and deferring every aside
    // by a microtask would put it behind the next burst instead of in front of
    // it. The already-scheduled microtask still runs and finds the sources
    // drained.
    if (_burstFlushScheduled) _flushBurstSpeech();

    // The echo guard compares what the microphone hears against this, and for a
    // turn whose answer is silent (voice output off mid-turn, or an empty
    // reply) this is the last thing that actually came out of the speaker.
    _lastSpokenLine = text;
    _pendingUtterances++;
    _emitActivity(SpeechActivity.preparing);

    // Logged as `aside`, and deliberately noting that this joins the chain
    // synchronously while a burst waits on a microtask: the two are queued from
    // the same turn, so their relative order here is the order they are heard.
    final id = SpeechLog.queued(
      'aside',
      text,
      detail: 'burstPending=$_burstFlushScheduled',
    );

    final queued = Stopwatch()..start();
    final epoch = _speechEpoch;
    final seq = ++_queueSeq;
    final rendering = _renderAhead(
      text,
      summarize: false,
      epoch: epoch,
      logId: id,
      aside: true,
    );
    _speechChain = _speechChain.then(
      (_) => _speakSafely(
        rendering,
        epoch: epoch,
        seq: seq,
        queuedFor: queued,
        aside: true,
        logId: id,
      ),
    );
  }

  void _commitMessage(ChatMessage message) {
    // Queued appends outlive the session: the passenger can leave while an
    // earlier reply is still synthesizing, and everything behind it in the
    // queue then lands on a disposed notifier.
    if (!mounted) return;
    state = state.copyWith(messages: [...state.messages, message]);
    unawaited(_saveChatMessageUseCase(message));
  }

  bool _shouldSpeak(ChatMessage message) {
    if (message.role != ChatRole.assistant) return false;
    if (!state.isVoiceOutputEnabled) return false;
    if (message.type == ChatMessageType.text) return true;

    // Cards are narrated on whichever engine is selected. This used to be
    // gated on the neural engine, from a design where a card's bubble was held
    // back until its audio was ready — which the device engine, rendering at
    // playback time, could never satisfy. Messages are no longer held back for
    // audio, so the gate had no purpose left except to silence every booking,
    // boarding pass and travel history the moment the device voice was chosen.
    return _cardSpeechTextBuilder.build(message) != null;
  }

  /// What gets spoken for [message], and whether this code composed it.
  ///
  /// A card's `text` is only a caption — the substance is in its payload, so
  /// the builder describes the card and that is spoken instead. A message
  /// carrying its own [ChatMessage.spokenText] has already answered this
  /// question, and is treated as factual: something upstream deliberately chose
  /// those words, and they should not then be reworded.
  SpokenLine? _speechLineFor(ChatMessage message) {
    final explicit = message.spokenText;
    if (explicit != null && explicit.trim().isNotEmpty) {
      return SpokenLine.fromCard(explicit);
    }
    final built = _cardSpeechTextBuilder.build(message);
    if (built != null) return built;
    return message.text.trim().isEmpty ? null : SpokenLine.prose(message.text);
  }

  /// Cuts the assistant off mid-sentence **and drops anything still queued**
  /// — the follow-up "you can say check me in" included. Called from every
  /// deliberate passenger interaction — a typed message, a suggestion chip, a
  /// tap on a journey card, an answer to a confirmation, the mic — because
  /// carrying on after the passenger has already moved past reads as the
  /// assistant not listening. Deliberately fires even when the interaction is
  /// then dropped (e.g. a tap that lands while [ChatState.isBusy]): the
  /// passenger acted either way.
  ///
  /// Does not emit [SpeechActivity.settled]: the caller is usually about to
  /// queue a new acknowledgement, and a settled edge here would reopen the
  /// microphone on a turn that has only just started. Use [abortSpeechQueue]
  /// when the conversation is actually over (interrupt, leave audio mode).
  void stopSpeaking() {
    _dropQueuedSpeech('user acted');
    unawaited(_stopSpeakingSafely());
  }

  /// Abandons everything queued, in flight, or playing, and reports the turn
  /// as settled — the interrupt / leave-audio-mode path.
  void abortSpeechQueue() {
    _dropQueuedSpeech('queue abandoned');
    unawaited(_stopSpeakingSafely());
    _emitActivity(SpeechActivity.settled);
  }

  /// Bumps the speech epoch so every in-flight link abandons itself, and
  /// clears a burst that has not flushed yet. Without the epoch bump,
  /// [stopSpeaking] only silences what is audible: a follow-up already in
  /// the chain (the spoken suggestion line) would start the moment the
  /// current clip ended.
  void _dropQueuedSpeech(String reason) {
    SpeechLog.aborted(
      '$reason (pending=$_pendingUtterances '
      'burstSources=${_burstSpeechSources.length})',
    );
    _speechEpoch++;
    _burstSpeechSources.clear();
    _burstFlushScheduled = false;
    _pendingUtterances = 0;
  }

  /// Words [speechSource] and renders its opening chunk **without waiting for
  /// the speaker to be free**.
  ///
  /// This is the difference between the acknowledgement covering the wait and
  /// merely preceding it. The acknowledgement exists to fill the seconds a turn
  /// takes, but the answer's own preparation — an LLM rewrite of up to 3.4s,
  /// then synthesis — used to begin only once the acknowledgement had finished
  /// playing, because it lived inside the chained link. Measured on a device:
  /// the backend answered 1.0s before the acknowledgement ended, and the
  /// passenger still waited another 3.4s in silence while the summarizer ran on
  /// text that had been sitting ready the whole time.
  ///
  /// Started at queue time instead, that work happens *during* the
  /// acknowledgement, and [_speakSafely] finds a finished clip waiting.
  ///
  /// Safe to run concurrently with playback: both synthesizers' `prepare` is
  /// stateless — Cartesia posts and returns bytes, the device engine only
  /// stamps the text for `play` to render — so nothing here touches the audio
  /// currently coming out of the speaker.
  Future<_RenderedSpeech?> _renderAhead(
    String speechSource, {
    required bool summarize,
    required int epoch,
    required int logId,
    required bool aside,
  }) async {
    // Summarized once for the whole line, then split — so both halves are
    // worded by the same pass and only one LLM round trip is paid for.
    final spoken = await _resolveSpokenTextSafely(speechSource, summarize);
    if (spoken.trim().isEmpty || epoch != _speechEpoch) return null;
    SpeechLog.resolved(logId, spoken, summarized: summarize);

    // An acknowledgement is split per sentence on either engine, because for it
    // the split is not about render latency at all — it is what gives
    // [_speakSafely] a boundary to stop on once the answer lands.
    //
    // For an answer, chunking exists only to overlap a network render with
    // playback. The device engine has no render step — it speaks as it goes —
    // so splitting there would put seams between the pieces for nothing.
    final chunks = aside
        ? sentencesForSpeech(spoken)
        : _voiceService.rendersAheadOfPlayback
            ? chunkForSpeech(spoken)
            : [spoken];
    SpeechLog.chunked(logId, chunks);

    return _RenderedSpeech(
        chunks, await _prepareSpeechSafely(chunks.first, false));
  }

  /// Plays what [rendering] produced, once whatever is in front of it has
  /// finished. The session is re-checked either side of the wait, because
  /// synthesis outlives the turn that started it: the passenger can leave,
  /// mute, or interrupt while it is in flight.
  ///
  /// [epoch] is captured when the utterance was *queued*, not when this runs —
  /// so [abortSpeechQueue] discards work that was already in the chain behind
  /// the interruption, rather than letting it read the post-abort epoch and
  /// carry on.
  Future<void> _speakSafely(
    Future<_RenderedSpeech?> rendering, {
    required int epoch,
    required int seq,
    Stopwatch? queuedFor,
    bool aside = false,
    int logId = 0,
  }) async {
    final trace = SpeechTrace.begin(
      'text→audio',
      detail: 'queued=${queuedFor?.elapsedMilliseconds ?? 0}ms',
    );

    try {
      final rendered = await rendering;
      if (rendered == null || epoch != _speechEpoch) {
        trace?.end(detail: 'aborted=no-text');
        SpeechLog.finished(
          logId,
          rendered == null ? 'aborted=no-text' : 'aborted=interrupted',
        );
        return;
      }

      final chunks = rendered.chunks;
      var spokeAnything = false;

      // The first chunk is already rendered — that is the whole point of
      // [_renderAhead]. From the second onwards the pipeline resumes: each
      // chunk's synthesis is started before the previous one is played, so the
      // remainder renders during playback instead of after it.
      Future<PreparedSpeech?>? pending = Future.value(rendered.first);

      for (var i = 0; i < chunks.length; i++) {
        final prepared = await pending;
        pending = i + 1 < chunks.length
            ? _prepareSpeechSafely(chunks[i + 1], false)
            : null;

        // The filler has done its job: the answer it was covering is queued
        // behind it, so the rest of it would delay the very thing it exists to
        // introduce. Measured before this: a 132-character acknowledgement kept
        // talking for 3.1s after the flight options were ready to speak.
        //
        // Never before the first sentence — something has to be said, or a
        // request is met with the silence the acknowledgement was added to
        // remove. Stopping between sentences rather than mid-word is what keeps
        // it sounding like a person finishing a thought.
        if (aside && i > 0 && _answerSeq > seq) {
          trace?.end(detail: 'ack cut short at ${i}/${chunks.length}');
          SpeechLog.finished(
            logId,
            'cut short — answer ready',
            detail: 'spoke $i of ${chunks.length} sentences',
          );
          return;
        }

        if (prepared == null ||
            epoch != _speechEpoch ||
            !mounted ||
            !state.isVoiceOutputEnabled) {
          final why = prepared == null ? 'aborted=no-audio' : 'aborted=left';
          trace?.end(detail: why);
          SpeechLog.finished(logId, why, detail: 'atChunk=${i + 1}');
          return;
        }

        // Once per turn, on the first audible chunk: the loop treats this as
        // "the assistant started talking", and a second one mid-line would be
        // a phase change the passenger never saw.
        if (!spokeAnything) {
          spokeAnything = true;
          _emitActivity(
            aside ? SpeechActivity.acknowledging : SpeechActivity.playing,
          );
        }
        SpeechLog.speaking(
          logId,
          prepared.spokenText,
          chunk: i + 1,
          ofChunks: chunks.length,
        );
        await _playSpeechSafely(prepared);
      }
      trace?.end(detail: 'chunks=${chunks.length}');
      SpeechLog.finished(logId, 'done', detail: 'chunks=${chunks.length}');
    } catch (error) {
      // This future *is* [_speechChain]. Letting it reject would leave every
      // utterance queued behind it unspoken for the rest of the session, and
      // surface as an unhandled async error far from here. The individual steps
      // all swallow their own failures, so reaching this is unexpected rather
      // than routine — but the cost of being wrong about that is silence.
      trace?.end(detail: 'aborted=threw');
      SpeechLog.finished(logId, 'aborted=threw',
          detail: '${error.runtimeType}');
    } finally {
      // Aborted links must not decrement or settle: [_dropQueuedSpeech] already
      // zeroed the count, and a settled edge here would reopen the microphone
      // on a turn the passenger has only just started (or a sheet they just
      // opened).
      if (epoch == _speechEpoch) {
        if (_pendingUtterances > 0) _pendingUtterances--;
        _settleIfQuiet();
      }
    }
  }

  Future<String> _resolveSpokenTextSafely(String text, bool summarize) async {
    try {
      return await _voiceService.resolveSpokenText(text, summarize: summarize);
    } catch (_) {
      // Summarization is an enhancement — never let it silence the reply.
      return text;
    }
  }

  /// Announces the end of the turn's speech once nothing is playing, no further
  /// utterance is about to be queued, and the turn itself has finished.
  ///
  /// The turn condition is what makes the acknowledgement safe. It is spoken
  /// *during* the turn, so it empties the speech queue seconds before the
  /// answer exists — and on its own that looks exactly like the turn having
  /// finished speaking, which would send the conversation loop back to the
  /// microphone while the answer was still being fetched. The passenger would
  /// be invited to speak, and then talked over.
  void _settleIfQuiet() {
    if (!mounted) return;
    if (_pendingUtterances == 0 && !_burstFlushScheduled && !state.isBusy) {
      _emitActivity(SpeechActivity.settled);
    }
  }

  /// Watches the busy→idle edge, so a turn that ends without speaking still
  /// announces itself.
  ///
  /// [_settleIfQuiet] holds `settled` back for the whole time a turn is in
  /// flight, which leaves one case with nobody to report it: a turn that
  /// finishes having said nothing at all — an error, an empty reply, or voice
  /// output switched off mid-turn. Without this the loop would wait out its
  /// twenty-second watchdog before asking again.
  ///
  /// Hooked here rather than at each `status: ChatStatus.idle` because there
  /// are eight of those across five entry points, several behind early returns.
  @override
  set state(ChatState value) {
    final wasBusy = state.isBusy;
    super.state = value;
    if (wasBusy && !value.isBusy) _settleIfQuiet();
  }

  void _emitActivity(SpeechActivity activity) {
    if (!_speechActivity.isClosed) _speechActivity.add(activity);
  }

  /// Voice output is a nice-to-have; a plugin/platform failure here (e.g. no
  /// TTS engine installed) should never break the chat flow itself.
  Future<PreparedSpeech?> _prepareSpeechSafely(
    String text,
    bool summarize,
  ) async {
    try {
      return await _voiceService.prepareSpeech(text, summarize: summarize);
    } catch (_) {
      // Intentionally swallowed — see doc comment above.
      return null;
    }
  }

  Future<void> _playSpeechSafely(PreparedSpeech speech) async {
    try {
      await _voiceService.playSpeech(speech);
    } catch (_) {
      // Intentionally swallowed — see [_prepareSpeechSafely].
    }
  }

  Future<void> _stopSpeakingSafely() async {
    try {
      await _voiceService.stopSpeaking();
    } catch (_) {
      // Intentionally swallowed — see [_prepareSpeechSafely].
    }
  }

  void _appendError(String message, {String? retrySuggestion}) {
    state = state.copyWith(
      status: ChatStatus.error,
      errorMessage: message,
      suggestions: retrySuggestion == null || retrySuggestion.trim().isEmpty
          ? state.suggestions
          : [retrySuggestion],
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

/// One utterance, worded and part-rendered, waiting only for the speaker.
///
/// [first] is the opening chunk's audio, already synthesized; the rest of
/// [chunks] are rendered as playback moves through them. `null` means the
/// synthesizer had nothing to give, which the caller treats as "say nothing"
/// rather than as an error — voice output is never allowed to break the chat.
class _RenderedSpeech {
  const _RenderedSpeech(this.chunks, this.first);

  final List<String> chunks;
  final PreparedSpeech? first;
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
  // Watched, not read: switching accounts on Home rebuilds the view model,
  // which starts a fresh chat session against the new member number.
  final account = ref.watch(activeAccountProvider);
  return ChatViewModel(
    flightService: FlightServices(memberNo: account.memberNo),
    conciergeMoments:
        ref.watch(conciergeMomentsServiceProvider(account.memberNo)),
    travelerFirstName: account.firstName,
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
