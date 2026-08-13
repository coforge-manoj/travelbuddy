import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ai_travel_assistant/core/errors/failures.dart';
import 'package:ai_travel_assistant/core/services/local_notification_service.dart';
import 'package:ai_travel_assistant/core/utils/result.dart';
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
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/booking_session_store.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_state.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_viewmodel.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/speech_synthesizer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_service.dart';

import '../mocks/mocks.dart';

/// Stands in for the whole TTS stack.
///
/// Subclasses the real service rather than reimplementing it so the test binds
/// to the surface `ChatViewModel` actually calls. Playback can be held open via
/// [gate], which is what lets a test assert that nothing settles — and so that
/// the microphone would not reopen — while audio is still running.
class _FakeVoiceService extends VoiceService {
  _FakeVoiceService({this.neuralEngine = false});

  /// Stands for an engine that synthesizes over the network before playing —
  /// the only kind chunking helps.
  final bool neuralEngine;
  final List<String> prepared = [];
  final List<String> played = [];
  int stopCount = 0;

  /// Whether the summarizer was asked for on each prepared line. Factual card
  /// narration must bypass it, so a PNR or fare can never be reworded.
  final List<bool> summarizeFlags = [];

  /// When set, [playSpeech] blocks on it, simulating audio still playing.
  Completer<void>? gate;

  @override
  bool get rendersAheadOfPlayback => neuralEngine;

  @override
  Future<PreparedSpeech?> prepareSpeech(
    String text, {
    bool summarize = true,
  }) async {
    prepared.add(text);
    return PreparedSpeech(spokenText: text, audioBytes: Uint8List(0));
  }

  @override
  Future<void> playSpeech(PreparedSpeech speech) async {
    played.add(speech.spokenText);
    final gate = this.gate;
    if (gate != null) await gate.future;
  }

  @override
  Future<void> stopSpeaking() async => stopCount++;

  @override
  Future<String> resolveSpokenText(String text, {bool summarize = true}) async {
    summarizeFlags.add(summarize);
    return text;
  }

  @override
  void dispose() {}
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
  late _FakeVoiceService voice;

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

  ChatViewModel buildViewModel({
    bool voiceOutputEnabled = true,
    bool neuralEngine = true,
  }) {
    chatRepository = MockChatRepository();
    flightRepository = MockFlightRepository();
    seatRepository = MockSeatRepository();
    baggageRepository = MockBaggageRepository();
    airportRepository = MockAirportRepository();
    agentRepository = MockAgentRepository();
    historyRepository = MockChatHistoryRepository();
    voice = _FakeVoiceService(neuralEngine: neuralEngine);

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
      voiceService: voice,
      bookingSessionStore: BookingSessionStore(),
      notificationService: LocalNotificationService(),
      getReminderDelaySeconds: () => 5,
      getVoiceOutputEnabled: () => voiceOutputEnabled,
      setPendingNextScenarioId: (_) {},
    );
  }

  ChatMessage text(String body) => ChatMessage(
        id: body,
        role: ChatRole.assistant,
        type: ChatMessageType.text,
        timestamp: DateTime(2026),
        text: body,
      );

  ChatMessage card(ChatMessageType type, {required String caption}) =>
      ChatMessage(
        id: '$type-$caption',
        role: ChatRole.assistant,
        type: type,
        timestamp: DateTime(2026),
        text: caption,
        payload: const <String>[],
      );

  group('burst coalescing', () {
    test('a reply plus its cards is spoken once, not once per message', () async {
      final viewModel = buildViewModel();
      addTearDown(viewModel.dispose);
      await pumpEventQueue();

      // What one /chat turn emits: a text bubble followed by every card it
      // came back with, appended synchronously with no await between them.
      viewModel.debugAppendMessages([
        text('Here are a few options.'),
        card(ChatMessageType.flightOffersCard, caption: 'Flight options'),
        card(ChatMessageType.basketCard, caption: 'Your basket'),
      ]);
      await pumpEventQueue();

      expect(voice.prepared, hasLength(1));
      expect(voice.played, hasLength(1));
      expect(voice.prepared.single, contains('Here are a few options.'));
      expect(voice.prepared.single, contains('Flight options'));
      expect(voice.prepared.single, contains('Your basket'));
    });

    test("a card's narration replaces the backend's summary of the same turn",
        () async {
      final viewModel = buildViewModel();
      addTearDown(viewModel.dispose);
      await pumpEventQueue();

      // A live turn: the bubble carries the backend's own one-line summary, and
      // the card narrates the same answer from its payload. Both were spoken,
      // so the passenger heard the flight count twice — and the two word it
      // differently, so no string de-duplication removes it.
      viewModel.debugAppendMessages([
        text('105 flights. Most recent was AA993 DFW→LHR in Flagship Business.'),
        ChatMessage(
          id: 'card',
          role: ChatRole.assistant,
          type: ChatMessageType.travelHistoryCard,
          timestamp: DateTime(2026),
          text: '105 flights. Most recent was AA993 DFW→LHR in Flagship Business.',
          spokenText: '105 flights all time, 193325 dollars in total. '
              'Most recently flight A A 993, D F W to L H R.',
        ),
      ]);
      await pumpEventQueue();

      // Joined rather than `.single`: a line this long is split into chunks for
      // the network engine, which is orthogonal to what this asserts.
      final spoken = voice.prepared.join(' ');
      expect('105 flights'.allMatches(spoken).length, 1, reason: spoken);
      // The card's version is kept, because it is the one written for the ear:
      // the reply would have an engine read "AA993 DFW→LHR" as a word.
      expect(spoken, contains('A A 993'));
      expect(spoken, contains('193325 dollars'));
      expect(spoken, isNot(contains('DFW→LHR')));
    });

    test('a reply with no card of its own is still spoken', () async {
      final viewModel = buildViewModel();
      addTearDown(viewModel.dispose);
      await pumpEventQueue();

      viewModel.debugAppendMessages([
        text('I need an origin, a destination and a date.'),
      ]);
      await pumpEventQueue();

      expect(
        voice.prepared.single,
        'I need an origin, a destination and a date.',
      );
    });

    test('several cards in one turn each keep their own detail', () async {
      final viewModel = buildViewModel();
      addTearDown(viewModel.dispose);
      await pumpEventQueue();

      viewModel.debugAppendMessages([
        text('Here it is.'),
        ChatMessage(
          id: 'card1',
          role: ChatRole.assistant,
          type: ChatMessageType.travelHistoryCard,
          timestamp: DateTime(2026),
          text: 'Here it is.',
          spokenText: '105 flights all time.',
        ),
        ChatMessage(
          id: 'card2',
          role: ChatRole.assistant,
          type: ChatMessageType.basketCard,
          timestamp: DateTime(2026),
          text: 'Here it is.',
          spokenText: 'Total 240 dollars.',
        ),
      ]);
      await pumpEventQueue();

      final spoken = voice.prepared.single;
      expect(spoken, contains('105 flights all time'));
      expect(spoken, contains('Total 240 dollars'));
      expect(spoken, isNot(contains('Here it is')));
    });

    test('replies separated by real work are spoken as separate turns', () async {
      final viewModel = buildViewModel();
      addTearDown(viewModel.dispose);
      await pumpEventQueue();

      viewModel.debugAppendMessages([text('Looking that up.')]);
      await pumpEventQueue();
      viewModel.debugAppendMessages([text('Your gate is B twelve.')]);
      await pumpEventQueue();

      expect(voice.prepared, ['Looking that up.', 'Your gate is B twelve.']);
    });

    test('nothing is spoken when voice output is off', () async {
      final viewModel = buildViewModel(voiceOutputEnabled: false);
      addTearDown(viewModel.dispose);
      await pumpEventQueue();

      viewModel.debugAppendMessages([text('Here are a few options.')]);
      await pumpEventQueue();

      expect(voice.prepared, isEmpty);
    });

    test('cards are narrated on the device engine too', () async {
      final viewModel = buildViewModel(neuralEngine: false);
      addTearDown(viewModel.dispose);
      await pumpEventQueue();

      viewModel.debugAppendMessages([
        card(ChatMessageType.flightOffersCard, caption: 'Flight options'),
      ]);
      await pumpEventQueue();

      // Card narration was once gated on the neural engine, from a design where
      // a card's bubble was held back until its audio existed. Messages are no
      // longer held back, and the device voice is now the default — so that gate
      // would silence every booking, boarding pass and travel history, which is
      // the entire point of asking about a journey out loud.
      expect(voice.prepared, hasLength(1));
      expect(voice.prepared.single, contains('Flight options'));
    });

    test('the device engine speaks a long line whole, without seams', () async {
      final viewModel = buildViewModel(neuralEngine: false);
      addTearDown(viewModel.dispose);
      await pumpEventQueue();

      viewModel.debugAppendMessages([
        text(
          '105 flights all time, 193325 dollars in total. Most recently flight '
          'A A 993 on 2026-07-21, D F W to L H R in Flagship Business.',
        ),
      ]);
      await pumpEventQueue();
      await pumpEventQueue();

      // Chunking overlaps a network render with playback. The device engine has
      // no render step, so splitting there would only add seams for nothing.
      expect(voice.prepared, hasLength(1));
    });

    test('a message carrying spokenText speaks that, not its on-screen text', () async {
      final viewModel = buildViewModel();
      addTearDown(viewModel.dispose);
      await pumpEventQueue();

      viewModel.debugAppendMessages([
        ChatMessage(
          id: 'x',
          role: ChatRole.assistant,
          type: ChatMessageType.text,
          timestamp: DateTime(2026),
          text: '**Gate B12** · Terminal 2',
          spokenText: 'Gate B twelve, terminal two.',
        ),
      ]);
      await pumpEventQueue();

      expect(voice.prepared.single, 'Gate B twelve, terminal two.');
    });

    test('a plain reply is sent to the summarizer for rewording', () async {
      final viewModel = buildViewModel();
      addTearDown(viewModel.dispose);
      await pumpEventQueue();

      viewModel.debugAppendMessages([text('Sure, let me look that up.')]);
      await pumpEventQueue();

      expect(voice.summarizeFlags.single, isTrue);
    });

    test('a burst carrying card facts bypasses the summarizer entirely', () async {
      final viewModel = buildViewModel();
      addTearDown(viewModel.dispose);
      await pumpEventQueue();

      viewModel.debugAppendMessages([
        ChatMessage(
          id: 'pass',
          role: ChatRole.assistant,
          type: ChatMessageType.text,
          timestamp: DateTime(2026),
          text: 'Checked in.',
          spokenText: 'Checked in. Gate 25, seat 12 A.',
        ),
      ]);
      await pumpEventQueue();

      // The summarizer is an LLM. It may reword prose, but a gate or seat it
      // rewrites is a wrong answer delivered confidently, so factual lines go
      // to the engine exactly as this code built them.
      expect(voice.summarizeFlags.single, isFalse);
    });
  });

  group('speechActivity', () {
    test('emits preparing then playing then settled, once per turn', () async {
      final viewModel = buildViewModel();
      addTearDown(viewModel.dispose);
      await pumpEventQueue();

      final seen = <SpeechActivity>[];
      final sub = viewModel.speechActivity.listen(seen.add);
      addTearDown(sub.cancel);

      viewModel.debugAppendMessages([
        text('Here are a few options.'),
        card(ChatMessageType.flightOffersCard, caption: 'Flight options'),
      ]);
      await pumpEventQueue();
      await pumpEventQueue();

      expect(seen, [
        SpeechActivity.preparing,
        SpeechActivity.playing,
        SpeechActivity.settled,
      ]);
    });

    test('does not settle while audio is still playing', () async {
      final viewModel = buildViewModel();
      addTearDown(viewModel.dispose);
      await pumpEventQueue();

      voice.gate = Completer<void>();

      final seen = <SpeechActivity>[];
      final sub = viewModel.speechActivity.listen(seen.add);
      addTearDown(sub.cancel);

      viewModel.debugAppendMessages([text('Your gate is B twelve.')]);
      await pumpEventQueue();
      await pumpEventQueue();

      // This is the property the hands-free loop rests on: the microphone must
      // not reopen mid-sentence.
      expect(seen, isNot(contains(SpeechActivity.settled)));
      expect(seen.last, SpeechActivity.playing);

      voice.gate!.complete();
      await pumpEventQueue();

      expect(seen.last, SpeechActivity.settled);
    });
  });

  group('the line said before the answer', () {
    /// A turn that reaches the backend and comes back with nothing to say.
    ///
    /// The interesting case rather than the convenient one: with no answer to
    /// speak, the acknowledgement is the *only* utterance of the turn, so
    /// anything wrong with its bookkeeping shows up here instead of being
    /// covered by the answer that follows it.
    void stubFailingTurn() {
      when(() => chatRepository.classifyIntent(any())).thenAnswer(
        (_) async => const Result.failure(NetworkFailure('offline')),
      );
    }

    test('is spoken, but never written into the transcript', () async {
      final viewModel = buildViewModel();
      addTearDown(viewModel.dispose);
      await pumpEventQueue();
      stubFailingTurn();

      await viewModel.sendMessage(
        'what is my gate',
        acknowledgement: 'Sure, you want to know about your gate. One moment.',
      );
      await pumpEventQueue();

      expect(voice.played.first, startsWith('Sure, you want to know'));
      // Read back later, a bubble for this would be a promise with no answer
      // attached to it.
      expect(
        viewModel.state.messages.map((m) => m.text),
        isNot(contains(contains('you want to know about your gate'))),
      );
    });

    test('is never handed to the summarizer', () async {
      final viewModel = buildViewModel();
      addTearDown(viewModel.dispose);
      await pumpEventQueue();
      stubFailingTurn();

      await viewModel.sendMessage(
        'what is my gate',
        acknowledgement: 'Sure. One moment.',
      );
      await pumpEventQueue();

      // The summarizer's round trip is longer than the wait this is filling —
      // paying for it would make the line arrive after the answer it precedes.
      expect(voice.summarizeFlags.first, isFalse);
    });

    test('does not settle the turn it is spoken during', () async {
      final viewModel = buildViewModel();
      addTearDown(viewModel.dispose);
      await pumpEventQueue();
      stubFailingTurn();

      final seen = <SpeechActivity>[];
      final sub = viewModel.speechActivity.listen(seen.add);
      addTearDown(sub.cancel);

      // A backend that has not answered yet — the situation this whole feature
      // exists for, and the only one where the bug it guards against appears.
      final backend = Completer<Result<IntentResult>>();
      when(() => chatRepository.classifyIntent(any()))
          .thenAnswer((_) => backend.future);

      final turn = viewModel.sendMessage(
        'what is my gate',
        acknowledgement: 'Sure. One moment.',
      );
      await pumpEventQueue();
      await pumpEventQueue();

      // The acknowledgement has finished playing and the queue is empty — which
      // on its own looks exactly like the turn having finished speaking. If it
      // settled here the loop would reopen the microphone, invite the passenger
      // to speak, and then talk over them when the answer arrived.
      expect(seen, contains(SpeechActivity.acknowledging));
      expect(seen, isNot(contains(SpeechActivity.settled)));

      backend.complete(const Result.failure(NetworkFailure('offline')));
      await turn;
      await pumpEventQueue();

      // And the turn ending is what releases it, even though this one never
      // found anything to say.
      expect(seen.last, SpeechActivity.settled);
    });
  });

  group('chunked playback', () {
    // The opening sentence is synthesized and played on its own so the
    // passenger hears something in ~0.7s instead of ~2.2s; the remainder
    // renders while it plays.
    const longNarration =
        '105 flights all time, 193325 dollars in total. Most recently flight '
        'A A 993 on 2026-07-21, D F W to L H R in Flagship Business.';

    test('a long line is synthesized in two pieces, first sentence first',
        () async {
      final viewModel = buildViewModel(neuralEngine: true);
      addTearDown(viewModel.dispose);
      await pumpEventQueue();

      viewModel.debugAppendMessages([text(longNarration)]);
      await pumpEventQueue();
      await pumpEventQueue();

      expect(voice.prepared, hasLength(2));
      expect(voice.prepared.first, endsWith('in total.'));
      expect(voice.played, hasLength(2));
    });

    test('the turn still settles exactly once', () async {
      final viewModel = buildViewModel(neuralEngine: true);
      addTearDown(viewModel.dispose);
      await pumpEventQueue();

      final seen = <SpeechActivity>[];
      final sub = viewModel.speechActivity.listen(seen.add);
      addTearDown(sub.cancel);

      viewModel.debugAppendMessages([text(longNarration)]);
      await pumpEventQueue();
      await pumpEventQueue();
      await pumpEventQueue();

      // This is what the hands-free loop rests on. Two chunks must not mean two
      // settles, or the microphone would reopen between the halves of one
      // sentence pair.
      expect(
        seen.where((a) => a == SpeechActivity.settled),
        hasLength(1),
      );
      expect(
        seen.where((a) => a == SpeechActivity.playing),
        hasLength(1),
      );
      expect(seen.last, SpeechActivity.settled);
    });

    test('the whole line is summarized once, not once per chunk', () async {
      final viewModel = buildViewModel(neuralEngine: true);
      addTearDown(viewModel.dispose);
      await pumpEventQueue();

      viewModel.debugAppendMessages([text(longNarration)]);
      await pumpEventQueue();
      await pumpEventQueue();

      // Summarizing each chunk separately would pay two LLM round trips and
      // could word the halves inconsistently, since neither call sees the other.
      expect(voice.summarizeFlags, hasLength(1));
    });

    test('interrupting between chunks stops the second one playing', () async {
      final viewModel = buildViewModel(neuralEngine: true);
      addTearDown(viewModel.dispose);
      await pumpEventQueue();

      voice.gate = Completer<void>();
      viewModel.debugAppendMessages([text(longNarration)]);
      await pumpEventQueue();
      await pumpEventQueue();

      // First chunk is playing and held open.
      expect(voice.played, hasLength(1));

      viewModel.abortSpeechQueue();
      voice.gate!.complete();
      await pumpEventQueue();
      await pumpEventQueue();

      expect(voice.played, hasLength(1));
    });
  });

  group('abortSpeechQueue', () {
    test('stops audio and settles immediately', () async {
      final viewModel = buildViewModel();
      addTearDown(viewModel.dispose);
      await pumpEventQueue();

      voice.gate = Completer<void>();

      final seen = <SpeechActivity>[];
      final sub = viewModel.speechActivity.listen(seen.add);
      addTearDown(sub.cancel);

      viewModel.debugAppendMessages([text('Your gate is B twelve.')]);
      await pumpEventQueue();
      await pumpEventQueue();

      viewModel.abortSpeechQueue();
      await pumpEventQueue();

      expect(voice.stopCount, greaterThan(0));
      expect(seen.last, SpeechActivity.settled);

      voice.gate!.complete();
    });

    test('an utterance still being synthesized never reaches playback', () async {
      final viewModel = buildViewModel();
      addTearDown(viewModel.dispose);
      await pumpEventQueue();

      viewModel.debugAppendMessages([text('A long answer about your booking.')]);
      // Interrupt in the same microtask window the flush was scheduled in, so
      // the abort lands while preparation is still in flight. stopSpeaking()
      // alone could not catch this — there is no audio to stop yet, and the
      // clip would start playing seconds after the passenger interrupted.
      viewModel.abortSpeechQueue();
      await pumpEventQueue();
      await pumpEventQueue();

      expect(voice.played, isEmpty);
    });
  });
}
