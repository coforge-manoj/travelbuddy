import 'package:flutter/material.dart';
import 'package:ai_travel_assistant/core/theme/app_theme.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/markdown_message.dart';

/// A single text bubble in the conversation. Rich-card message types are
/// rendered by [RichCardWidget] instead — this widget only handles
/// [ChatMessageType.text] and [ChatMessageType.error].
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  bool get _isUser => message.role == ChatRole.user;
  bool get _isError => message.type == ChatMessageType.error;

  @override
  Widget build(BuildContext context) {
    final align = _isUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = _isError
        ? ChatColors.errorBubble(context)
        : _isUser
            ? ChatColors.userBubble(context)
            : ChatColors.assistantBubble(context);
    final textColor =
        _isUser ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface;

    return Align(
      alignment: align,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(_isUser ? 16 : 4),
            bottomRight: Radius.circular(_isUser ? 4 : 16),
          ),
          boxShadow: [
            if (!_isUser)
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: MarkdownMessage(text: message.text, color: textColor),
      ),
    );
  }
}
