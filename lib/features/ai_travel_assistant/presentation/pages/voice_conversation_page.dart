import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_viewmodel.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/voice_conversation_controller.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/voice_conversation_state.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/chat_suggestion_chips.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/confirm_action_bar.dart';
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
/// Whether audio mode is showing the answer's cards, or just the orb.
///
/// Held outside the page — and outside `chatViewModelProvider`, which is
/// `autoDispose` — so the choice survives leaving and re-entering audio mode.
/// A passenger who has pushed the cards away does not want them back every time
/// they tap the microphone again.
///
/// Defaults to off: audio mode is for listening, and the orb alone is the whole
/// interface until the passenger asks for more.
final voiceShowCardsProvider = StateProvider<bool>((ref) => false);

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
    // A fresh session greets first; a continuation goes straight to
    // listening. Re-entering mid-conversation must not replay the last
    // answer.
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
    final showCards = ref.watch(voiceShowCardsProvider);

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

    // Big enough to be the screen rather than a control on it, capped so it
    // does not swallow a tablet. With the cards up it goes back to being one
    // element among several.
    final orbSize = showCards
        ? 132.0
        : math.min(MediaQuery.sizeOf(context).shortestSide * 0.62, 280.0);

    final orb = VoiceOrb(
      phase: voice.phase,
      // Handed the notifier itself, not a value read here: levels arrive far
      // faster than this page should rebuild, and only the orb reads them.
      level: controller.micLevel,
      size: orbSize,
      onTap: () => voice.phase == VoicePhase.idle
          ? controller.resume()
          : controller.interrupt(),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_close());
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _Header(
                onClose: _close,
                showCards: showCards,
                // Nothing to reveal is worth saying: with no cards this turn the
                // toggle would promise a view that turns out to be a line of
                // text.
                cardCount: cards.length,
                onToggleCards: () => ref
                    .read(voiceShowCardsProvider.notifier)
                    .update((shown) => !shown),
              ),
              // Cards up: the answer is the screen and the orb sits under it, as
              // a boarding pass barcode or a seat grid has to be. Cards away: the
              // orb *is* the screen, centred in everything the header leaves.
              if (showCards)
                Expanded(
                  child: VoiceCardStage(
                    cards: cards,
                    fallbackText: lastAssistantText,
                  ),
                )
              else
                Expanded(child: Center(child: orb)),
              // Same gate as `ChatPage`: a pending approval outranks chips, so
              // "upgrade to Business" shows Confirm / Not now rather than
              // "check me in". Routed through the loop so tapping yes and
              // saying it take the same path.
              if (chat.needsConfirmation && !chat.isBusy)
                ConfirmActionBar(
                  prompt: chat.pendingConfirmationPrompt ?? 'Shall I go ahead?',
                  onConfirm: () => controller.say('yes'),
                  onDecline: () => controller.say('no'),
                )
              else
                ChatSuggestionChips(
                  suggestions: chat.suggestions,
                  onSelected: controller.say,
                ),
              _CaptionStrip(state: voice),
              if (showCards) ...[
                const SizedBox(height: 8),
                orb,
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onClose,
    required this.showCards,
    required this.cardCount,
    required this.onToggleCards,
  });

  final Future<void> Function() onClose;
  final bool showCards;

  /// How many cards the latest turn produced, used only to decide whether the
  /// toggle is worth offering.
  final int cardCount;

  final VoidCallback onToggleCards;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Text(
            'Voice mode',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (showCards || cardCount > 0)
            IconButton(
              tooltip: showCards ? 'Hide cards' : 'Show cards',
              onPressed: onToggleCards,
              isSelected: showCards,
              icon: Badge(
                // A quiet count while they are hidden, so the passenger knows
                // the answer had something to look at without being shown it.
                isLabelVisible: !showCards && cardCount > 0,
                label: Text('$cardCount'),
                child: Icon(showCards ? Icons.style : Icons.style_outlined),
              ),
            ),
          IconButton(
            tooltip: 'Close voice mode',
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

    // What the assistant said back on being asked, shown for as long as the
    // answer takes. It replaces "Thinking…" because it says the same thing with
    // the one addition that matters: what it thinks it was asked for.
    final acknowledgement =
        state.acknowledgement.isEmpty ? 'Thinking…' : state.acknowledgement;

    final caption = switch (state.phase) {
      VoicePhase.capturing => state.partialTranscript,
      VoicePhase.listening => 'Listening…',
      VoicePhase.preparing => 'Getting ready…',
      VoicePhase.thinking || VoicePhase.acknowledging => acknowledgement,
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
                : theme.textTheme.bodyMedium?.copyWith(
                    // The acknowledgement is the assistant talking, not a
                    // status line, so it is not greyed out like one.
                    color: state.isSpeaking ? null : grey,
                  ),
          ),
        ),
      ),
    );
  }
}
