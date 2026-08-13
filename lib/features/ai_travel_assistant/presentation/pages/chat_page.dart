import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/pages/voice_conversation_page.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_state.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_viewmodel.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/chat_bubble.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/chat_header.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/chat_suggestion_chips.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/confirm_action_bar.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/message_composer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/rich_card_widget.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/typing_indicator.dart';
import 'package:ai_travel_assistant/features/concierge_demo/presentation/widgets/suggested_reply_chip.dart';

/// The single entry-point screen for the AI Travel Assistant. Push this from
/// the host app — e.g.
/// `Navigator.push(context, AiTravelAssistantEntryPoint.route())` — it's
/// fully self-contained given the providers wired in `core/di/providers.dart`.
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, this.autoStartScenarioId});

  /// A Journey Concierge scenario id to kick off as soon as this page
  /// opens — set when a passenger taps the post-use-case reminder
  /// notification, so tapping it lands them straight back in the concierge
  /// conversation instead of just the plain welcome screen.
  final String? autoStartScenarioId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Resolve which scenario (if any) should replace the plain welcome
    // message: either the one behind a tapped notification, or — if the
    // passenger instead opened the AI assistant directly, missing or
    // ignoring the notification — whichever use case a pending reminder was
    // still waiting on. Deliberately left in the pending marker as-is here:
    // it's only cleared once that scenario actually completes (see
    // `ChatViewModel._scheduleNextUseCaseReminder`), so backing out before
    // finishing it and reopening the assistant resumes the same use case
    // again instead of losing it.
    final tappedScenarioId = widget.autoStartScenarioId;
    final pendingScenarioId = ref.read(pendingNextScenarioIdProvider);
    final effectiveScenarioId = tappedScenarioId ?? pendingScenarioId;
    if (effectiveScenarioId != null) {
      // Deferred until after the widget tree finishes building this frame —
      // Riverpod disallows modifying a provider's state directly inside
      // initState.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(chatViewModelProvider.notifier).startScenarioById(effectiveScenarioId);
      });
    }
  }

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
    final itemCount = state.messages.length + (isTyping ? 1 : 0);

    final activeScenario = state.activeScenario;
    final showSuggestedReply = activeScenario != null && !state.isBusy;
    final nextScenarioTurn = showSuggestedReply && state.scenarioTurnIndex < activeScenario.turns.length
        ? activeScenario.turns[state.scenarioTurnIndex]
        : null;

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
                      return const TypingIndicator();
                    },
                  ),
          ),
          // A pending confirmation outranks the suggestion chips: paying,
          // upgrading and cancelling are the one thing the passenger has to
          // answer before anything else moves.
          if (state.needsConfirmation && !state.isBusy)
            ConfirmActionBar(
              prompt: state.pendingConfirmationPrompt ?? 'Shall I go ahead?',
              onConfirm: viewModel.confirmPendingAction,
              onDecline: viewModel.declinePendingAction,
            )
          else if (state.suggestions.isNotEmpty && !state.isBusy)
            ChatSuggestionChips(
              suggestions: state.suggestions,
              onSelected: viewModel.sendMessage,
            )
          else if (nextScenarioTurn != null)
            SuggestedReplyChip(
              text: nextScenarioTurn.parentLine,
              onTap: () => viewModel.sendMessage(nextScenarioTurn.parentLine),
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
            // Pushed, never `pushReplacement`. `chatViewModelProvider` is
            // autoDispose and `_startNewSession` clears history on
            // construction, so replacing this page would tear the notifier
            // down and silently wipe the conversation the passenger is in the
            // middle of. Pushing keeps this page mounted and its `ref.watch`
            // alive, which is what makes the transcript complete the moment
            // audio mode is closed, and what lets re-entering it continue the
            // same conversation on the same backend session.
            onAudioModePressed: () => Navigator.of(context).push(
              VoiceConversationPage.route(),
            ),
          ),
        ],
      ),
    );
  }
}
