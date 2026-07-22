import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_state.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_viewmodel.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/chat_bubble.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/message_composer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/rich_card_widget.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/suggested_prompts.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel Assistant'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: state.messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount:
                        state.messages.length + (state.status == ChatStatus.sendingMessage ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.messages.length) {
                        return const TypingIndicator();
                      }
                      final message = state.messages[index];
                      final isRichCard = message.type != ChatMessageType.text &&
                          message.type != ChatMessageType.error;
                      return isRichCard
                          ? RichCardWidget(message: message)
                          : ChatBubble(message: message);
                    },
                  ),
          ),
          SuggestedPrompts(
            prompts: state.suggestedPrompts,
            onSelected: viewModel.sendMessage,
          ),
          const Divider(height: 1),
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
