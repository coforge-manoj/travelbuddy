import 'package:flutter/material.dart';

import 'package:ai_travel_assistant/core/theme/app_theme.dart';

/// Shown while the assistant is talking in typing mode, so there is always a
/// way to cut a summary short without hunting for the mute button.
class SpeakingIndicator extends StatelessWidget {
  const SpeakingIndicator({super.key, required this.onStop});

  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ActionChip(
          avatar: const Icon(Icons.graphic_eq, size: 18, color: AppTheme.brandBlue),
          label: const Text('Speaking — tap to stop'),
          onPressed: onStop,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
