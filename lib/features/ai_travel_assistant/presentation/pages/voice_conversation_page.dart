import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_viewmodel.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/voice_conversation_controller.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/voice_conversation_state.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/voice/voice_card_stage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/voice/voice_orb.dart';

/// Hands-free audio mode.
///
/// **Must be pushed over a mounted `ChatPage`, never used as a replacement.**
/// `chatViewModelProvider` is `autoDispose` and `ChatViewModel._startNewSession`
/// clears history and reseeds a welcome message on construction, so a replace
/// would tear the notifier down and silently destroy the whole conversation.
/// Pushing keeps `ChatPage`'s `ref.watch` alive underneath, which is what makes
/// the transcript complete the moment this page is popped, and what lets
/// re-entering audio mode continue where it left off.
class VoiceConversationPage extends ConsumerStatefulWidget {
  const VoiceConversationPage({super.key});

  static const routeName = '/ai-travel-assistant/voice';

  static Route<void> route() {
    return PageRouteBuilder<void>(
      settings: const RouteSettings(name: routeName),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
      pageBuilder: (_, __, ___) => const VoiceConversationPage(),
    );
  }

  @override
  ConsumerState<VoiceConversationPage> createState() =>
      _VoiceConversationPageState();
}

class _VoiceConversationPageState extends ConsumerState<VoiceConversationPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Straight into listening. Nothing is replayed on entry: re-entering
    // mid-conversation to speak again should not first read the last answer
    // back at the passenger.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(voiceConversationControllerProvider.notifier).start();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // One mechanism for phone calls, app switching, Siri and the screen
    // locking: all of them leave `resumed` first.
    ref
        .read(voiceConversationControllerProvider.notifier)
        .onAppLifecycle(state);
  }

  Future<void> _close() async {
    await ref.read(voiceConversationControllerProvider.notifier).stop();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final voice = ref.watch(voiceConversationControllerProvider);
    final chat = ref.watch(chatViewModelProvider);
    final controller = ref.read(voiceConversationControllerProvider.notifier);

    final cards = latestTurnCards(chat.messages);
    final lastAssistantText = chat.messages
        .lastWhere(
          (m) => m.role == ChatRole.assistant && m.type == ChatMessageType.text,
          orElse: () => ChatMessage(
            id: 'none',
            role: ChatRole.assistant,
            type: ChatMessageType.text,
            timestamp: DateTime.now(),
          ),
        )
        .text;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(onClose: _close),
            Expanded(
              child: VoiceCardStage(
                cards: cards,
                fallbackText: lastAssistantText,
              ),
            ),
            _CaptionStrip(state: voice),
            const SizedBox(height: 8),
            VoiceOrb(
              phase: voice.phase,
              onTap: () => voice.phase == VoicePhase.idle
                  ? controller.resume()
                  : controller.interrupt(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final Future<void> Function() onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Text(
            'Audio mode',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Close audio mode',
            onPressed: onClose,
            icon: const Icon(Icons.keyboard_arrow_down),
          ),
        ],
      ),
    );
  }
}

/// The live caption: what the passenger is saying, or what the assistant is
/// doing while they are not.
class _CaptionStrip extends StatelessWidget {
  const _CaptionStrip({required this.state});

  final VoiceConversationState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grey = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6);

    final caption = switch (state.phase) {
      VoicePhase.capturing => state.partialTranscript,
      VoicePhase.listening => 'Listening…',
      VoicePhase.preparing => 'Getting ready…',
      VoicePhase.thinking => 'Thinking…',
      VoicePhase.speaking => 'Speaking…',
      VoicePhase.recovering => state.message ?? 'One moment…',
      VoicePhase.permissionDenied =>
        state.message ?? 'I need permission to use the microphone.',
      VoicePhase.idle => state.message ?? 'Tap to talk.',
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
        child: Center(
          child: Text(
            caption,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: state.phase == VoicePhase.capturing
                ? theme.textTheme.titleMedium
                : theme.textTheme.bodyMedium?.copyWith(color: grey),
          ),
        ),
      ),
    );
  }
}
