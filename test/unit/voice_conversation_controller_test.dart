import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ai_travel_assistant/core/services/local_notification_service.dart';
import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
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
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/voice_conversation_controller.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/voice_conversation_state.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/acknowledgement_composer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_service.dart';

import '../mocks/mocks.dart';

/// A scriptable microphone.
///
/// Implements the narrow [ConversationVoicePort] rather than faking the whole
/// [VoiceService], so these tests exercise the loop and nothing else — no
/// synthesizers, no platform channels, no clock beyond the controller's own.
class _FakeVoicePort implements ConversationVoicePort {
  _FakeVoicePort({this.ready = true});

  bool ready;
  int startCount = 0;
  int stopCount = 0;
  int cancelCount = 0;
  bool _listening = false;

  void Function(String transcript, bool isFinal)? _onResult;
  void Function(String errorCode, bool permanent)? _onError;
  void Function(double level)? _onLevel;

  @override
  Future<bool> ensureReady() async => ready;

  @override
  bool get isListening => _listening;

  @override
  Future<bool> startListening({
    required void Function(String transcript, bool isFinal) onResult,
    void Function(String errorCode, bool permanent)? onError,
    void Function(String status)? onStatus,
    void Function(double level)? onLevel,
    String localeId = 'en_US',
  }) async {
    if (!ready) return false;
    startCount++;
    _listening = true;
    _onResult = onResult;
    _onError = onError;
    _onLevel = onLevel;
    return true;
  }

  /// Lets a test push microphone levels the way the recognizer would.
  void emitLevel(double level) => _onLevel?.call(level);

  @override
  Future<void> stopListening() async {
    stopCount++;
    _listening = false;
  }

  @override
  Future<void> cancelListening() async {
    cancelCount++;
    _listening = false;
  }

  /// Simulates the passenger speaking.
  void say(String transcript, {bool isFinal = true}) =>
      _onResult?.call(transcript, isFinal);

  void fail(String code, {bool permanent = false}) =>
      _onError?.call(code, permanent);
}

/// A [ChatViewModel] whose speech and network are under the test's control.
class _StubChat extends Mock implements ChatViewModel {}

Future<void> settle([Duration? extra]) async {
  await Future<void>.delayed(extra ?? const Duration(milliseconds: 1));
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
  late StreamController<SpeechActivity> activity;
  late _FakeVoicePort voice;

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

  /// A real ChatViewModel, but with a stubbed backend so no turn ever reaches
  /// the network. Speech is driven by [activity] instead of a synthesizer.
  ChatViewModel buildChat() {
    chatRepository = MockChatRepository();
    flightRepository = MockFlightRepository();
    seatRepository = MockSeatRepository();
    baggageRepository = MockBaggageRepository();
    airportRepository = MockAirportRepository();
    agentRepository = MockAgentRepository();
    historyRepository = MockChatHistoryRepository();

    when(() => historyRepository.clearHistory())
        .thenAnswer((_) async => const Result.success(null));
    when(() => historyRepository.saveMessage(any()))
        .thenAnswer((_) async => const Result.success(null));

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
      voiceService: VoiceService(),
      bookingSessionStore: BookingSessionStore(),
      notificationService: LocalNotificationService(),
      getReminderDelaySeconds: () => 5,
      getVoiceOutputEnabled: () => true,
      setPendingNextScenarioId: (_) {},
    );
  }

  /// Builds the controller against a stubbed chat, so the loop can be stepped
  /// without any turn actually going anywhere.
  ({VoiceConversationController controller, _StubChat chat}) buildLoop({
    bool ready = true,
    bool needsConfirmation = false,
  }) {
    activity = StreamController<SpeechActivity>.broadcast();
    voice = _FakeVoicePort(ready: ready);
    final chat = _StubChat();

    when(() => chat.speechActivity).thenAnswer((_) => activity.stream);
    when(() => chat.state).thenReturn(
      ChatState(
        isVoiceOutputEnabled: true,
        // `needsConfirmation` is derived from this being non-null.
        pendingConfirmationMessage:
            needsConfirmation ? 'cancel my booking' : null,
      ),
    );
    when(() => chat.lastSpokenLine).thenReturn('Your gate is B twelve.');
    when(
      () => chat.sendMessage(
        any(),
        acknowledgement: any(named: 'acknowledgement'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => chat.confirmPendingAction(
        acknowledgement: any(named: 'acknowledgement'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => chat.declinePendingAction(
        acknowledgement: any(named: 'acknowledgement'),
      ),
    ).thenReturn(null);
    when(() => chat.abortSpeechQueue()).thenReturn(null);
    when(() => chat.toggleVoiceOutput()).thenReturn(null);

    final controller = VoiceConversationController(
      voice: voice,
      chat: chat,
      reopenDelay: const Duration(milliseconds: 10),
      recoveryDelay: const Duration(milliseconds: 10),
      thinkingTimeout: const Duration(milliseconds: 60),
    );
    addTearDown(() {
      controller.dispose();
      activity.close();
    });
    return (controller: controller, chat: chat);
  }

  group('the happy loop', () {
    test('runs listen, capture, think, speak, listen without a tap', () async {
      final loop = buildLoop();
      final c = loop.controller;

      await c.start();
      expect(c.state.phase, VoicePhase.listening);
      expect(voice.startCount, 1);

      c.state; // partial transcript drives the live caption
      voice.say('check me in', isFinal: false);
      expect(c.state.phase, VoicePhase.capturing);
      expect(c.state.partialTranscript, 'check me in');

      voice.say('check me in');
      await settle();
      expect(c.state.phase, VoicePhase.thinking);
      verify(
        () => loop.chat.sendMessage(
          'check me in',
          acknowledgement: any(named: 'acknowledgement'),
        ),
      ).called(1);

      activity.add(SpeechActivity.playing);
      await settle();
      expect(c.state.phase, VoicePhase.speaking);

      activity.add(SpeechActivity.settled);
      await settle(const Duration(milliseconds: 30));

      // The whole point: the microphone reopened on its own.
      expect(c.state.phase, VoicePhase.listening);
      expect(voice.startCount, 2);
    });

    test('answers back before the answer exists', () async {
      final loop = buildLoop();
      final c = loop.controller;
      await c.start();

      voice.say('can you help me with my trip details');
      await settle();

      // Not "Thinking…" with a spinner: the passenger hears what was
      // understood while the backend is still working on it.
      final captured = verify(
        () => loop.chat.sendMessage(
          any(),
          acknowledgement: captureAny(named: 'acknowledgement'),
        ),
      ).captured.single as String?;

      expect(captured, contains('your trip details'));
      expect(c.state.acknowledgement, captured);
    });

    test('the line said up front does not hand the turn back', () async {
      final loop = buildLoop();
      final c = loop.controller;
      await c.start();
      voice.say('what is my gate');
      await settle();
      final startsBefore = voice.startCount;

      // The acknowledgement plays and finishes — but the answer has not
      // arrived. Reopening here would invite the passenger to speak and then
      // talk over them the moment the backend replied.
      activity.add(SpeechActivity.acknowledging);
      await settle(const Duration(milliseconds: 30));

      expect(c.state.phase, VoicePhase.acknowledging);
      expect(voice.startCount, startsBefore);

      // And the answer, when it comes, still drives the loop as before.
      activity.add(SpeechActivity.playing);
      await settle();
      expect(c.state.phase, VoicePhase.speaking);
      activity.add(SpeechActivity.settled);
      await settle(const Duration(milliseconds: 30));
      expect(voice.startCount, startsBefore + 1);
    });

    test('a turn that stalls after acknowledging still recovers', () async {
      final loop = buildLoop();
      final c = loop.controller;
      await c.start();
      voice.say('book me a flight to Delhi');
      await settle();

      // `playing` cancels the watchdog because the turn is over. This must
      // not: the backend has said nothing yet.
      activity.add(SpeechActivity.acknowledging);
      await settle(const Duration(milliseconds: 120));

      expect(c.state.phase, isNot(VoicePhase.acknowledging));
      expect(voice.startCount, greaterThan(1));
    });

    test('reopens once per turn, not once per message', () async {
      final loop = buildLoop();
      final c = loop.controller;
      await c.start();
      voice.say('show me my trips');
      await settle();

      // A turn emits a reply and several cards; ChatViewModel coalesces them
      // into one utterance, so only one settled arrives.
      activity.add(SpeechActivity.playing);
      activity.add(SpeechActivity.settled);
      await settle(const Duration(milliseconds: 30));

      expect(voice.startCount, 2);
    });
  });

  group('microphone level', () {
    test('reaches the orb without going through the state', () async {
      // Levels arrive at roughly 10-20Hz. Routed through VoiceConversationState
      // every one of them would rebuild the page and every card on it, so the
      // orb reads them off a notifier instead.
      final c = buildLoop().controller;
      await c.start();

      final before = c.state;
      voice.emitLevel(10);

      expect(c.micLevel.value, greaterThan(0));
      expect(c.state, same(before));
    });

    test('a louder voice moves it further', () async {
      final c = buildLoop().controller;
      await c.start();

      for (var i = 0; i < 20; i++) {
        voice.emitLevel(2);
      }
      final quiet = c.micLevel.value;

      for (var i = 0; i < 20; i++) {
        voice.emitLevel(10);
      }

      expect(c.micLevel.value, greaterThan(quiet));
    });

    test('drops to silence when the turn ends', () async {
      // Otherwise the orb sits inflated at the size of the passenger's last
      // word for the whole of the wait that follows.
      final c = buildLoop().controller;
      await c.start();
      for (var i = 0; i < 20; i++) {
        voice.emitLevel(10);
      }
      expect(c.micLevel.value, greaterThan(0));

      voice.say('check me in');
      await settle();

      expect(c.micLevel.value, 0);
    });

    test('drops to silence on an interruption', () async {
      final c = buildLoop().controller;
      await c.start();
      for (var i = 0; i < 20; i++) {
        voice.emitLevel(10);
      }

      await c.interrupt();

      expect(c.micLevel.value, 0);
    });

    test('a level from a closed session is ignored', () async {
      // The recognizer can call back after the session has concluded; acting on
      // it would revive the orb mid-answer.
      final c = buildLoop().controller;
      await c.start();
      voice.say('check me in');
      await settle();

      voice.emitLevel(10);

      expect(c.micLevel.value, 0);
    });
  });

  group('interrupting', () {
    test('discards the half-spoken sentence instead of sending it', () async {
      final loop = buildLoop();
      final c = loop.controller;
      await c.start();
      voice.say('actually never mi', isFinal: false);

      await c.interrupt();

      // cancelListening, not stopListening: stop finalizes, which would submit
      // the abandoned fragment as the passenger's next message.
      expect(voice.cancelCount, greaterThan(0));
      expect(voice.stopCount, 0);
      verifyNever(
        () => loop.chat.sendMessage(
          any(),
          acknowledgement: any(named: 'acknowledgement'),
        ),
      );
      expect(c.state.phase, VoicePhase.idle);
    });

    test('silences speech that is still being synthesized', () async {
      final loop = buildLoop();
      final c = loop.controller;
      await c.start();
      voice.say('what is my gate');
      await settle();

      await c.interrupt();

      verify(() => loop.chat.abortSpeechQueue()).called(1);
    });

    test('a late settled from the interrupted turn does not reopen the mic',
        () async {
      final loop = buildLoop();
      final c = loop.controller;
      await c.start();
      voice.say('what is my gate');
      await settle();
      final startsBefore = voice.startCount;

      await c.interrupt();
      // The turn was already in flight and still completes — it just must not
      // move a loop the passenger has left.
      activity.add(SpeechActivity.settled);
      await settle(const Duration(milliseconds: 30));

      expect(voice.startCount, startsBefore);
      expect(c.state.phase, VoicePhase.idle);
    });
  });

  group('confirmations', () {
    test('a spoken yes approves rather than starting a new turn', () async {
      final loop = buildLoop(needsConfirmation: true);
      final c = loop.controller;
      await c.start();

      voice.say('yes, go ahead');
      await settle();

      // Routed through sendMessage, "cancel my booking" answered with "yes"
      // comes back "Left it as it was" while the UI reports it cancelled.
      verify(
        () => loop.chat.confirmPendingAction(
          acknowledgement: any(named: 'acknowledgement'),
        ),
      ).called(1);
      verifyNever(
        () => loop.chat.sendMessage(
          any(),
          acknowledgement: any(named: 'acknowledgement'),
        ),
      );
    });

    test('a qualified yes is sent as a normal message', () async {
      final loop = buildLoop(needsConfirmation: true);
      final c = loop.controller;
      await c.start();

      voice.say('yes but make it the morning flight');
      await settle();

      verifyNever(
        () => loop.chat.confirmPendingAction(
          acknowledgement: any(named: 'acknowledgement'),
        ),
      );
      verify(
        () => loop.chat.sendMessage(
          'yes but make it the morning flight',
          acknowledgement: any(named: 'acknowledgement'),
        ),
      ).called(1);
    });

    test('a spoken no is answered out loud, not with silence', () async {
      // Audio mode has no confirmation bar to visibly disappear. Without a
      // spoken line a refusal is met with silence, which the passenger reads as
      // the microphone having missed them.
      final loop = buildLoop(needsConfirmation: true);
      final c = loop.controller;
      await c.start();

      voice.say('no, not now');
      await settle(const Duration(milliseconds: 30));

      verify(
        () => loop.chat.declinePendingAction(
          acknowledgement: any(named: 'acknowledgement', that: isNotEmpty),
        ),
      ).called(1);

      // The refusal is being spoken, so the microphone stays shut rather than
      // opening over the top of it — the loop is half-duplex.
      expect(voice.startCount, 1);

      activity.add(SpeechActivity.settled);
      await settle(const Duration(milliseconds: 30));
      expect(voice.startCount, 2);
    });

    test('answering a pending question with something else says so', () async {
      // The approval lapses either way — `sendMessage` clears it. On screen the
      // bar goes; spoken, it has to be stated, or the passenger's next "yes"
      // lands on nothing.
      final loop = buildLoop(needsConfirmation: true);
      final c = loop.controller;
      await c.start();

      voice.say('how much was that again');
      await settle();

      final spoken = verify(
        () => loop.chat.sendMessage(
          'how much was that again',
          acknowledgement: captureAny(named: 'acknowledgement'),
        ),
      ).captured.single as String?;

      expect(spoken, isNotNull);
      expect(
        AcknowledgementComposer.droppedNotes.any(spoken!.startsWith),
        isTrue,
        reason: 'should lead with the note that the approval lapsed, got '
            '"$spoken"',
      );
    });
  });

  group('tapping a suggestion', () {
    test('goes through the loop, not around it', () async {
      final loop = buildLoop();
      final c = loop.controller;
      await c.start();

      await c.say('Check me in');
      await settle();

      // Same path as speaking it: the microphone is closed first, and the turn
      // gets the acknowledgement and watchdog every other turn gets.
      expect(voice.cancelCount, greaterThan(0));
      expect(c.state.phase, VoicePhase.thinking);
      verify(
        () => loop.chat.sendMessage(
          'Check me in',
          acknowledgement: any(named: 'acknowledgement'),
        ),
      ).called(1);
    });

    test('a chip that approves a pending action confirms it', () async {
      // "Yes, cancel it" is a suggestion the backend sends on exactly the turn
      // where it is also an approval. Routed to sendMessage it would be
      // re-parsed as a fresh request and the cancellation would be lost.
      final loop = buildLoop(needsConfirmation: true);
      final c = loop.controller;
      await c.start();

      await c.say('Yes, cancel it');
      await settle();

      verify(
        () => loop.chat.confirmPendingAction(
          acknowledgement: any(named: 'acknowledgement'),
        ),
      ).called(1);
      verifyNever(
        () => loop.chat.sendMessage(
          any(),
          acknowledgement: any(named: 'acknowledgement'),
        ),
      );
    });

    test('an empty tap does nothing', () async {
      final loop = buildLoop();
      final c = loop.controller;
      await c.start();

      await c.say('   ');
      await settle();

      verifyNever(
        () => loop.chat.sendMessage(
          any(),
          acknowledgement: any(named: 'acknowledgement'),
        ),
      );
    });
  });

  group('when nothing is heard', () {
    test('asks again once, then stops rather than looping forever', () async {
      final loop = buildLoop();
      final c = loop.controller;
      await c.start();

      voice.fail('error_no_match');
      await settle(const Duration(milliseconds: 30));
      expect(c.state.phase, VoicePhase.listening);
      expect(voice.startCount, 2);

      voice.fail('error_no_match');
      await settle(const Duration(milliseconds: 30));

      // Someone who has put the phone down should not be asked every 2s.
      expect(c.state.phase, VoicePhase.idle);
      expect(c.state.message, contains('Tap when'));
      expect(voice.startCount, 2);
    });

    test('one silence produces one reopen, not two', () async {
      final loop = buildLoop();
      final c = loop.controller;
      await c.start();
      final startsBefore = voice.startCount;

      // Android reports a single silence twice: an empty final result *and*
      // error_no_match. Acting on both scheduled two reopens for one pause,
      // which on a real device looked like the microphone restarting over and
      // over without ever hearing the passenger out.
      voice.say('');
      voice.fail('error_no_match');
      await settle(const Duration(milliseconds: 40));

      expect(voice.startCount, startsBefore + 1);
      expect(c.state.consecutiveSilentTurns, 1);
    });

    test('a transcript arriving after the turn ended is ignored', () async {
      final loop = buildLoop();
      final c = loop.controller;
      await c.start();

      voice.say('check me in');
      // A late duplicate from the same listening session must not start a
      // second turn.
      voice.say('check me in');
      await settle();

      verify(
        () => loop.chat.sendMessage(
          'check me in',
          acknowledgement: any(named: 'acknowledgement'),
        ),
      ).called(1);
    });

    test('a recoverable fault retries', () async {
      final loop = buildLoop();
      final c = loop.controller;
      await c.start();

      voice.fail('error_audio');
      await settle(const Duration(milliseconds: 30));

      expect(voice.startCount, 2);
    });

    test('an echo of the assistant is dropped, not answered', () async {
      final loop = buildLoop();
      final c = loop.controller;
      await c.start();
      voice.say('what is my gate');
      await settle();

      activity.add(SpeechActivity.playing);
      await settle();
      activity.add(SpeechActivity.settled);
      await settle(const Duration(milliseconds: 30));

      // The speaker is still ringing as the mic reopens.
      voice.say('your gate is B twelve');
      await settle(const Duration(milliseconds: 30));

      // Answering it would put the assistant in conversation with itself.
      verifyNever(
        () => loop.chat.sendMessage(
          'your gate is B twelve',
          acknowledgement: any(named: 'acknowledgement'),
        ),
      );
    });
  });

  group('permissions and lifecycle', () {
    test('a refused microphone is terminal, and opens nothing', () async {
      final loop = buildLoop(ready: false);
      final c = loop.controller;

      await c.start();

      expect(c.state.phase, VoicePhase.permissionDenied);
      expect(voice.startCount, 0);
    });

    test('backgrounding interrupts, resuming restarts', () async {
      final loop = buildLoop();
      final c = loop.controller;
      await c.start();

      c.onAppLifecycle(AppLifecycleState.paused);
      await settle();
      expect(c.state.phase, VoicePhase.idle);

      c.onAppLifecycle(AppLifecycleState.resumed);
      await settle(const Duration(milliseconds: 30));
      expect(c.state.phase, VoicePhase.listening);
    });

    test('resuming does nothing if audio mode was not running', () async {
      final loop = buildLoop();
      final c = loop.controller;

      c.onAppLifecycle(AppLifecycleState.resumed);
      await settle();

      expect(c.state.phase, VoicePhase.idle);
      expect(voice.startCount, 0);
    });
  });

  group('watchdog', () {
    test('a turn that never speaks recovers instead of hanging', () async {
      final loop = buildLoop();
      final c = loop.controller;
      await c.start();

      voice.say('book me a flight');
      await settle();
      expect(c.state.phase, VoicePhase.thinking);

      // No playing, no settled, no error — a hung request.
      await settle(const Duration(milliseconds: 120));

      expect(c.state.phase, isNot(VoicePhase.thinking));
      expect(voice.startCount, 2);
    });
  });

  test('the real ChatViewModel exposes the stream the loop subscribes to', () {
    final chat = buildChat();
    addTearDown(chat.dispose);
    expect(chat.speechActivity, isA<Stream<SpeechActivity>>());
  });
}
