import 'package:equatable/equatable.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';

enum ChatStatus { idle, loadingHistory, sendingMessage, listening, error }

class ChatState extends Equatable {
  const ChatState({
    this.messages = const [],
    this.status = ChatStatus.idle,
    this.suggestedPrompts = const [
      'Is my flight delayed?',
      'I want a window seat',
      'I need another 10kg of baggage',
      'Which terminal do I go to?',
    ],
    this.errorMessage,
    this.isVoiceOutputEnabled = true,
  });

  final List<ChatMessage> messages;
  final ChatStatus status;
  final List<String> suggestedPrompts;
  final String? errorMessage;
  final bool isVoiceOutputEnabled;

  bool get isBusy => status == ChatStatus.sendingMessage || status == ChatStatus.loadingHistory;

  ChatState copyWith({
    List<ChatMessage>? messages,
    ChatStatus? status,
    List<String>? suggestedPrompts,
    String? errorMessage,
    bool clearError = false,
    bool? isVoiceOutputEnabled,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      status: status ?? this.status,
      suggestedPrompts: suggestedPrompts ?? this.suggestedPrompts,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isVoiceOutputEnabled: isVoiceOutputEnabled ?? this.isVoiceOutputEnabled,
    );
  }

  @override
  List<Object?> get props =>
      [messages, status, suggestedPrompts, errorMessage, isVoiceOutputEnabled];
}
