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
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/voice/speaking_indicator.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/voice/voice_status_bar.dart';

/// The single entry-point screen for the AI Travel Assistant. Push this from
/// the host app — e.g.
/// `Navigator.push(context, AiTravelAssistantEntryPoint.route())` — it's
/// fully self-contained given the providers wired in `core/di/providers.dart`.
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> with WidgetsBindingObserver {
  final _scrollController = ScrollController();

  /// When talkback is on, the passenger can temporarily prefer the text
  /// composer. Not persisted — entering talkback always lands on the orb.
  bool _preferTypingWhileTalkback = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Sync the app-scoped narrator with the current lifecycle — a previous
    // visit may have left speech blocked after a background.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final lifecycle =
          WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
      ref.read(chatViewModelProvider.notifier).handleAppLifecycle(lifecycle);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(chatViewModelProvider.notifier).handleAppLifecycle(state);
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

  /// The orb means one thing only: start or stop *listening*. Tapping it while
  /// the assistant talks is a barge-in — [ChatViewModel.startVoiceInput] stops
  /// narration on its way in. Silencing without speaking is the dedicated stop
  /// button's job.
  void _toggleMic(ChatViewModel viewModel, ChatState state) {
    if (state.status == ChatStatus.listening) {
      viewModel.stopVoiceInput();
    } else {
      viewModel.startVoiceInput();
    }
  }

  void _toggleComposerMic(ChatViewModel viewModel, ChatState state) {
    if (state.status == ChatStatus.listening) {
      viewModel.stopVoiceInput();
    } else {
      viewModel.startVoiceInput(mode: VoiceInputMode.dictate);
    }
  }

  Future<void> _onTalkbackToggle(ChatViewModel viewModel, bool currentlyEnabled) async {
    if (!currentlyEnabled) {
      // Entering talkback always shows the orb first.
      setState(() => _preferTypingWhileTalkback = false);
    }
    await viewModel.toggleVoiceOutput();
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
    // Show the onboarding shortcuts once the welcome message has landed,
    // until the passenger sends their first message.
    final showQuickActions = state.messages.length <= 1 && state.status == ChatStatus.idle;
    final itemCount = state.messages.length + (isTyping ? 1 : 0) + (showQuickActions ? 1 : 0);

    final showVoiceBar = state.isVoiceOutputEnabled && !_preferTypingWhileTalkback;
    // Chip only when the orb is hidden (talkback off, or temporary typing).
    final showSpeakingChip = state.isSpeaking && !showVoiceBar;

    return Scaffold(
      body: Column(
        children: [
          ChatHeader(
            onBack: () => Navigator.of(context).maybePop(),
            isTalkbackEnabled: state.isVoiceOutputEnabled,
            onTalkbackToggle: () => _onTalkbackToggle(viewModel, state.isVoiceOutputEnabled),
          ),
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
          if (showSpeakingChip) SpeakingIndicator(onStop: viewModel.stopSpeaking),
          if (showVoiceBar)
            VoiceStatusBar(
              status: state.status,
              enabled: !state.isBusy || state.status == ChatStatus.speaking,
              onOrbTap: () => _toggleMic(viewModel, state),
              onStopSpeaking: viewModel.stopSpeaking,
              onPreferTyping: () => setState(() => _preferTypingWhileTalkback = true),
            )
          else
            MessageComposer(
              enabled: !state.isBusy,
              isListening: state.status == ChatStatus.listening,
              showReturnToVoice: state.isVoiceOutputEnabled,
              dictationText: state.dictationDraft,
              dictationRevision: state.dictationRevision,
              onReturnToVoice: () {
                setState(() => _preferTypingWhileTalkback = false);
                if (state.status != ChatStatus.listening &&
                    state.status != ChatStatus.speaking) {
                  viewModel.startVoiceInput();
                }
              },
              onSend: viewModel.sendMessage,
              onMicPressed: () => _toggleComposerMic(viewModel, state),
            ),
        ],
      ),
    );
  }
}
