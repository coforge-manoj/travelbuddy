import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/services/llm/llm_service.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/change_seat_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/chat_history_usecases.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/purchase_baggage_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_viewmodel.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_service.dart';

import '../mocks/mocks.dart';

// Note on voice: ChatViewModel wraps every VoiceService call in a try/catch
// (`_speakSafely`) precisely so a real `VoiceService()` — whose
// speech_to_text/flutter_tts plugins have no platform channel in
// `flutter_test` — can be used here without any special faking. A
// MissingPluginException is swallowed the same way a real TTS-engine
// failure would be in production.

ChatMessage _assistantText(String text) => ChatMessage(
      id: 't',
      role: ChatRole.assistant,
      type: ChatMessageType.text,
      timestamp: DateTime(2026),
      text: text,
    );

ChatMessage _card(ChatMessageType type, Object payload) => ChatMessage(
      id: 'c',
      role: ChatRole.assistant,
      type: type,
      timestamp: DateTime(2026),
      payload: payload,
    );

void main() {
  late MockRunAssistantTurnUseCase runAssistantTurn;
  late MockSeatRepository seatRepository;
  late MockBaggageRepository baggageRepository;
  late MockChatHistoryRepository historyRepository;
  late ChatViewModel viewModel;

  setUpAll(() {
    // FlutterTts (constructed inside VoiceService) calls setMethodCallHandler,
    // which needs the test binding's binary messenger initialized first.
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(
      ChatMessage(
        id: 'fallback',
        role: ChatRole.user,
        type: ChatMessageType.text,
        timestamp: DateTime(2026),
      ),
    );
  });

  setUp(() {
    runAssistantTurn = MockRunAssistantTurnUseCase();
    seatRepository = MockSeatRepository();
    baggageRepository = MockBaggageRepository();
    historyRepository = MockChatHistoryRepository();

    when(() => historyRepository.loadHistory())
        .thenAnswer((_) async => const Result.success([]));
    when(() => historyRepository.saveMessage(any()))
        .thenAnswer((_) async => const Result.success(null));

    viewModel = ChatViewModel(
      runAssistantTurnUseCase: runAssistantTurn,
      changeSeatUseCase: ChangeSeatUseCase(seatRepository),
      purchaseBaggageUseCase: PurchaseBaggageUseCase(baggageRepository),
      loadChatHistoryUseCase: LoadChatHistoryUseCase(historyRepository),
      saveChatMessageUseCase: SaveChatMessageUseCase(historyRepository),
      clearChatHistoryUseCase: ClearChatHistoryUseCase(historyRepository),
      voiceService: VoiceService(),
    );
  });

  Future<void> pumpEventQueue() => Future<void>.delayed(Duration.zero);

  test('assistant reply (summary + card) is appended to the chat', () async {
    const option = BaggageOption(id: 'bag_10kg', extraWeightKg: 10, price: 45);
    when(() => runAssistantTurn.call(any())).thenAnswer(
      (_) async => [
        _assistantText('Here are your baggage options.'),
        _card(ChatMessageType.baggageOptionsCard, const [option]),
      ],
    );

    await viewModel.sendMessage('I need another 10kg of baggage');
    await pumpEventQueue();

    // User bubble + summary text + card.
    expect(viewModel.state.messages.length, greaterThanOrEqualTo(3));
    expect(
      viewModel.state.messages.last.type,
      ChatMessageType.baggageOptionsCard,
    );
    verify(() => runAssistantTurn.call('I need another 10kg of baggage'))
        .called(1);
  });

  test('an LlmException surfaces as an inline error message', () async {
    when(() => runAssistantTurn.call(any()))
        .thenThrow(LlmException('Gemini rejected the request.'));

    await viewModel.sendMessage('Is my flight delayed?');
    await pumpEventQueue();

    expect(viewModel.state.messages.last.type, ChatMessageType.error);
    expect(
      viewModel.state.messages.last.text,
      contains('Gemini rejected the request.'),
    );
  });

  test('a voice recording adds an audio bubble then the assistant reply',
      () async {
    when(() => runAssistantTurn.summarizeTranscript(any()))
        .thenAnswer((_) async => 'I want a window seat.');
    when(() => runAssistantTurn.call(any()))
        .thenAnswer((_) async => [_assistantText('A few window seats are open.')]);

    await viewModel.submitVoiceRecording(
      const AudioRecordingResult(
        audioPath: '/tmp/rec.m4a',
        transcript: 'uh window seat please',
        duration: Duration(seconds: 3),
      ),
    );
    await pumpEventQueue();

    final types = viewModel.state.messages.map((m) => m.type).toList();
    expect(types, contains(ChatMessageType.audioMessage));
    expect(viewModel.state.messages.last.type, ChatMessageType.text);
    expect(viewModel.state.messages.last.text, contains('window seats'));
    verify(() => runAssistantTurn.summarizeTranscript('uh window seat please'))
        .called(1);
    verify(() => runAssistantTurn.call('I want a window seat.')).called(1);
  });

  test('an empty-transcript recording surfaces an error, no LLM call', () async {
    await viewModel.submitVoiceRecording(
      const AudioRecordingResult(
        audioPath: '/tmp/rec.m4a',
        transcript: '   ',
        duration: Duration(seconds: 1),
      ),
    );
    await pumpEventQueue();

    expect(viewModel.state.messages.last.type, ChatMessageType.error);
    verifyNever(() => runAssistantTurn.summarizeTranscript(any()));
    verifyNever(() => runAssistantTurn.call(any()));
  });

  test('Android STT-only result (no audio path) still runs the assistant',
      () async {
    when(() => runAssistantTurn.summarizeTranscript(any()))
        .thenAnswer((_) async => 'Where is my gate?');
    when(() => runAssistantTurn.call(any()))
        .thenAnswer((_) async => [_assistantText('Gate A12.')]);

    await viewModel.submitVoiceRecording(
      const AudioRecordingResult(
        transcript: 'where is my gate',
        duration: Duration(seconds: 2),
      ),
    );
    await pumpEventQueue();

    final userTurns = viewModel.state.messages
        .where((m) => m.role == ChatRole.user)
        .toList();
    expect(userTurns, hasLength(1));
    expect(userTurns.single.text, 'where is my gate');
    expect(viewModel.state.messages.last.text, contains('Gate A12'));
    verify(() => runAssistantTurn.call('Where is my gate?')).called(1);
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

    expect(
      viewModel.state.messages.last.type,
      ChatMessageType.baggageSuccessCard,
    );
    expect(viewModel.state.messages.last.payload, purchase);
  });
}
