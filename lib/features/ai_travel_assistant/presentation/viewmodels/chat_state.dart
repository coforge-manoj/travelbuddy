import 'package:equatable/equatable.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';

enum ChatStatus { idle, loadingHistory, sendingMessage, listening, error }

class ChatState extends Equatable {
  const ChatState({
    this.messages = const [],
    this.status = ChatStatus.idle,
    this.suggestedPrompts = const [
      'Flight Status',
      'Seat Selection',
      'Add Baggage',
      'Check-in Counter & Terminal',
      'Baggage Allowance',
      'Boarding Time',
      'Airport Navigation',
      'Travel Documents',
    ],
    this.errorMessage,
    this.isVoiceOutputEnabled = false,
    this.voiceDraft,
  });

  final List<ChatMessage> messages;
  final ChatStatus status;
  final List<String> suggestedPrompts;
  final String? errorMessage;
  final bool isVoiceOutputEnabled;

  /// Live speech-to-text transcript during dictation (voice mode 1). The
  /// composer mirrors this into its text field; null when not dictating.
  final String? voiceDraft;

  bool get isBusy =>
      status == ChatStatus.sendingMessage ||
      status == ChatStatus.loadingHistory;

  ChatState copyWith({
    List<ChatMessage>? messages,
    ChatStatus? status,
    List<String>? suggestedPrompts,
    String? errorMessage,
    bool clearError = false,
    bool? isVoiceOutputEnabled,
    String? voiceDraft,
    bool clearVoiceDraft = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      status: status ?? this.status,
      suggestedPrompts: suggestedPrompts ?? this.suggestedPrompts,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isVoiceOutputEnabled: isVoiceOutputEnabled ?? this.isVoiceOutputEnabled,
      voiceDraft: clearVoiceDraft ? null : (voiceDraft ?? this.voiceDraft),
    );
  }

  @override
  List<Object?> get props => [
        messages,
        status,
        suggestedPrompts,
        errorMessage,
        isVoiceOutputEnabled,
        voiceDraft,
      ];
}
