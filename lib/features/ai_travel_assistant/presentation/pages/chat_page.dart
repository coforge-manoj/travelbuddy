import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_state.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_viewmodel.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/chat_bubble.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/chat_header.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/message_composer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/quick_actions_list.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/rich_card_widget.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/typing_indicator.dart';

/// The single entry-point screen for the AI Travel Assistant. Push this from
/// the host app — e.g.
/// `Navigator.push(context, AiTravelAssistantEntryPoint.route())` — it's
/// fully self-contained given the providers wired in `core/di/providers.dart`.
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
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
    final state = ref.watch(chatViewModelProvider);
    final viewModel = ref.read(chatViewModelProvider.notifier);

    ref.listen(chatViewModelProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    final isTyping = state.status == ChatStatus.sendingMessage;
    // Show the onboarding shortcuts once the welcome message and the initial
    // flight-offer suggestion have landed, until the passenger acts on
    // either of them.
    final showQuickActions = state.messages.length <= 2 && state.status == ChatStatus.idle;
    final itemCount = state.messages.length + (isTyping ? 1 : 0) + (showQuickActions ? 1 : 0);

    return Scaffold(
      body: Column(
        children: [
          ChatHeader(onBack: () => Navigator.of(context).maybePop()),
          Expanded(
            child: state.messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      if (index < state.messages.length) {
                        final message = state.messages[index];
                        final isRichCard = message.type != ChatMessageType.text &&
                            message.type != ChatMessageType.error;
                        return isRichCard
                            ? RichCardWidget(message: message)
                            : ChatBubble(message: message);
                      }
                      if (isTyping && index == state.messages.length) {
                        return const TypingIndicator();
                      }
                      return QuickActionsList(onSelected: viewModel.sendMessage);
                    },
                  ),
          ),
          MessageComposer(
            enabled: !state.isBusy,
            isListening: state.status == ChatStatus.listening,
            onSend: viewModel.sendMessage,
            onMicPressed: () {
              if (state.status == ChatStatus.listening) {
                viewModel.stopVoiceInput();
              } else {
                viewModel.startVoiceInput();
              }
            },
          ),
        ],
      ),
    );
  }
}
