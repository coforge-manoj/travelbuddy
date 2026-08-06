import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/concierge_demo/domain/entities/proactive_scenario.dart';
import 'package:ai_travel_assistant/features/concierge_demo/presentation/viewmodels/scenario_chat_state.dart';

const _uuid = Uuid();

/// Drives one scripted Journey Concierge conversation: the passenger sends
/// (taps or types) the next line in [ProactiveScenario.turns], and this
/// walks the script forward one exchange at a time, appending the matching
/// concierge reply and — on the final turn — the scenario's concluding
/// [ChatMessageType.actionSummaryCard].
///
/// Every scenario in the playbook is a single linear path with no branching,
/// so [sendReply] advances the script on any non-empty reply rather than
/// gating on [ScenarioTurn.matchKeywords] — the point is that a paraphrase of
/// the scripted line always reaches the same resolution, never that it gets
/// stuck waiting for an exact match.
class ScenarioChatViewModel extends StateNotifier<ScenarioChatState> {
  ScenarioChatViewModel({required ProactiveScenario scenario})
      : _scenario = scenario,
        super(const ScenarioChatState());

  final ProactiveScenario _scenario;

  Future<void> sendReply(String text) async {
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

    if (state.isComplete) {
      _appendMessage(
        ChatMessage(
          id: _uuid.v4(),
          role: ChatRole.assistant,
          type: ChatMessageType.text,
          timestamp: DateTime.now(),
          text: "That's the end of this concierge preview — head back to explore another "
              'moment from the trip.',
        ),
      );
      return;
    }

    state = state.copyWith(status: ScenarioChatStatus.thinking);
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final turnIndex = state.currentTurnIndex;
    final turn = _scenario.turns[turnIndex];
    final isLastTurn = turnIndex == _scenario.turns.length - 1;

    _appendMessage(
      ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.assistant,
        type: ChatMessageType.text,
        timestamp: DateTime.now(),
        text: turn.conciergeReply,
      ),
    );

    if (isLastTurn) {
      _appendMessage(
        ChatMessage(
          id: _uuid.v4(),
          role: ChatRole.assistant,
          type: ChatMessageType.actionSummaryCard,
          timestamp: DateTime.now(),
          payload: _scenario.concludingAction,
        ),
      );
    }

    state = state.copyWith(
      status: ScenarioChatStatus.idle,
      currentTurnIndex: turnIndex + 1,
      isComplete: isLastTurn,
    );
  }

  void _appendMessage(ChatMessage message) {
    state = state.copyWith(messages: [...state.messages, message]);
  }
}

final scenarioChatViewModelProvider = StateNotifierProvider.autoDispose
    .family<ScenarioChatViewModel, ScenarioChatState, ProactiveScenario>(
  (ref, scenario) => ScenarioChatViewModel(scenario: scenario),
);
