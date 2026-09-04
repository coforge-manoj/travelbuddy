import 'package:flutter/material.dart';

/// Shown above the composer whenever the last `/chat` turn came back with
/// `needsConfirmation: true` — paying, upgrading and cancelling never happen
/// on the first ask.
///
/// This is the single place any of those get approved, which is why none of
/// the preview cards carry their own Confirm button. Declining does not send
/// anything: it just clears the pending action, leaving the passenger free
/// to keep typing.
class ConfirmActionBar extends StatelessWidget {
  const ConfirmActionBar({
    super.key,
    required this.prompt,
    required this.onConfirm,
    required this.onDecline,
  });

  /// What is being approved, in the backend's own words.
  final String prompt;
  final VoidCallback onConfirm;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.tertiary.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 18, color: scheme.tertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              prompt,
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onDecline,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: const Text('Not now'),
          ),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: onConfirm,
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
