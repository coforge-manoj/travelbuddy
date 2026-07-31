import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/widgets.dart' show AppLifecycleState;
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
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/search_flights_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/send_message_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/booking_session_store.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_state.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/audio_cue_player.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/display_text_formatter.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/proactive_prompt_builder.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/speech_phraser.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/speech_text_formatter.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/talk_back_preference_store.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_action_parser.dart';
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

/// Shown (and spoken) when the recognizer will not start or has failed, as
/// opposed to simply not having heard anything.
const _micUnavailableMessage =
    "I can't reach the microphone right now. Check that microphone access is "
    'allowed, or tap the keyboard to type instead.';

/// How long a read-back stays answerable. Long enough to hear the
/// confirmation and reply even when TTS is slow.
const _confirmationWindow = Duration(seconds: 45);

/// How long to wait, after the assistant has finished speaking, before
/// offering a nudge. Long enough for the passenger to actually read a card
/// they have just been read out — a flight list takes a while to scan, and a
/// nudge that lands mid-read feels like being talked over. Governs every step
/// of the silence ladder.
const _proactiveDelay = Duration(seconds: 12);

/// Slightly longer than a talkback listen session's `listenFor` (30s), so the
/// watchdog only fires once the recognizer has genuinely given up.
const _listenWatchdogDelay = Duration(seconds: 32);

/// How long the microphone waits for the passenger to *begin* talking before
/// the recognizer gives up on the session.
///
/// The patient end of the wait, deliberately: the microphone opens on its own
/// now, so the passenger has not just tapped anything and may still be
/// gathering the thought. Closing on them at that point is worse than holding
/// an empty microphone open a few seconds longer.
const _talkBackPauseFor = Duration(seconds: 5);

/// How long a pause *after* the passenger has started talking is taken as
/// them having finished.
///
/// Shorter than [_talkBackPauseFor] on purpose: once there are words to work
/// with, every further second of held-open microphone is a second the
/// passenger spends wondering whether they were heard. The recognizer has no
/// separate end-of-speech window, so this is timed against the partial
/// transcripts it streams.
const _endOfSpeechPause = Duration(seconds: 2);

/// Max length of a single talkback listen session.
const _talkBackListenFor = Duration(seconds: 30);

/// How long after the assistant stops speaking the microphone opens by
/// itself. Just long enough for playback to release the audio session and for
/// the mic-open cue to land as its own beat, rather than clipping the tail of
/// the sentence it follows.
const _voiceHandoffDelay = Duration(milliseconds: 400);

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
/// speech and queued on a [VoiceNarrator], the microphone opens by itself once
/// a spoken turn finishes so the passenger can simply answer, spoken
/// transcripts are resolved against the card on screen before falling back to
/// intent classification, and anything that would book or charge is read back
/// for an explicit yes.
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
    VoiceActionParser voiceActionParser = const RuleBasedVoiceActionParser(),
    SpeechPhraser speechPhraser = const FallbackSpeechPhraser(),
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
        _voiceActionParser = voiceActionParser,
        _speechPhraser = speechPhraser,
        _talkBackPreference = talkBackPreferenceStore,
        _bookingSessionStore = bookingSessionStore,
        super(const ChatState()) {
    _narrationSubscription = _narrator.phaseChanges.listen(_onNarrationPhaseChanged);
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
  final VoiceActionParser _voiceActionParser;
  final SpeechPhraser _speechPhraser;
  final TalkBackPreferenceStore _talkBackPreference;
  final BookingSessionStore _bookingSessionStore;

  late final StreamSubscription<NarrationPhase> _narrationSubscription;
  Timer? _proactiveTimer;
  Timer? _confirmationTimer;
  /// True when [pendingConfirmation] was armed by a silence nudge rather than
  /// by the passenger — only those may be replaced by the next ladder step.
  bool _pendingFromProactive = false;
  Timer? _listenWatchdog;
  Timer? _voiceHandoffTimer;

  /// True while the turn on its way to the speaker should hand the microphone
  /// back once it finishes. Cleared by anything that silences the assistant
  /// deliberately — muting, barge-in, backgrounding — so "be quiet" is never
  /// answered with an open microphone.
  bool _handoffPending = false;

  /// Set once a hands-free open has failed. The orb still works; the
  /// assistant just stops reaching for a microphone it cannot have, instead of
  /// grabbing at it after every single turn.
  bool _handoffUnavailable = false;

  /// False while the passenger has chosen the keyboard even though talkback is
  /// on. Kept in sync by [setHandsFreeEnabled] from the chat screen.
  bool _handsFreeEnabled = true;

  /// Talkback and cues only run while the app is in front. Kept in sync by
  /// [handleAppLifecycle] from the chat screen's binding observer.
  bool _appInForeground = true;

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
    // The offers card that follows names the route and the fares, so the
    // spoken half stops at the fact the passenger doesn't have yet.
    _appendAssistantText(
      "You don't have a flight booked yet. I can help you book one — here are some options:",
      speakAs: "You don't have a flight booked yet, but I can help you book one.",
    );
    await _handleBookFlight();
  }

  /// Called once the passenger taps "Select" on a [FlightOffersCard] entry.
  /// Books the flight, then kicks off the guided seat → baggage flow that
  /// [confirmSeatChange], [confirmBaggagePurchase], [addMoreBaggage], and
  /// [finishBooking] carry forward.
  Future<void> selectFlightOffer(String offerId) async {
    // Guided flow already past flight selection — ignore scrollback / repeat taps.
    if (state.pendingBooking != null || !_canActOnCard(ChatMessageType.flightOffersCard)) {
      return;
    }
    // A UI selection is the passenger jumping ahead of whatever the
    // assistant is still saying — cut it off rather than talk over the flow.
    await stopSpeaking();
    if (!mounted) return;
    state = state.copyWith(
      status: ChatStatus.sendingMessage,
      highlightedOfferId: offerId,
      clearHighlightedSeatNumber: true,
      clearHighlightedBaggageOptionId: true,
      clearPendingConfirmation: true,
    );
    final result = await _bookFlightUseCase(offerId: offerId, passengerName: _demoTravelerFullName);
    await result.fold(
      (failure) async => _appendError(failure.message),
      (booking) async {
        _lockCards({ChatMessageType.flightOffersCard});
        state = state.copyWith(
          pendingBooking: booking,
          confirmedOfferId: offerId,
          clearPendingSeatNumber: true,
          clearConfirmedSeatNumber: true,
          pendingBaggagePurchases: const [],
          confirmedBaggageOptionIds: const [],
        );
        _appendAssistantText(
          'Flight ${DisplayTextFormatter.flightNumber(booking.flight.flightNumber)} '
          'is reserved — now pick your seat.',
          speakAs: 'Flight ${SpeechTextFormatter.flightNumber(booking.flight.flightNumber)} '
              'is reserved.',
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
  ///
  /// When a selectable card (or a pending confirmation) is active, the same
  /// voice-action parser runs as for speech — so typing "book JetBlue" or
  /// "yes" works the same way as saying it.
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isBusy) return;

    if (state.dictationDraft.isNotEmpty || state.dictationRevision > 0) {
      state = state.copyWith(dictationDraft: '', dictationRevision: state.dictationRevision + 1);
    }

    if (await _tryHandleCardUtterance(trimmed)) return;

    _clearPendingConfirmation();
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
      // The phrasing model returns `searchFlights` for "find / show / book
      // flights"; both routes land on the same demo offers card.
      case IntentType.searchFlight:
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
    if (!_canActOnCard(ChatMessageType.seatMapCard)) return;
    await stopSpeaking();
    if (!mounted) return;
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
        _lockCards({ChatMessageType.seatMapCard});
        state = state.copyWith(
          confirmedSeatNumber: seat.seatNumber,
          pendingSeatNumber: pendingBooking != null ? seat.seatNumber : null,
        );
        final displaySeat = DisplayTextFormatter.seat(seat.seatNumber);
        final spokenSeat = SpeechTextFormatter.seat(seat.seatNumber);
        if (pendingBooking != null) {
          // "Want to add any baggage?" stays on screen but out of the audio:
          // the baggage card queued right behind this asks the same thing, and
          // hearing the question twice in one breath sounds like a stutter.
          _appendAssistantText(
            'Seat $displaySeat confirmed. ✅ Want to add any baggage?',
            speakAs: 'Seat $spokenSeat confirmed.',
          );
          await _showBaggageOptions(pendingBooking.flight.flightNumber);
        } else {
          _appendAssistantText(
            'You are all set in seat $displaySeat. ✅',
            speakAs: 'You are all set in seat $spokenSeat.',
          );
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
    if (booking == null || !_canActOnCard(ChatMessageType.seatMapCard)) return;
    await stopSpeaking();
    if (!mounted) return;
    state = state.copyWith(status: ChatStatus.sendingMessage);
    _lockCards({ChatMessageType.seatMapCard});
    state = state.copyWith(clearConfirmedSeatNumber: true, clearPendingSeatNumber: true);
    _appendAssistantText(
      "No problem — we'll assign a seat later. Want to add any baggage?",
      speakAs: "No problem, we'll assign a seat later.",
    );
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
    if (!_canActOnCard(ChatMessageType.baggageOptionsCard)) return;
    await stopSpeaking();
    if (!mounted) return;
    state = state.copyWith(status: ChatStatus.sendingMessage);
    final booking = state.pendingBooking;
    final pnr = _activeBooking?.pnr ?? _demoPnr;
    final result = await _purchaseBaggageUseCase(pnr: pnr, optionId: optionId);
    result.fold(
      (failure) => _appendError(failure.message),
      (purchase) {
        _lockCards({ChatMessageType.baggageOptionsCard});
        final nextConfirmedIds = [...state.confirmedBaggageOptionIds, purchase.option.id];
        if (booking != null) {
          state = state.copyWith(
            pendingBaggagePurchases: [...state.pendingBaggagePurchases, purchase],
            confirmedBaggageOptionIds: nextConfirmedIds,
          );
        } else {
          state = state.copyWith(confirmedBaggageOptionIds: nextConfirmedIds);
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
    await stopSpeaking();
    if (!mounted) return;
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
    await stopSpeaking();
    if (!mounted) return;

    // Lock any still-open baggage (and earlier) selection cards so scrollback
    // cannot change choices after the itinerary is finalized.
    _lockCards({
      ChatMessageType.flightOffersCard,
      ChatMessageType.seatMapCard,
      ChatMessageType.baggageOptionsCard,
    });

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

  /// Listen sessions that came back empty in a row, reset by the first
  /// transcript that lands. Keeps [_reportListenMiss] from repeating itself.
  int _consecutiveListenMisses = 0;

  /// Fires when [_finalTranscriptGrace] expires with no transcript delivered.
  Timer? _finalTranscriptTimer;

  /// Fires when the passenger has been quiet for [_endOfSpeechPause] after
  /// actually saying something.
  Timer? _endOfSpeechTimer;

  /// Starts voice input. Stops any narration first: the summaries end in
  /// questions, so passengers routinely tap the mic while the assistant is
  /// still talking, and an open microphone would otherwise record the
  /// assistant's own voice coming out of the speaker.
  ///
  /// [VoiceInputMode.dictate] (composer mic) streams words into
  /// [ChatState.dictationDraft] so the passenger can edit before sending.
  /// [VoiceInputMode.conversational] (talkback orb) runs the transcript
  /// through [handleVoiceTranscript] immediately.
  ///
  /// [handsFree] marks a session the assistant opened by itself once it
  /// finished speaking (see [_scheduleVoiceHandoff]). Nobody asked for it, so
  /// it stays quieter about coming up empty than a session the passenger
  /// deliberately started.
  Future<void> startVoiceInput({
    VoiceInputMode mode = VoiceInputMode.conversational,
    bool handsFree = false,
  }) async {
    if (state.isBusy || state.status == ChatStatus.listening) return;

    _handoffPending = false;
    _cancelVoiceHandoff();
    _cancelProactivePrompt();
    await _narrator.stopAll();
    if (!mounted) return;
    // No tap happened, so there is no tap to acknowledge — the mic-open cue
    // below is what tells the passenger the floor is theirs.
    if (!handsFree) unawaited(_cues.tapFeedback());
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
    _endOfSpeechTimer?.cancel();
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

        if (!isFinal) {
          if (transcript.trim().isNotEmpty) {
            _armEndOfSpeech(generation, transcript);
          }
          return;
        }
        if (transcript.trim().isEmpty) {
          // Empty finals happen on silence; leave cleanup to onListeningEnded
          // so we don't race the platform session teardown.
          return;
        }
        _completeListenSession();
        unawaited(handleVoiceTranscript(transcript));
      },
      onListeningEnded: (reason) {
        unawaited(
          _onListeningSessionEnded(
            generation: generation,
            heardSomething: heardSomething,
            reason: reason,
            apologizeOnMiss: !dictate,
            handsFree: handsFree,
          ),
        );
      },
      listenFor: talkBack ? _talkBackListenFor : const Duration(seconds: 15),
      pauseFor: talkBack ? _talkBackPauseFor : const Duration(seconds: 2),
    );

    if (!mounted) return;
    if (!started) {
      _listenSessionOpen = false;
      _transcriptPending = false;
      if (handsFree) {
        // The passenger asked for nothing, so they are told nothing — but a
        // microphone that will not open now will not open on the next turn
        // either, and announcing that after every reply is its own kind of
        // broken. They can still tap the orb, which does say so.
        _handoffUnavailable = true;
        return;
      }
      if (dictate) {
        state = state.copyWith(
          status: ChatStatus.error,
          errorMessage: _micUnavailableMessage,
        );
      } else {
        // Spoken as well as shown: someone driving the assistant by voice is
        // the least likely to be looking at the screen.
        _appendAssistantText(_micUnavailableMessage);
      }
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
        reason: VoiceListenEndReason.completed,
        apologizeOnMiss: !dictate,
        handsFree: handsFree,
      );
    });
  }

  /// Treats [_endOfSpeechPause] of quiet, once real words have arrived, as the
  /// passenger having finished their sentence — rather than waiting out the
  /// recognizer's longer [_talkBackPauseFor] window, which exists for the
  /// passenger who has not started speaking at all.
  void _armEndOfSpeech(int generation, String transcript) {
    _endOfSpeechTimer?.cancel();
    _endOfSpeechTimer = Timer(_endOfSpeechPause, () {
      if (!mounted || generation != _listenGeneration || !_transcriptPending) {
        return;
      }
      _completeListenSession();
      unawaited(_voiceService.stopListening());
      unawaited(handleVoiceTranscript(transcript));
    });
  }

  /// Marks the current session finished: no further transcripts accepted, no
  /// pending timers, and the listening UI released.
  void _completeListenSession() {
    _transcriptPending = false;
    _listenSessionOpen = false;
    _consecutiveListenMisses = 0;
    _listenWatchdog?.cancel();
    _finalTranscriptTimer?.cancel();
    _endOfSpeechTimer?.cancel();
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
    required VoiceListenEndReason reason,
    required bool apologizeOnMiss,
    bool handsFree = false,
  }) async {
    if (generation != _listenGeneration || !_listenSessionOpen) return;
    _listenSessionOpen = false;
    await stopVoiceInput();
    if (!mounted || !_transcriptPending) return;

    if (!heardSomething) {
      _transcriptPending = false;
      if (handsFree) {
        // A microphone the passenger never asked for closes again without
        // comment: they were reading the card, not mumbling at it. The silence
        // ladder — cancelled when this session opened — takes over from here.
        if (reason == VoiceListenEndReason.recognizerFailed) {
          _handoffUnavailable = true;
        }
        _scheduleProactivePrompt();
        return;
      }
      if (apologizeOnMiss) _reportListenMiss(reason);
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
      if (apologizeOnMiss) _reportListenMiss(reason);
    });
  }

  /// Tells the passenger a listen session came back empty — but only while
  /// saying so is still useful.
  ///
  /// The apology used to fire on every miss, so a passenger the microphone
  /// genuinely could not hear was met with the same sentence over and over.
  /// After the second consecutive miss the assistant stops narrating its own
  /// failure and just returns to rest.
  void _reportListenMiss(VoiceListenEndReason reason) {
    if (reason == VoiceListenEndReason.recognizerFailed) {
      _consecutiveListenMisses = 0;
      _appendAssistantText(_micUnavailableMessage);
      return;
    }

    _consecutiveListenMisses++;
    if (_consecutiveListenMisses == 1) {
      _appendAssistantText("Sorry, I didn't catch that.");
    } else if (_consecutiveListenMisses == 2) {
      _appendAssistantText(
        "I'm still not hearing anything. Try speaking a little closer to the "
        'phone, or tap the keyboard to type instead.',
      );
    }
  }

  Future<void> stopVoiceInput() async {
    _listenSessionOpen = false;
    _listenWatchdog?.cancel();
    _endOfSpeechTimer?.cancel();
    await _voiceService.stopListening();
    if (mounted && state.status == ChatStatus.listening) {
      state = state.copyWith(status: ChatStatus.idle);
    }
  }

  /// Shuts the microphone because the assistant is about to speak.
  ///
  /// The recognizer cannot tell the passenger's voice from the speaker's: a
  /// session left open across a spoken turn transcribes the assistant's own
  /// words and then answers them. [startVoiceInput] enforces the same rule
  /// from the other side, silencing narration before it opens the microphone.
  ///
  /// The bumped generation is what makes this an abandonment rather than a
  /// stop: whatever the recognizer still has in flight belongs to a turn the
  /// passenger has already moved on from — by tapping a card, typically — so
  /// delivering it late would answer a question nobody is still asking. It
  /// also keeps the empty session from being reported as a misheard one.
  void _closeMicrophoneForSpeech() {
    if (!_listenSessionOpen && !_transcriptPending) return;
    _listenGeneration++;
    _completeListenSession();
    unawaited(_voiceService.stopListening());
  }

  /// Interprets a spoken transcript against the card currently on screen
  /// before falling back to normal intent classification.
  ///
  /// Uses [VoiceActionParser] (rules first, LLM when the card context is
  /// active and the phrase is unfamiliar) so passengers can select flights,
  /// seats, and baggage by speaking natural language.
  ///
  /// Exposed for tests because the only production caller is the speech
  /// recognizer callback, which has no platform channel under `flutter_test`.
  @visibleForTesting
  Future<void> handleVoiceTranscript(String transcript) async {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty || state.isBusy) return;

    if (await _tryHandleCardUtterance(trimmed)) return;

    _clearPendingConfirmation();
    _appendUserMessage(trimmed);
    await _classifyAndRoute(trimmed);
  }

  /// Shared path for typed and spoken card commands. Returns `true` when the
  /// utterance was handled as a card action (including confirm/cancel).
  Future<bool> _tryHandleCardUtterance(String trimmed) async {
    final pending = state.confirmationValidAt(DateTime.now());
    if (pending == null && state.voiceContext.kind == VoiceContextKind.none) {
      return false;
    }

    final outcome = await _voiceActionParser.resolve(
      transcript: trimmed,
      context: state.voiceContext,
      pendingConfirmation: pending,
    );
    if (outcome == null) return false;

    _appendUserMessage(trimmed);
    final confirming = outcome is ConfirmPendingAction;
    _clearPendingConfirmation(keepHighlights: confirming);

    switch (outcome) {
      case VoiceAmbiguity(:final question, :final suggestion, :final speechText):
        if (suggestion != null) {
          _proposeAction(suggestion, speechText, displayText: question);
        } else {
          _appendAssistantText(question, speakAs: speechText);
        }
      case final VoiceAction action:
        await _dispatchVoiceAction(action, pending: pending);
    }
    return true;
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
        state = state.copyWith(clearCardHighlights: true);
        _appendAssistantText('Okay, I cancelled that. What would you like to do instead?');
      case _ when action.requiresConfirmation:
        // Booking and charging never happen straight off a transcript: read
        // the price back and wait for an explicit yes.
        _proposeAction(
          action,
          action.confirmationPrompt,
          displayText: action.confirmationDisplayText,
        );
      case _:
        _highlightAction(action);
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

  /// Reads [spokenPrompt] back and arms [action] so a following "yes" runs it.
  /// [displayText] is what appears in the chat bubble when it should differ
  /// from speech (readable times vs "5 oh 5").
  ///
  /// [fromProactive] marks silence-ladder confirmations so a later nudge can
  /// replace them; passenger-initiated ones stay locked until yes/no/expiry.
  void _proposeAction(
    VoiceAction action,
    String spokenPrompt, {
    String? displayText,
    bool fromProactive = false,
  }) {
    _pendingFromProactive = fromProactive;
    _highlightAction(action);
    state = state.copyWith(
      pendingConfirmation: action,
      pendingConfirmationExpiresAt: DateTime.now().add(_confirmationWindow),
    );
    _appendAssistantText(displayText ?? spokenPrompt, speakAs: spokenPrompt);

    _confirmationTimer?.cancel();
    _confirmationTimer = Timer(_confirmationWindow, () {
      if (!mounted) return;
      _clearPendingConfirmation();
    });
  }

  /// Mirrors a voice/text choice onto the card so the passenger sees which
  /// offer, seat, or bag option is armed or about to run.
  void _highlightAction(VoiceAction action) {
    state = switch (action) {
      SelectOfferAction(:final offer) => state.copyWith(
          highlightedOfferId: offer.id,
          clearHighlightedSeatNumber: true,
          clearHighlightedBaggageOptionId: true,
        ),
      SelectSeatAction(:final seat) => state.copyWith(
          highlightedSeatNumber: seat.seatNumber,
          clearHighlightedOfferId: true,
          clearHighlightedBaggageOptionId: true,
        ),
      SelectBaggageAction(:final option) => state.copyWith(
          highlightedBaggageOptionId: option.id,
          clearHighlightedOfferId: true,
          clearHighlightedSeatNumber: true,
        ),
      _ => state.copyWith(clearCardHighlights: true),
    };
  }

  void _clearPendingConfirmation({bool keepHighlights = false}) {
    _confirmationTimer?.cancel();
    _confirmationTimer = null;
    _pendingFromProactive = false;
    if (state.pendingConfirmation == null &&
        (keepHighlights ||
            (state.highlightedOfferId == null &&
                state.highlightedSeatNumber == null &&
                state.highlightedBaggageOptionId == null))) {
      return;
    }
    state = state.copyWith(
      clearPendingConfirmation: true,
      clearCardHighlights: !keepHighlights,
    );
  }

  // -------------------------------------------------------------------------
  // Voice output
  // -------------------------------------------------------------------------

  /// Keeps spoken output tied to app visibility. When the app leaves the
  /// foreground, any in-flight talkback is silenced and further utterances
  /// are dropped until the passenger is looking at the app again.
  Future<void> handleAppLifecycle(AppLifecycleState lifecycle) async {
    final inForeground = lifecycle == AppLifecycleState.resumed;
    if (_appInForeground == inForeground) {
      // Still push the gate onto the (app-scoped) narrator — a previous chat
      // visit may have left it blocked after a background.
      await _narrator.setSpeechAllowed(inForeground);
      return;
    }
    _appInForeground = inForeground;

    if (!inForeground) {
      _cancelProactivePrompt();
      _handoffPending = false;
      _cancelVoiceHandoff();
    }

    await _narrator.setSpeechAllowed(inForeground);

    if (!inForeground) {
      // stopAll emits speaking:false, which would otherwise re-arm the
      // proactive nudge timer while we are still in the background.
      _cancelProactivePrompt();
      _cancelVoiceHandoff();
      if (mounted && state.status == ChatStatus.listening) {
        await stopVoiceInput();
      }
    }
  }

  /// Called by the chat screen when the passenger moves between the voice orb
  /// and the typing composer. While they are typing, the assistant must not
  /// open the microphone on them, talkback or no talkback.
  void setHandsFreeEnabled(bool enabled) {
    _handsFreeEnabled = enabled;
    if (!enabled) {
      _handoffPending = false;
      _cancelVoiceHandoff();
    }
  }

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
    // Cutting the assistant off is a request for quiet, not an invitation to
    // start listening: the orb is right there when they want to talk.
    _handoffPending = false;
    _cancelVoiceHandoff();
    await _narrator.stopAll();
    if (mounted && state.isNarrating) {
      state = state.copyWith(status: ChatStatus.idle);
    }
  }

  void _onNarrationPhaseChanged(NarrationPhase phase) {
    if (!mounted) return;
    switch (phase) {
      // Only claimed from rest: a turn narrated while the passenger is
      // talking, or while an API call is still running, must not steal the
      // listening/working state out from under them.
      case NarrationPhase.preparing:
        if (state.status == ChatStatus.idle) {
          state = state.copyWith(status: ChatStatus.preparingSpeech);
        }
      case NarrationPhase.speaking:
        if (state.status == ChatStatus.idle ||
            state.status == ChatStatus.preparingSpeech) {
          state = state.copyWith(status: ChatStatus.speaking);
        }
      case NarrationPhase.idle:
        if (state.isNarrating) {
          state = state.copyWith(status: ChatStatus.idle);
        }
        _scheduleVoiceHandoff();
        _scheduleProactivePrompt();
    }
  }

  /// Returns to a resting status once a turn is done, staying with the
  /// narrator while it still has audio to word, fetch, or play.
  void _settleStatus() {
    if (!mounted) return;
    state = state.copyWith(status: _narratorStatus());
    // Covers the turn whose audio finished before the flow around it did —
    // the narrator's idle edge came while an API call was still running, so
    // the handoff was not eligible yet.
    _scheduleVoiceHandoff();
  }

  ChatStatus _narratorStatus() => switch (_narrator.phase) {
        NarrationPhase.speaking => ChatStatus.speaking,
        NarrationPhase.preparing => ChatStatus.preparingSpeech,
        NarrationPhase.idle =>
          _narrator.isBusy ? ChatStatus.preparingSpeech : ChatStatus.idle,
      };

  // -------------------------------------------------------------------------
  // Hands-free handoff
  // -------------------------------------------------------------------------

  /// Opens the microphone by itself a beat after the assistant stops talking,
  /// so replying takes nothing more than replying.
  ///
  /// Every spoken turn ends in a question, and making the passenger find and
  /// tap an orb to answer one is the difference between a conversation and a
  /// form. They keep the orb as an override — to interrupt, or to start a turn
  /// the assistant is not expecting.
  void _scheduleVoiceHandoff() {
    _cancelVoiceHandoff();
    if (!_canHandOffMic) return;
    _voiceHandoffTimer = Timer(_voiceHandoffDelay, () {
      _voiceHandoffTimer = null;
      // Re-checked on arrival: the passenger may have tapped the orb, started
      // typing, or asked for silence during the gap.
      if (!_canHandOffMic) return;
      unawaited(startVoiceInput(handsFree: true));
    });
  }

  void _cancelVoiceHandoff() {
    _voiceHandoffTimer?.cancel();
    _voiceHandoffTimer = null;
  }

  bool get _canHandOffMic =>
      mounted &&
      _handoffPending &&
      !_handoffUnavailable &&
      _handsFreeEnabled &&
      _appInForeground &&
      state.isVoiceOutputEnabled &&
      !state.isBusy &&
      state.status != ChatStatus.listening &&
      !_listenSessionOpen &&
      _narrator.phase == NarrationPhase.idle &&
      !_narrator.isBusy;

  // -------------------------------------------------------------------------
  // Proactive follow-ups
  // -------------------------------------------------------------------------

  /// Arms the next silence nudge. Only runs once the passenger has actually
  /// heard the whole turn, and only while the current choice still has
  /// follow-ups left.
  void _scheduleProactivePrompt() {
    _cancelProactivePrompt();
    if (!_appInForeground) return;
    if (!state.isVoiceOutputEnabled) return;
    if (state.voiceContext.kind == VoiceContextKind.none) return;
    if (!_hasMoreProactiveSteps()) return;

    // Passenger-initiated confirmations must not be overwritten by a nudge.
    // Silence-ladder confirmations may advance to the next step.
    if (state.pendingConfirmation != null && !_pendingFromProactive) return;

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
    if (state.pendingConfirmation != null && !_pendingFromProactive) return;

    if (state.pendingConfirmation != null && _pendingFromProactive) {
      _clearPendingConfirmation();
    }

    final step = state.proactivePromptStep;
    final nudge = ProactivePromptBuilder.build(state.voiceContext, step);
    if (nudge == null) return;

    state = state.copyWith(proactivePromptStep: step + 1);
    unawaited(_playCue(AudioCue.prompt));

    final target = nudge.suggestedAction;
    if (target != null) {
      _proposeAction(
        target,
        nudge.speechText,
        displayText: nudge.text,
        fromProactive: true,
      );
    } else {
      _appendAssistantText(nudge.text, speakAs: nudge.speechText);
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

  /// Appends an assistant text bubble. [speakAs] is what TTS reads when the
  /// spoken form should differ from the on-screen [text] (speech spelling).
  void _appendAssistantText(String text, {String? speakAs}) {
    _appendMessage(
      ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.assistant,
        type: ChatMessageType.text,
        timestamp: DateTime.now(),
        text: text,
      ),
      speakAs: speakAs,
    );
  }

  void _appendMessage(ChatMessage message, {bool narrate = true, String? speakAs}) {
    _cancelProactivePrompt();
    // The turn is still growing; whether it ends with an open microphone is
    // decided when the narrator finally falls quiet.
    _cancelVoiceHandoff();

    var stored = message;
    final draft =
        message.role == ChatRole.assistant ? VoiceSummaryBuilder.draft(message) : null;
    if (draft?.displayFallbackText != null) {
      stored = message.copyWith(text: draft!.displayFallbackText);
    }

    final context = _voiceContextFor(stored);
    final isNewChoice = context != null && context.kind != VoiceContextKind.none;
    state = state.copyWith(
      messages: [...state.messages, stored],
      voiceContext: context,
      proactivePromptStep: isNewChoice ? 0 : null,
    );
    unawaited(_saveChatMessageUseCase(stored));

    if (stored.role != ChatRole.assistant) return;

    unawaited(_playCue(_cueFor(stored.type)));

    if (!narrate || !state.isVoiceOutputEnabled) {
      if (draft != null) unawaited(_polishCaption(stored.id, draft));
      return;
    }

    // Nothing may be spoken into an open microphone. The handoff below is what
    // gives it back, once the passenger has actually heard this turn.
    _closeMicrophoneForSpeech();

    // This turn will be heard, so the passenger gets the microphone back once
    // it has been.
    _handoffPending = true;

    // Cards: speak via draft (LLM speech phrasing); caption via display text
    // (LLM chat caption). Plain text uses speakAs when speech spelling differs.
    if (draft != null) {
      _narrator.enqueueDraft(draft);
      unawaited(_polishCaption(stored.id, draft));
      return;
    }
    _narrator.enqueue(
      SpeechTextFormatter.clean(speakAs ?? stored.text),
    );
  }

  /// Replaces a card/text caption with an LLM-written readable version when
  /// the phrasing keeps the display facts intact.
  Future<void> _polishCaption(String messageId, SpokenDraft draft) async {
    if (draft.displayFallbackText == null) return;
    try {
      final caption = await _speechPhraser.phraseDisplay(draft);
      if (!mounted || caption.trim().isEmpty) return;
      if (caption == draft.displayFallbackText) return;

      final updated = [
        for (final message in state.messages)
          if (message.id == messageId) message.copyWith(text: caption) else message,
      ];
      state = state.copyWith(messages: updated);
      final polished = updated.where((message) => message.id == messageId).firstOrNull;
      if (polished != null) unawaited(_saveChatMessageUseCase(polished));
    } catch (_) {
      // Caption polish is best-effort; the display fallback already on screen
      // is correct and readable.
    }
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
    if (message.role != ChatRole.assistant || !message.isInteractive) return null;
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

  /// Whether the passenger may still act on [type]. If no such card exists
  /// yet (direct/test calls), allow; once every card of that type is locked,
  /// reject scrollback and voice retries.
  bool _canActOnCard(ChatMessageType type) {
    final cards = state.messages.where((message) => message.type == type);
    if (cards.isEmpty) return true;
    return cards.any((message) => message.isInteractive);
  }

  /// Marks matching cards non-interactive so scrollback cannot change a
  /// choice that has already been committed.
  void _lockCards(Set<ChatMessageType> types) {
    final changed = <ChatMessage>[];
    final updated = <ChatMessage>[
      for (final message in state.messages)
        if (types.contains(message.type) && message.isInteractive)
          message.copyWith(isInteractive: false)
        else
          message,
    ];
    for (var i = 0; i < updated.length; i++) {
      if (!identical(updated[i], state.messages[i])) {
        changed.add(updated[i]);
      }
    }
    if (changed.isEmpty) return;

    var next = state.copyWith(messages: updated);
    if (_locksCurrentVoiceContext(types)) {
      next = next.copyWith(voiceContext: const VoiceContext.none());
    }
    state = next;
    for (final message in changed) {
      unawaited(_saveChatMessageUseCase(message));
    }
  }

  bool _locksCurrentVoiceContext(Set<ChatMessageType> types) {
    return switch (state.voiceContext.kind) {
      VoiceContextKind.flightOffers => types.contains(ChatMessageType.flightOffersCard),
      VoiceContextKind.seatMap => types.contains(ChatMessageType.seatMapCard),
      VoiceContextKind.baggageOptions => types.contains(ChatMessageType.baggageOptionsCard),
      VoiceContextKind.none => false,
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
    if (cue == null || !state.isSoundEnabled || !_appInForeground) return;
    await _cues.play(cue);
  }

  /// Plays the mic-open cue to completion so it cannot overlap the
  /// recognizer's hold on the audio session.
  Future<void> _playListeningCue() async {
    if (!state.isSoundEnabled || !_appInForeground) return;
    await _cues.playAndAwait(AudioCue.listeningStart);
  }

  @override
  void dispose() {
    _cancelProactivePrompt();
    _cancelVoiceHandoff();
    _confirmationTimer?.cancel();
    _listenWatchdog?.cancel();
    _finalTranscriptTimer?.cancel();
    _endOfSpeechTimer?.cancel();
    _handoffPending = false;
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
    voiceActionParser: ref.watch(voiceActionParserProvider),
    speechPhraser: ref.watch(speechPhraserProvider),
  );
});
