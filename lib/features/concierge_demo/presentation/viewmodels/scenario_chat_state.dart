import 'package:equatable/equatable.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';

enum ScenarioChatStatus { idle, thinking }

class ScenarioChatState extends Equatable {
  const ScenarioChatState({
    this.messages = const [],
    this.currentTurnIndex = 0,
    this.status = ScenarioChatStatus.idle,
    this.isComplete = false,
  });

  final List<ChatMessage> messages;

  /// Index into [ProactiveScenario.turns] of the exchange the passenger is
  /// currently expected to reply to.
  final int currentTurnIndex;
  final ScenarioChatStatus status;
  final bool isComplete;

  bool get isBusy => status == ScenarioChatStatus.thinking;

  ScenarioChatState copyWith({
    List<ChatMessage>? messages,
    int? currentTurnIndex,
    ScenarioChatStatus? status,
    bool? isComplete,
  }) {
    return ScenarioChatState(
      messages: messages ?? this.messages,
      currentTurnIndex: currentTurnIndex ?? this.currentTurnIndex,
      status: status ?? this.status,
      isComplete: isComplete ?? this.isComplete,
    );
  }

  @override
  List<Object?> get props => [messages, currentTurnIndex, status, isComplete];
}
