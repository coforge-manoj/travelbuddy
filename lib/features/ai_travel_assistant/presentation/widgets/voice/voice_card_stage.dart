import 'package:flutter/material.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/rich_card_widget.dart';

/// The cards from the latest assistant turn, walking back from the end and
/// stopping at the passenger's last message.
///
/// A turn appends its text bubble and then all its cards together, so anything
/// after the last user message belongs to the answer just given.
List<ChatMessage> latestTurnCards(List<ChatMessage> messages) {
  final cards = <ChatMessage>[];
  for (final message in messages.reversed) {
    if (message.role == ChatRole.user) break;
    if (message.type == ChatMessageType.text ||
        message.type == ChatMessageType.error) {
      continue;
    }
    cards.insert(0, message);
  }
  return cards;
}

/// The visual half of audio mode.
///
/// TravelBuddy's answers are not all speakable — a boarding pass has a barcode
/// to scan and a seat map is a grid to pick from — so audio mode shows the
/// current answer rather than hiding it behind an orb. Only the latest turn is
/// shown: this is a conversation the passenger is listening to, not a
/// transcript they are reading.
///
/// Cards render through [RichCardWidget], the same dispatch the chat uses, so
/// there is no second copy of the twelve card widgets and a tap inside audio
/// mode round-trips through `/chat` exactly as it does in the chat. Tapping
/// seat 12A and saying "twelve A" become the same call.
class VoiceCardStage extends StatelessWidget {
  const VoiceCardStage({
    super.key,
    required this.cards,
    required this.fallbackText,
  });

  final List<ChatMessage> cards;

  /// Shown when the turn produced no cards, so the screen is never blank while
  /// audio is playing.
  final String fallbackText;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return _SpokenTextPanel(text: fallbackText);
    }

    if (cards.length == 1) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: SingleChildScrollView(
          key: ValueKey(cards.single.id),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: RichCardWidget(message: cards.single),
        ),
      );
    }

    return PageView.builder(
      controller: PageController(viewportFraction: 0.92),
      itemCount: cards.length,
      itemBuilder: (context, index) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: RichCardWidget(message: cards[index]),
      ),
    );
  }
}

class _SpokenTextPanel extends StatelessWidget {
  const _SpokenTextPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                height: 1.35,
                fontWeight: FontWeight.w400,
              ),
        ),
      ),
    );
  }
}
