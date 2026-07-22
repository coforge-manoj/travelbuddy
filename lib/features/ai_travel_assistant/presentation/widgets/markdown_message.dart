import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Thin wrapper around [MarkdownBody] styled to match the chat bubble's text
/// color, with scrolling/selection disabled since it's nested in a bubble.
class MarkdownMessage extends StatelessWidget {
  const MarkdownMessage({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: text,
      shrinkWrap: true,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
        listBullet: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
        strong: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
