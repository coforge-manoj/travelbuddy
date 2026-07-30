import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/chat_bubble.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/chat_header.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/message_composer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/rich_card_widget.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/typing_indicator.dart';
import 'package:ai_travel_assistant/features/concierge_demo/domain/entities/proactive_scenario.dart';
import 'package:ai_travel_assistant/features/concierge_demo/presentation/viewmodels/scenario_chat_state.dart';
import 'package:ai_travel_assistant/features/concierge_demo/presentation/viewmodels/scenario_chat_viewmodel.dart';
import 'package:ai_travel_assistant/features/concierge_demo/presentation/widgets/notification_banner.dart';
import 'package:ai_travel_assistant/features/concierge_demo/presentation/widgets/suggested_reply_chip.dart';

/// Plays back one scripted Journey Concierge conversation: reuses the same
/// component structure as the generic assistant's [ChatPage] — header,
/// bubble/rich-card list, typing indicator, composer — seeded instead by
/// [ProactiveScenario.turns] rather than live intent classification.
class ScenarioChatPage extends ConsumerStatefulWidget {
  const ScenarioChatPage({super.key, required this.scenario});

  final ProactiveScenario scenario;

  static Route<void> route(ProactiveScenario scenario) {
    return MaterialPageRoute<void>(
      builder: (_) => ScenarioChatPage(scenario: scenario),
    );
  }

  @override
  ConsumerState<ScenarioChatPage> createState() => _ScenarioChatPageState();
}

class _ScenarioChatPageState extends ConsumerState<ScenarioChatPage> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = scenarioChatViewModelProvider(widget.scenario);
    final state = ref.watch(provider);
    final viewModel = ref.read(provider.notifier);

    ref.listen(provider, (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    final isThinking = state.status == ScenarioChatStatus.thinking;
    final showSuggestedReply = !state.isComplete && !isThinking;
    final nextTurn =
        showSuggestedReply && state.currentTurnIndex < widget.scenario.turns.length
            ? widget.scenario.turns[state.currentTurnIndex]
            : null;

    return Scaffold(
      body: Column(
        children: [
          ChatHeader(onBack: () => Navigator.of(context).maybePop()),
          NotificationBanner(text: widget.scenario.notificationText),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: state.messages.length + (isThinking ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < state.messages.length) {
                  final message = state.messages[index];
                  final isRichCard = message.type != ChatMessageType.text &&
                      message.type != ChatMessageType.error;
                  return isRichCard
                      ? RichCardWidget(message: message)
                      : ChatBubble(message: message);
                }
                return const TypingIndicator();
              },
            ),
          ),
          if (nextTurn != null)
            SuggestedReplyChip(
              text: nextTurn.parentLine,
              onTap: () => viewModel.sendReply(nextTurn.parentLine),
            ),
          MessageComposer(
            enabled: !state.isBusy,
            onSend: viewModel.sendReply,
            onMicPressed: () {},
          ),
        ],
      ),
    );
  }
}
