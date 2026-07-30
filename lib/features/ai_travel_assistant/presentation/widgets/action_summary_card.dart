import 'package:flutter/material.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/action_summary.dart';

/// Renders a concluding [ActionSummary] — styled to match the other success
/// cards ([BaggageSuccessCard], [BookingConfirmationCard]): a colored
/// container, a headline row with an icon, and a short list of detail lines.
class ActionSummaryCard extends StatelessWidget {
  const ActionSummaryCard({super.key, required this.summary});

  final ActionSummary summary;

  static IconData _iconFor(ActionIcon icon) {
    return switch (icon) {
      ActionIcon.checkCircle => Icons.check_circle,
      ActionIcon.bookmark => Icons.bookmark_added_outlined,
      ActionIcon.document => Icons.description_outlined,
      ActionIcon.route => Icons.alt_route_outlined,
      ActionIcon.clock => Icons.access_time_outlined,
      ActionIcon.info => Icons.info_outline,
      ActionIcon.family => Icons.family_restroom_outlined,
      ActionIcon.luggage => Icons.luggage_outlined,
      ActionIcon.seat => Icons.event_seat_outlined,
      ActionIcon.passport => Icons.badge_outlined,
      ActionIcon.celebration => Icons.celebration_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_iconFor(summary.icon), size: 18, color: scheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    summary.headline,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: scheme.onPrimaryContainer),
                  ),
                ),
              ],
            ),
            if (summary.details.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final detail in summary.details)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    detail,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: scheme.onPrimaryContainer),
                  ),
                ),
            ],
            if (summary.footer != null) ...[
              const SizedBox(height: 6),
              Text(
                summary.footer!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimaryContainer.withOpacity(0.75),
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
