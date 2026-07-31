import 'package:flutter/material.dart';

import 'package:ai_travel_assistant/core/theme/app_theme.dart';

/// Shown while the assistant is talking in typing mode, so there is always a
/// way to cut a summary short without hunting for the mute button.
///
/// [preparing] covers the stretch between a reply landing and its audio
/// actually starting — wording and network synthesis both happen in there,
/// and claiming "speaking" over silence reads as a bug.
class SpeakingIndicator extends StatelessWidget {
  const SpeakingIndicator({
    super.key,
    required this.onStop,
    this.preparing = false,
  });

  final VoidCallback onStop;
  final bool preparing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ActionChip(
          avatar: preparing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.brandBlue,
                  ),
                )
              : const Icon(Icons.graphic_eq, size: 18, color: AppTheme.brandBlue),
          label: Text(
            preparing ? 'Preparing audio — tap to skip' : 'Speaking — tap to stop',
          ),
          onPressed: onStop,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
