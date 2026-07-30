import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:ai_travel_assistant/core/di/providers.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/agent_escalation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking_summary.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
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
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/search_flights_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/send_message_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/booking_session_store.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_state.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/audio_cue_player.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/proactive_prompt_builder.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/speech_text_formatter.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/talk_back_preference_store.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_action_resolver.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_narrator.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_service.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_summary_builder.dart';

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

/// How long a read-back stays answerable. Short enough that a stray "yes"
/// long after the fact can't trigger a purchase.
const _confirmationWindow = Duration(seconds: 15);

/// How long to wait, after the assistant has finished speaking, before
/// offering a nudge. Long enough for the passenger to actually read a card
/// they have just been read out — a flight list takes a while to scan, and a
/// nudge that lands mid-read feels like being talked over. Governs every step
/// of the silence ladder.
const _proactiveDelay = Duration(seconds: 12);

/// Slightly longer than a talkback listen session's `listenFor` (30s), so the
/// watchdog only fires once the recognizer has genuinely given up.
const _listenWatchdogDelay = Duration(seconds: 32);

/// How long silence may last before the recognizer ends a talkback session.
/// Passengers need a beat after the listening cue before they start speaking,
/// so the default platform pause is too short — but this is also the lag felt
/// after the passenger stops talking, so it stays short enough not to drag.
const _talkBackPauseFor = Duration(seconds: 5);

/// Max length of a single talkback listen session.
const _talkBackListenFor = Duration(seconds: 30);

/// How long a final transcript may still arrive *after* the platform says the
/// listen session is over.
///
/// `speech_to_text` reports `notListening`/`done` as soon as the recognizer
/// closes the microphone, but only delivers the final transcript once its own
/// `finalTimeout` (2s by default) has elapsed — synthesizing one from the last
/// partial if the engine never sends a real final. Treating session-end as the
/// point where results stop being accepted throws that transcript away.
const _finalTranscriptGrace = Duration(seconds: 3);

/// The single orchestrator behind the chat screen: sends user text through
/// intent classification, then routes to the right use case (flight status,
/// seat map, baggage options, airport info, or human escalation) and turns
/// the result into a rich [ChatMessage] the UI can render. Falls back to a
/// free-form AI reply for FAQ/unknown intents.
///
/// It also drives the voice layer: every assistant message is summarized for
/// speech and queued on a [VoiceNarrator], spoken transcripts are resolved
/// against the card on screen before falling back to intent classification,
/// and anything that would book or charge is read back for an explicit yes.
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
    required VoiceNarrator voiceNarrator,
    required AudioCuePlayer audioCuePlayer,
    required BookingSessionStore bookingSessionStore,
    TalkBackPreferenceStore talkBackPreferenceStore = const TalkBackPreferenceStore(),
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
        _narrator = voiceNarrator,
        _cues = audioCuePlayer,
        _talkBackPreference = talkBackPreferenceStore,
        _bookingSessionStore = bookingSessionStore,
        super(const ChatState()) {
    _narrationSubscription = _narrator.speakingChanges.listen(_onNarrationStateChanged);
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
  final VoiceNarrator _narrator;
  final AudioCuePlayer _cues;
  final TalkBackPreferenceStore _talkBackPreference;
  final BookingSessionStore _bookingSessionStore;

  late final StreamSubscription<bool> _narrationSubscription;
  Timer? _proactiveTimer;
  Timer? _confirmationTimer;
  Timer? _listenWatchdog;

  /// Every fresh entry into the chat screen (including navigating back and
  /// re-opening it — see the `autoDispose` on [chatViewModelProvider], which
  /// tears this view model down when nothing is watching it) starts a clean
  /// session: any previous local history is discarded and a welcome message
  /// seeds the conversation. Flight options are no longer shown proactively
  /// — they only appear once the passenger asks to book a flight (see
  /// [_handleBookFlight]).
  Future<void> _startNewSession() async {
    unawaited(_clearChatHistoryUseCase());
    unawaited(_restoreTalkBackPreference());

    final welcome = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.assistant,
      type: ChatMessageType.text,
      timestamp: DateTime.now(),
      text: 'Hello $_demoTravelerFirstName! How can I help you today?',
    );
    state = state.copyWith(status: ChatStatus.idle, messages: [welcome]);
    unawaited(_saveChatMessageUseCase(welcome));
  }

  Future<void> _restoreTalkBackPreference() async {
    final stored = await _talkBackPreference.read();
    if (stored == null || !mounted) return;
    state = state.copyWith(isVoiceOutputEnabled: stored);
    if (!stored) await _narrator.stopAll();
  }

  /// The booking that seat/baggage/status/airport requests should apply to:
  /// the one in progress in the guided post-selection flow, if any,
  /// otherwise the passenger's last confirmed booking from
  /// [_bookingSessionStore] (which survives across chat sessions).
  Booking? get _activeBooking => state.pendingBooking ?? _bookingSessionStore.confirmedBooking;

  /// Triggered by the "Book a Flight" quick action or free text like "I want
  /// to book a flight". Searches (demo route) and shows the flight-offers
  /// card so the passenger can pick one and enter the guided booking flow.
  Future<void> _handleBookFlight() async {
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
  }

  /// Called for seat/baggage/status/airport-info requests when there is no
  /// [_activeBooking] to apply them to — lets the passenger know and offers
  /// to start a booking instead of guessing at a flight.
  Future<void> _offerToBookFlight() async {
    _appendAssistantText(
      "You don't have a flight booked yet. I can help you book one — here are some options:",
    );
    await _handleBookFlight();
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
        _appendAssistantText(
          'Flight ${booking.flight.flightNumber} is reserved — now pick your seat.',
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
    _settleStatus();
  }

  /// Entry point for the composer and suggested-prompt chips.
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isBusy) return;

    _clearPendingConfirmation();
    if (state.dictationDraft.isNotEmpty || state.dictationRevision > 0) {
      state = state.copyWith(dictationDraft: '', dictationRevision: state.dictationRevision + 1);
    }
    _appendUserMessage(trimmed);
    await _classifyAndRoute(trimmed);
  }

  Future<void> _classifyAndRoute(String utterance) async {
    state = state.copyWith(status: ChatStatus.sendingMessage, clearError: true);

    final intentResult = await _classifyIntentUseCase(utterance);
    await intentResult.fold(
      (failure) async => _appendError(failure.message),
      (intent) async => _handleIntent(intent, utterance),
    );

    _settleStatus();
  }

  Future<void> _handleIntent(IntentResult intent, String utterance) async {
    if (intent.isLowConfidence && intent.type != IntentType.faq) {
      _appendEscalationOffer();
      return;
    }

    switch (intent.type) {
      case IntentType.searchFlight:
        await _handleSearchFlights(intent);
      case IntentType.bookFlight:
        await _handleBookFlight();
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
    final booking = _activeBooking;
    if (booking == null) {
      await _offerToBookFlight();
      return;
    }
    final result = await _getFlightStatusUseCase(booking.flight.flightNumber);
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


  Future<void>_handleSearchFlights(IntentResult intent)async{
    print("handle search flights");
  }

  Future<void> _handleSeatSelection() async {
    final booking = _activeBooking;
    if (booking == null) {
      await _offerToBookFlight();
      return;
    }
    _appendFlightInfo(booking);
    final result = await _getSeatMapUseCase(booking.flight.flightNumber);
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

  /// A short text card recapping which flight a seat-map/baggage request
  /// applies to — shown so the passenger can confirm it's the right one
  /// before picking a seat or bag.
  ///
  /// Deliberately not narrated: the card that follows names the same flight,
  /// and hearing it twice in one breath sounds like a stutter.
  void _appendFlightInfo(Booking booking) {
    _appendMessage(
      ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.assistant,
        type: ChatMessageType.text,
        timestamp: DateTime.now(),
        text: 'Flight ${booking.flight.flightNumber}: '
            '${booking.flight.origin} → ${booking.flight.destination} · PNR ${booking.pnr}.',
      ),
      narrate: false,
    );
  }

  /// Called by the seat-selection UI once the passenger taps a seat. Applies
  /// to whichever booking is active: the one just made via
  /// [selectFlightOffer], if the guided flow is in progress, otherwise the
  /// passenger's last confirmed booking.
  Future<void> confirmSeatChange(String seatNumber) async {
    state = state.copyWith(status: ChatStatus.sendingMessage);
    final pendingBooking = state.pendingBooking;
    final activeBooking = _activeBooking;
    final result = await _changeSeatUseCase(
      pnr: activeBooking?.pnr ?? _demoPnr,
      flightNumber: activeBooking?.flight.flightNumber ?? _demoFlightNumber,
      seatNumber: seatNumber,
    );
    await result.fold(
      (failure) async => _appendError(failure.message),
      (seat) async {
        if (pendingBooking != null) {
          state = state.copyWith(pendingSeatNumber: seat.seatNumber);
          _appendAssistantText('Seat ${seat.seatNumber} confirmed. ✅ Want to add any baggage?');
          await _showBaggageOptions(pendingBooking.flight.flightNumber);
        } else {
          _appendAssistantText('You are all set in seat ${seat.seatNumber}. ✅');
        }
      },
    );
    _settleStatus();
  }

  /// Called from "Skip" on [SeatMapCard] while the guided post-booking flow
  /// is active — leaves the seat unassigned and moves straight to baggage
  /// options, same as [confirmSeatChange] does after a seat is picked.
  Future<void> skipSeatSelection() async {
    final booking = state.pendingBooking;
    if (booking == null) return;
    state = state.copyWith(status: ChatStatus.sendingMessage);
    _appendAssistantText("No problem — we'll assign a seat later. Want to add any baggage?");
    await _showBaggageOptions(booking.flight.flightNumber);
    _settleStatus();
  }

  Future<void> _handleBaggage() async {
    final booking = _activeBooking;
    if (booking == null) {
      await _offerToBookFlight();
      return;
    }
    _appendFlightInfo(booking);
    await _showBaggageOptions(booking.flight.flightNumber);
  }

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
    final pnr = _activeBooking?.pnr ?? _demoPnr;
    final result = await _purchaseBaggageUseCase(pnr: pnr, optionId: optionId);
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
    _settleStatus();
  }

  /// Called from the "Add more baggage" action on [BaggageSuccessCard] while
  /// the guided flow is active — re-shows the baggage options so the
  /// passenger can add another bag.
  Future<void> addMoreBaggage() async {
    final booking = state.pendingBooking;
    if (booking == null) return;
    state = state.copyWith(status: ChatStatus.sendingMessage);
    await _showBaggageOptions(booking.flight.flightNumber);
    _settleStatus();
  }

  /// Called from the "Skip"/"Finish" actions on the baggage cards once the
  /// passenger is done adding bags — renders the complete itinerary,
  /// including terminal/gate/boarding info, closes out the guided flow, and
  /// remembers this as the passenger's confirmed booking for future chat
  /// sessions (see [BookingSessionStore]).
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
    _bookingSessionStore.confirmedBooking = booking;
    state = state.copyWith(
      clearPendingBooking: true,
      clearPendingSeatNumber: true,
      pendingBaggagePurchases: const [],
    );
  }

  Future<void> _handleAirportInfo() async {
    final booking = _activeBooking;
    if (booking == null) {
      await _offerToBookFlight();
      return;
    }
    final result = await _getAirportDetailsUseCase(
      flightNumber: booking.flight.flightNumber,
      airportCode: booking.flight.origin,
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
    _appendAssistantText(
      "I'm not fully sure I understood that. Would you like to chat "
      'with a customer support agent instead?',
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

  // -------------------------------------------------------------------------
  // Voice input
  // -------------------------------------------------------------------------

  /// True while the platform listen session is open — i.e. the microphone is
  /// live and the UI should show the listening state.
  bool _listenSessionOpen = false;

  /// True while a transcript for the current session may still be accepted.
  ///
  /// Deliberately outlives [_listenSessionOpen]: the final transcript lands
  /// after the session reports itself finished (see [_finalTranscriptGrace]),
  /// so tying result handling to the session being open drops the very
  /// transcript the passenger just spoke.
  bool _transcriptPending = false;

  /// Bumped per session so callbacks from an earlier one are ignored.
  int _listenGeneration = 0;

  /// Fires when [_finalTranscriptGrace] expires with no transcript delivered.
  Timer? _finalTranscriptTimer;

  /// Starts voice input. Stops any narration first: the summaries end in
  /// questions, so passengers routinely tap the mic while the assistant is
  /// still talking, and an open microphone would otherwise record the
  /// assistant's own voice coming out of the speaker.
  ///
  /// [VoiceInputMode.dictate] (composer mic) streams words into
  /// [ChatState.dictationDraft] so the passenger can edit before sending.
  /// [VoiceInputMode.conversational] (talkback orb) runs the transcript
  /// through [handleVoiceTranscript] immediately.
  Future<void> startVoiceInput({
    VoiceInputMode mode = VoiceInputMode.conversational,
  }) async {
    if (state.isBusy || state.status == ChatStatus.listening) return;

    _cancelProactivePrompt();
    await _narrator.stopAll();
    if (!mounted) return;
    unawaited(_cues.tapFeedback());
    // Awaited, unlike every other cue: the cue player owns the shared audio
    // session while it plays and releases it on completion, so overlapping
    // it with the recognizer silences the microphone. See
    // [AudioCuePlayer.playAndAwait].
    await _playListeningCue();
    if (!mounted) return;

    var heardSomething = false;
    final generation = ++_listenGeneration;
    _listenSessionOpen = true;
    _transcriptPending = true;
    _finalTranscriptTimer?.cancel();
    final talkBack = state.isVoiceOutputEnabled;
    final dictate = mode == VoiceInputMode.dictate;
    if (dictate) {
      state = state.copyWith(
        dictationDraft: '',
        dictationRevision: state.dictationRevision + 1,
      );
    }

    final started = await _voiceService.startListening(
      onResult: (transcript, isFinal) {
        // Guarded on [_transcriptPending], not [_listenSessionOpen], so the
        // final that arrives after session end is still delivered.
        if (generation != _listenGeneration || !_transcriptPending) return;
        if (!mounted) return;
        if (transcript.trim().isNotEmpty) heardSomething = true;

        if (dictate) {
          state = state.copyWith(
            dictationDraft: transcript,
            dictationRevision: state.dictationRevision + 1,
          );
          if (!isFinal) return;
          if (transcript.trim().isEmpty) return;
          _completeListenSession();
          unawaited(_voiceService.stopListening());
          return;
        }

        if (!isFinal) return;
        if (transcript.trim().isEmpty) {
          // Empty finals happen on silence; leave cleanup to onListeningEnded
          // so we don't race the platform session teardown.
          return;
        }
        _completeListenSession();
        unawaited(handleVoiceTranscript(transcript));
      },
      onListeningEnded: () {
        unawaited(
          _onListeningSessionEnded(
            generation: generation,
            heardSomething: heardSomething,
            apologizeOnMiss: !dictate,
          ),
        );
      },
      listenFor: talkBack ? _talkBackListenFor : const Duration(seconds: 15),
      pauseFor: talkBack ? _talkBackPauseFor : const Duration(seconds: 3),
    );

    if (!mounted) return;
    if (!started) {
      _listenSessionOpen = false;
      state = state.copyWith(
        status: ChatStatus.error,
        errorMessage: "Sorry, I didn't catch that.",
      );
      return;
    }

    // Only claim the listening state if the session is still open. A fast
    // final result (or an immediate session end) can land while the `await`
    // above is still unwinding, and unconditionally assigning here would
    // overwrite the idle/handling state that callback just set — stranding
    // the UI in "listening" with the transcript already gone.
    if (!_listenSessionOpen) return;
    state = state.copyWith(status: ChatStatus.listening, clearError: true);

    // Backup if the platform never delivers done/notListening (some engines
    // only fire that after a final result, which silence never produces).
    final watchdogDelay =
        talkBack ? _listenWatchdogDelay : const Duration(seconds: 17);
    _listenWatchdog?.cancel();
    _listenWatchdog = Timer(watchdogDelay, () async {
      if (!mounted || !_listenSessionOpen) return;
      await _onListeningSessionEnded(
        generation: generation,
        heardSomething: heardSomething,
        apologizeOnMiss: !dictate,
      );
    });
  }

  /// Marks the current session finished: no further transcripts accepted, no
  /// pending timers, and the listening UI released.
  void _completeListenSession() {
    _transcriptPending = false;
    _listenSessionOpen = false;
    _listenWatchdog?.cancel();
    _finalTranscriptTimer?.cancel();
    if (mounted && state.status == ChatStatus.listening) {
      state = state.copyWith(status: ChatStatus.idle);
    }
  }

  /// Leaves the listening UI when the platform session ends.
  ///
  /// Crucially this does *not* stop accepting transcripts. The recognizer
  /// reports the session over as soon as it closes the microphone, but the
  /// final transcript follows up to [_finalTranscriptGrace] later — so when
  /// speech was actually heard, the apology waits for that window rather than
  /// firing (or silently dropping the result) the moment the mic closes.
  Future<void> _onListeningSessionEnded({
    required int generation,
    required bool heardSomething,
    required bool apologizeOnMiss,
  }) async {
    if (generation != _listenGeneration || !_listenSessionOpen) return;
    _listenSessionOpen = false;
    await stopVoiceInput();
    if (!mounted || !_transcriptPending) return;

    if (!heardSomething) {
      _transcriptPending = false;
      if (apologizeOnMiss) _appendAssistantText("Sorry, I didn't catch that.");
      return;
    }

    _finalTranscriptTimer?.cancel();
    _finalTranscriptTimer = Timer(_finalTranscriptGrace, () {
      if (!mounted ||
          generation != _listenGeneration ||
          !_transcriptPending) {
        return;
      }
      _transcriptPending = false;
      if (apologizeOnMiss) _appendAssistantText("Sorry, I didn't catch that.");
    });
  }

  Future<void> stopVoiceInput() async {
    _listenSessionOpen = false;
    _listenWatchdog?.cancel();
    await _voiceService.stopListening();
    if (mounted && state.status == ChatStatus.listening) {
      state = state.copyWith(status: ChatStatus.idle);
    }
  }

  /// Interprets a spoken transcript against the card currently on screen
  /// before falling back to normal intent classification.
  ///
  /// Exposed for tests because the only production caller is the speech
  /// recognizer callback, which has no platform channel under `flutter_test`.
  @visibleForTesting
  Future<void> handleVoiceTranscript(String transcript) async {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty || state.isBusy) return;

    final pending = state.confirmationValidAt(DateTime.now());
    final outcome = VoiceActionResolver.resolve(
      transcript: trimmed,
      context: state.voiceContext,
      pendingConfirmation: pending,
    );

    if (outcome == null) {
      await sendMessage(trimmed);
      return;
    }

    _appendUserMessage(trimmed);
    _clearPendingConfirmation();

    switch (outcome) {
      case VoiceAmbiguity(:final question, :final suggestion):
        if (suggestion != null) {
          _proposeAction(suggestion, question);
        } else {
          _appendAssistantText(question);
        }
      case final VoiceAction action:
        await _dispatchVoiceAction(action, pending: pending);
    }
  }

  /// Fires the next silence follow-up immediately. Exposed for tests so the
  /// ladder can be exercised without waiting on TTS and the proactive timer.
  @visibleForTesting
  void debugFireProactivePrompt() => _fireProactivePrompt();

  Future<void> _dispatchVoiceAction(VoiceAction action, {VoiceAction? pending}) async {
    switch (action) {
      case ConfirmPendingAction():
        if (pending == null) {
          _appendAssistantText("I'm not sure what to confirm — what would you like to do?");
          return;
        }
        await _executeVoiceAction(pending);
      case CancelAction():
        _appendAssistantText('Okay, I cancelled that. What would you like to do instead?');
      case _ when action.requiresConfirmation:
        // Booking and charging never happen straight off a transcript: read
        // the price back and wait for an explicit yes.
        _proposeAction(action, action.confirmationPrompt);
      case _:
        await _executeVoiceAction(action);
    }
  }

  Future<void> _executeVoiceAction(VoiceAction action) async {
    switch (action) {
      case SelectOfferAction(:final offer):
        await selectFlightOffer(offer.id);
      case SelectSeatAction(:final seat):
        await confirmSeatChange(seat.seatNumber);
      case SkipSeatAction():
        await skipSeatSelection();
      case SelectBaggageAction(:final option):
        await confirmBaggagePurchase(option.id);
      case SkipBaggageAction():
        await finishBooking();
      case ConfirmPendingAction():
      case CancelAction():
        break;
    }
  }

  /// Reads [prompt] back and arms [action] so a following "yes" runs it.
  void _proposeAction(VoiceAction action, String prompt) {
    state = state.copyWith(
      pendingConfirmation: action,
      pendingConfirmationExpiresAt: DateTime.now().add(_confirmationWindow),
    );
    _appendAssistantText(prompt);

    _confirmationTimer?.cancel();
    _confirmationTimer = Timer(_confirmationWindow, () {
      if (!mounted) return;
      _clearPendingConfirmation();
    });
  }

  void _clearPendingConfirmation() {
    _confirmationTimer?.cancel();
    _confirmationTimer = null;
    if (state.pendingConfirmation == null) return;
    state = state.copyWith(clearPendingConfirmation: true);
  }

  // -------------------------------------------------------------------------
  // Voice output
  // -------------------------------------------------------------------------

  /// Toggles whether assistant replies are read aloud, and remembers the
  /// choice for next time. Turning talkback off also stops any in-flight
  /// listening or speech so the UI can return to a quiet typing mode.
  Future<void> toggleVoiceOutput() async {
    final enabled = !state.isVoiceOutputEnabled;
    state = state.copyWith(isVoiceOutputEnabled: enabled);
    unawaited(_talkBackPreference.write(enabled));

    if (!enabled) {
      if (state.status == ChatStatus.listening) {
        await stopVoiceInput();
      }
      await stopSpeaking();
    }
  }

  /// Silences the assistant immediately, discarding anything still queued
  /// rather than letting the next utterance start.
  Future<void> stopSpeaking() async {
    _cancelProactivePrompt();
    await _narrator.stopAll();
    if (mounted && state.status == ChatStatus.speaking) {
      state = state.copyWith(status: ChatStatus.idle);
    }
  }

  void _onNarrationStateChanged(bool speaking) {
    if (!mounted) return;
    if (speaking) {
      if (state.status == ChatStatus.idle) {
        state = state.copyWith(status: ChatStatus.speaking);
      }
      return;
    }

    if (state.status == ChatStatus.speaking) {
      state = state.copyWith(status: ChatStatus.idle);
    }
    _scheduleProactivePrompt();
  }

  /// Returns to a resting status once a turn is done, staying in `speaking`
  /// while the narrator still has audio to play.
  void _settleStatus() {
    if (!mounted) return;
    state = state.copyWith(status: _narrator.isBusy ? ChatStatus.speaking : ChatStatus.idle);
  }

  // -------------------------------------------------------------------------
  // Proactive follow-ups
  // -------------------------------------------------------------------------

  /// Arms the next silence nudge. Only runs once the passenger has actually
  /// heard the whole turn, and only while the current choice still has
  /// follow-ups left.
  void _scheduleProactivePrompt() {
    _cancelProactivePrompt();
    if (!state.isVoiceOutputEnabled) return;
    if (state.voiceContext.kind == VoiceContextKind.none) return;
    if (!_hasMoreProactiveSteps()) return;

    // Seat/baggage keep a single actionable nudge; don't stack another while
    // a confirmation is live. Flight offers continue the silence ladder even
    // with a cheapest-offer confirmation armed — the next step clears it.
    if (state.pendingConfirmation != null &&
        state.voiceContext.kind != VoiceContextKind.flightOffers) {
      return;
    }

    _proactiveTimer = Timer(_proactiveDelay, _fireProactivePrompt);
  }

  void _cancelProactivePrompt() {
    _proactiveTimer?.cancel();
    _proactiveTimer = null;
  }

  bool _hasMoreProactiveSteps() {
    return ProactivePromptBuilder.hasMoreSteps(
      state.voiceContext.kind,
      state.proactivePromptStep,
    );
  }

  void _fireProactivePrompt() {
    if (!mounted) return;
    if (state.isBusy || state.status == ChatStatus.listening) return;

    final step = state.proactivePromptStep;
    final nudge = ProactivePromptBuilder.build(state.voiceContext, step);
    if (nudge == null) return;

    // Soft follow-ups must not leave a prior "book the cheapest?" confirmation
    // armed — otherwise a polite "yes" to another date could book a flight.
    if (step > 0) {
      _clearPendingConfirmation();
    }

    state = state.copyWith(proactivePromptStep: step + 1);
    unawaited(_playCue(AudioCue.prompt));

    final target = nudge.suggestedAction;
    if (target != null) {
      _proposeAction(target, nudge.text);
    } else {
      _appendAssistantText(nudge.text);
    }
  }

  // -------------------------------------------------------------------------
  // Message plumbing
  // -------------------------------------------------------------------------

  void _appendUserMessage(String text) {
    _appendMessage(
      ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.user,
        type: ChatMessageType.text,
        timestamp: DateTime.now(),
        text: text,
      ),
    );
  }

  void _appendAssistantText(String text) {
    _appendMessage(
      ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.assistant,
        type: ChatMessageType.text,
        timestamp: DateTime.now(),
        text: text,
      ),
    );
  }

  void _appendMessage(ChatMessage message, {bool narrate = true}) {
    _cancelProactivePrompt();

    final context = _voiceContextFor(message);
    final isNewChoice = context != null && context.kind != VoiceContextKind.none;
    state = state.copyWith(
      messages: [...state.messages, message],
      voiceContext: context,
      proactivePromptStep: isNewChoice ? 0 : null,
    );
    unawaited(_saveChatMessageUseCase(message));

    if (message.role != ChatRole.assistant) return;

    unawaited(_playCue(_cueFor(message.type)));

    if (!narrate || !state.isVoiceOutputEnabled) return;

    // Cards are spoken, never read: hand the narrator the facts and let the
    // phrasing layer word them, so the same card doesn't produce the same
    // sentence every session. Plain text and errors are already on screen, so
    // they are spoken as written.
    final draft = VoiceSummaryBuilder.draft(message);
    if (draft != null) {
      _narrator.enqueueDraft(draft);
      return;
    }
    _narrator.enqueue(
      VoiceSummaryBuilder.build(message) ?? SpeechTextFormatter.clean(message.text),
    );
  }

  /// Errors go through the same path as any other message so they are
  /// spoken, cued, and persisted rather than only rendered.
  void _appendError(String message) {
    _appendMessage(
      ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.assistant,
        type: ChatMessageType.error,
        timestamp: DateTime.now(),
        text: message,
      ),
    );
    if (!mounted) return;
    state = state.copyWith(status: ChatStatus.error, errorMessage: message);
  }

  /// The choice a message puts in front of the passenger, or `null` when the
  /// message leaves the current choice untouched (plain text and errors do).
  VoiceContext? _voiceContextFor(ChatMessage message) {
    if (message.role != ChatRole.assistant) return null;
    return switch (message.type) {
      ChatMessageType.flightOffersCard when message.payload is List<FlightOffer> =>
        VoiceContext.flightOffers(message.payload! as List<FlightOffer>),
      ChatMessageType.seatMapCard when message.payload is SeatMap =>
        VoiceContext.seatMap(message.payload! as SeatMap),
      ChatMessageType.baggageOptionsCard when message.payload is List<BaggageOption> =>
        VoiceContext.baggageOptions(message.payload! as List<BaggageOption>),
      ChatMessageType.text || ChatMessageType.error => null,
      _ => const VoiceContext.none(),
    };
  }

  AudioCue? _cueFor(ChatMessageType type) => switch (type) {
        ChatMessageType.error => AudioCue.error,
        ChatMessageType.bookingConfirmationCard ||
        ChatMessageType.baggageSuccessCard =>
          AudioCue.success,
        ChatMessageType.flightOffersCard ||
        ChatMessageType.flightStatusCard ||
        ChatMessageType.seatMapCard ||
        ChatMessageType.baggageOptionsCard ||
        ChatMessageType.airportInfoCard ||
        ChatMessageType.agentEscalationCard =>
          AudioCue.resultsReady,
        ChatMessageType.text => null,
      };

  Future<void> _playCue(AudioCue? cue) async {
    if (cue == null || !state.isSoundEnabled) return;
    await _cues.play(cue);
  }

  /// Plays the mic-open cue to completion so it cannot overlap the
  /// recognizer's hold on the audio session.
  Future<void> _playListeningCue() async {
    if (!state.isSoundEnabled) return;
    await _cues.playAndAwait(AudioCue.listeningStart);
  }

  @override
  void dispose() {
    _cancelProactivePrompt();
    _confirmationTimer?.cancel();
    _listenWatchdog?.cancel();
    _finalTranscriptTimer?.cancel();
    _listenSessionOpen = false;
    _transcriptPending = false;
    unawaited(_narrationSubscription.cancel());
    unawaited(_narrator.stopAll());
    unawaited(_voiceService.stopListening());
    super.dispose();
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
    voiceNarrator: ref.watch(voiceNarratorProvider),
    audioCuePlayer: ref.watch(audioCuePlayerProvider),
    bookingSessionStore: ref.watch(bookingSessionStoreProvider),
  );
});
