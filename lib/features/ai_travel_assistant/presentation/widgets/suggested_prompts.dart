import 'package:flutter/material.dart';

/// Horizontally scrolling chips of suggested prompts shown above the
/// composer, e.g. right after the welcome message or in an empty state.
class SuggestedPrompts extends StatelessWidget {
  const SuggestedPrompts({super.key, required this.prompts, required this.onSelected});

  final List<String> prompts;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (prompts.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: prompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final prompt = prompts[index];
          return ActionChip(
            label: Text(prompt),
            onPressed: () => onSelected(prompt),
          );
        },
      ),
    );
  }
}
