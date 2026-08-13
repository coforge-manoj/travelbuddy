import 'package:flutter/material.dart';

import 'package:ai_travel_assistant/core/utils/app_date.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/document_check.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/card_shell.dart';

/// The `document_check` card. Issues lead, each paired with what to do about
/// it — a warning without a remedy is just anxiety. Passengers who are fine
/// are summarised underneath rather than given equal weight.
class DocumentCheckCard extends StatelessWidget {
  const DocumentCheckCard({super.key, required this.check});

  final DocumentCheck check;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blocked = check.issues.any((i) => i.isBlocking);
    final accent = check.ready
        ? Colors.green.shade700
        : (blocked ? scheme.error : Colors.orange.shade800);

    return CardShell(
      icon: check.ready ? Icons.verified_outlined : Icons.badge_outlined,
      title: check.destination == null
          ? 'Travel documents'
          : 'Travel documents · ${check.destination}',
      accent: accent,
      children: [
        if (check.ruleDetail != null) ...[
          Text(
            check.ruleDetail!,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant, height: 1.3),
          ),
          const SizedBox(height: 10),
        ],
        for (final issue in check.issues) ...[
          _IssueRow(issue: issue, accent: accent),
          const SizedBox(height: 10),
        ],
        if (check.clear.isNotEmpty) ...[
          if (check.issues.isNotEmpty) const CardDivider(),
          for (final ok in check.clear)
            CardRow(
              label: '✓ ${ok.passenger}',
              value: ok.expiry == null
                  ? 'Valid'
                  : 'Valid to ${AppDate.formatRaw(ok.expiry)}',
            ),
        ],
      ],
    );
  }
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({required this.issue, required this.accent});

  final DocumentIssue issue;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                issue.isBlocking
                    ? Icons.error_outline
                    : Icons.warning_amber_outlined,
                size: 16,
                color: accent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  issue.passenger,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                ),
              ),
            ],
          ),
          if (issue.detail != null) ...[
            const SizedBox(height: 4),
            Text(
              issue.detail!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurface, height: 1.3),
            ),
          ],
          // The remedy is the half that makes this helpful rather than
          // alarming, so it is always shown when the backend sends one.
          if (issue.action != null) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.arrow_forward, size: 13, color: accent),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    issue.action!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
