import 'package:equatable/equatable.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';

import '../../data/models/chat_context_model.dart';

enum ChatStatus { idle, loadingHistory, sendingMessage, listening, error }

class ChatState extends Equatable {
  const ChatState({
    this.messages = const [],
    this.status = ChatStatus.idle,
    this.errorMessage,
    this.isVoiceOutputEnabled = true,
    this.context = const ChatContext(),
  });

  final List<ChatMessage> messages;
  final ChatStatus status;
  final String? errorMessage;
  final bool isVoiceOutputEnabled;
  final ChatContext context;

  bool get isBusy => status == ChatStatus.sendingMessage || status == ChatStatus.loadingHistory;

  ChatState copyWith({
    List<ChatMessage>? messages,
    ChatStatus? status,
    String? errorMessage,
    bool clearError = false,
    bool? isVoiceOutputEnabled,
    ChatContext? context,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      status: status ?? this.status,
      errorMessage:
      clearError ? null : (errorMessage ?? this.errorMessage),
      isVoiceOutputEnabled:
      isVoiceOutputEnabled ?? this.isVoiceOutputEnabled,
      context: context ?? this.context,
    );
  }

  @override
  List<Object?> get props => [
    messages,
    status,
    errorMessage,
    isVoiceOutputEnabled,
    context,
  ];
}
