import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:ai_travel_assistant/core/di/providers.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/services/llm/llm_service.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/change_seat_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/chat_history_usecases.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/purchase_baggage_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/run_assistant_turn_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_state.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_service.dart';

const _uuid = Uuid();

/// Hard-codes the active booking context for the interactive follow-ups
/// (seat change, baggage purchase). The assistant turn itself gets its booking
/// context from [RunAssistantTurnUseCase]. Swap these for a real
/// `currentBookingProvider` at integration time.
const _demoFlightNumber = 'FZ123';
const _demoPnr = 'ABC123';

/// The chat screen's orchestrator. User text (typed, dictated, or from a
/// suggested prompt) is sent through [RunAssistantTurnUseCase], where Gemini
/// picks a tool, the matching use case runs, and the result comes back as a
/// summary bubble plus rich card message(s). Interactive card callbacks
/// (seat change, baggage purchase) and voice I/O are handled here directly.
class ChatViewModel extends StateNotifier<ChatState> {
  ChatViewModel({
    required RunAssistantTurnUseCase runAssistantTurnUseCase,
    required ChangeSeatUseCase changeSeatUseCase,
    required PurchaseBaggageUseCase purchaseBaggageUseCase,
    required LoadChatHistoryUseCase loadChatHistoryUseCase,
    required SaveChatMessageUseCase saveChatMessageUseCase,
    required ClearChatHistoryUseCase clearChatHistoryUseCase,
    required VoiceService voiceService,
  })  : _runAssistantTurnUseCase = runAssistantTurnUseCase,
        _changeSeatUseCase = changeSeatUseCase,
        _purchaseBaggageUseCase = purchaseBaggageUseCase,
        _loadChatHistoryUseCase = loadChatHistoryUseCase,
        _saveChatMessageUseCase = saveChatMessageUseCase,
        _clearChatHistoryUseCase = clearChatHistoryUseCase,
        _voiceService = voiceService,
        super(const ChatState()) {
    _loadHistory();
  }

  final RunAssistantTurnUseCase _runAssistantTurnUseCase;
  final ChangeSeatUseCase _changeSeatUseCase;
  final PurchaseBaggageUseCase _purchaseBaggageUseCase;
  final LoadChatHistoryUseCase _loadChatHistoryUseCase;
  final SaveChatMessageUseCase _saveChatMessageUseCase;
  final ClearChatHistoryUseCase _clearChatHistoryUseCase;
  final VoiceService _voiceService;

  Future<void> _loadHistory() async {
    state = state.copyWith(status: ChatStatus.loadingHistory);
    final result = await _loadChatHistoryUseCase();
    result.fold(
      (failure) => state =
          state.copyWith(status: ChatStatus.idle, messages: _welcomeMessages()),
      (history) => state = state.copyWith(
        status: ChatStatus.idle,
        messages: history.isEmpty ? _welcomeMessages() : history,
      ),
    );
  }

  List<ChatMessage> _welcomeMessages() {
    return [
      ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.assistant,
        type: ChatMessageType.text,
        timestamp: DateTime.now(),
        text: "Hi! I'm your travel assistant. Ask me about your flight, "
            'seat, baggage, or how to get to your gate.',
      ),
    ];
  }

  /// Clears the conversation and returns to the initial welcome state. The
  /// single welcome message keeps `messages.length <= 1`, so the suggested
  /// prompts reappear for the passenger to start fresh.
  Future<void> resetChat() async {
    if (state.status == ChatStatus.listening) {
      await stopVoiceInput();
    }
    unawaited(_voiceService.stopSpeaking());
    await _clearChatHistoryUseCase();
    state = state.copyWith(
      status: ChatStatus.idle,
      messages: _welcomeMessages(),
      clearError: true,
      clearVoiceDraft: true,
    );
  }

  /// Entry point for the composer, dictation, and suggested-prompt chips.
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
    // Clear any leftover dictation draft now that it's been sent.
    state = state.copyWith(
      status: ChatStatus.sendingMessage,
      clearError: true,
      clearVoiceDraft: true,
    );

    try {
      final replies = await _runAssistantTurnUseCase(trimmed);
      for (final message in replies) {
        _appendMessage(message);
      }
    } on LlmException catch (e) {
      _appendError(e.message);
    } catch (e) {
      _appendError('Something went wrong: $e');
    }

    state = state.copyWith(status: ChatStatus.idle);
  }

  /// Called by the seat-selection card once the passenger taps a seat.
  Future<void> confirmSeatChange(String seatNumber) async {
    state = state.copyWith(status: ChatStatus.sendingMessage);
    final result = await _changeSeatUseCase(
      pnr: _demoPnr,
      flightNumber: _demoFlightNumber,
      seatNumber: seatNumber,
    );
    result.fold(
      (failure) => _appendError(failure.message),
      (seat) => _appendMessage(
        ChatMessage(
          id: _uuid.v4(),
          role: ChatRole.assistant,
          type: ChatMessageType.text,
          timestamp: DateTime.now(),
          text: 'You are all set in seat ${seat.seatNumber}. ✅',
        ),
      ),
    );
    state = state.copyWith(status: ChatStatus.idle);
  }

  /// Called by the baggage card once the passenger picks an option.
  Future<void> confirmBaggagePurchase(String optionId) async {
    state = state.copyWith(status: ChatStatus.sendingMessage);
    final result =
        await _purchaseBaggageUseCase(pnr: _demoPnr, optionId: optionId);
    result.fold(
      (failure) => _appendError(failure.message),
      (purchase) => _appendMessage(
        ChatMessage(
          id: _uuid.v4(),
          role: ChatRole.assistant,
          type: ChatMessageType.baggageSuccessCard,
          timestamp: DateTime.now(),
          text: 'Your extra baggage is confirmed.',
          payload: purchase,
        ),
      ),
    );
    state = state.copyWith(status: ChatStatus.idle);
  }

  /// Voice mode 2 — voice conversation. Takes a finished recording, shows a
  /// replayable audio bubble (or the transcript as text when no file was
  /// captured — Android), summarizes the transcript, runs the same assistant
  /// loop, and (via [_appendMessage]) speaks the reply aloud.
  Future<void> submitVoiceRecording(AudioRecordingResult recording) async {
    if (state.isBusy) return;

    final transcript = recording.transcript.trim();
    final audioPath = recording.audioPath;
    final hasAudio = audioPath != null && audioPath.isNotEmpty;

    if (hasAudio) {
      _appendMessage(
        ChatMessage(
          id: _uuid.v4(),
          role: ChatRole.user,
          type: ChatMessageType.audioMessage,
          timestamp: DateTime.now(),
          audioPath: audioPath,
          audioDuration: recording.duration,
        ),
      );
    } else if (transcript.isNotEmpty) {
      // Android STT-only path: no replayable file, but the words still belong
      // in the thread so the passenger can see what was heard.
      _appendMessage(
        ChatMessage(
          id: _uuid.v4(),
          role: ChatRole.user,
          type: ChatMessageType.text,
          text: transcript,
          timestamp: DateTime.now(),
        ),
      );
    }

    state = state.copyWith(status: ChatStatus.sendingMessage, clearError: true);

    if (transcript.isEmpty) {
      _appendError(
        "I couldn't make out any speech in that recording. Please try again.",
      );
      state = state.copyWith(status: ChatStatus.idle);
      return;
    }

    try {
      final prompt =
          await _runAssistantTurnUseCase.summarizeTranscript(transcript);
      final replies = await _runAssistantTurnUseCase(prompt);
      for (final message in replies) {
        _appendMessage(message);
      }
    } on LlmException catch (e) {
      _appendError(e.message);
    } catch (e) {
      _appendError('Something went wrong: $e');
    }

    state = state.copyWith(status: ChatStatus.idle);
  }

  /// Voice mode 1 — dictation. Starts listening and streams the transcript
  /// into [ChatState.voiceDraft] so the composer fills its text field. Nothing
  /// is sent automatically: the passenger edits and taps send.
  Future<void> startVoiceInput() async {
    if (state.isBusy || state.status == ChatStatus.listening) return;
    final started = await _voiceService.startListening(
      onResult: (transcript, isFinal) {
        state = state.copyWith(voiceDraft: transcript);
        if (isFinal) {
          // Recognizer stops on a final result; drop the listening indicator
          // but keep the dictated text in the composer for editing.
          state = state.copyWith(status: ChatStatus.idle);
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

final chatViewModelProvider =
    StateNotifierProvider<ChatViewModel, ChatState>((ref) {
  return ChatViewModel(
    runAssistantTurnUseCase: ref.watch(runAssistantTurnUseCaseProvider),
    changeSeatUseCase: ref.watch(changeSeatUseCaseProvider),
    purchaseBaggageUseCase: ref.watch(purchaseBaggageUseCaseProvider),
    loadChatHistoryUseCase: ref.watch(loadChatHistoryUseCaseProvider),
    saveChatMessageUseCase: ref.watch(saveChatMessageUseCaseProvider),
    clearChatHistoryUseCase: ref.watch(clearChatHistoryUseCaseProvider),
    voiceService: ref.watch(voiceServiceProvider),
  );
});
