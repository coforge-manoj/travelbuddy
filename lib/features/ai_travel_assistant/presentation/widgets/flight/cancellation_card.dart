import 'package:flutter/material.dart';

import 'package:ai_travel_assistant/core/utils/money_format.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/cancellation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/card_shell.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/wallet_split_section.dart';

/// The `cancellation` card, in both of its lives: the refund preview shown
/// while the turn is waiting on a confirmation, and the receipt once the
/// refund has gone back. [Cancellation.isConfirmed] picks between them —
/// the preview must not read as though the booking is already gone.
class CancellationCard extends StatelessWidget {
  const CancellationCard({super.key, required this.cancellation});

  final Cancellation cancellation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isConfirmed = cancellation.isConfirmed;
    final accent = isConfirmed ? scheme.error : scheme.tertiary;
    final refundTotal = cancellation.effectiveRefundTotal;

    return CardShell(
      icon: isConfirmed ? Icons.cancel_outlined : Icons.help_outline,
      title: isConfirmed ? 'Booking cancelled' : 'Cancellation preview',
      accent: accent,
      children: [
        Text(
          [
            cancellation.pnr,
            if (cancellation.flightNumber.isNotEmpty) cancellation.flightNumber,
          ].join(' · '),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        if (cancellation.reason != null) ...[
          const SizedBox(height: 4),
          Text(
            cancellation.reason!,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
          ),
        ],
        if (cancellation.penalty != null && cancellation.penalty! > 0) ...[
          const CardDivider(),
          CardRow(
            label: 'Cancellation fee',
            value: '−${formatMoney(cancellation.penalty, cancellation.currency)}',
            valueColor: scheme.error,
          ),
        ],
        if (refundTotal != null) ...[
          const CardDivider(),
          CardRow(
            label: isConfirmed ? 'Refunded' : 'You would get back',
            value: formatMoney(refundTotal, cancellation.currency),
            emphasis: true,
          ),
        ],
        if (cancellation.refund != null)
          WalletSplitSection(
            wallet: cancellation.refund!,
            currency: cancellation.currency,
            isRefund: true,
            title: isConfirmed ? 'Refunded to' : 'Would be refunded to',
          ),
      ],
    );
  }
}
