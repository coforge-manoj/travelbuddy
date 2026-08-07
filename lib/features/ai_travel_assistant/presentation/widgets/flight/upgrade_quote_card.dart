import 'package:flutter/material.dart';

import 'package:ai_travel_assistant/core/utils/money_format.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/upgrade_quote.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/card_shell.dart';

/// The `upgrade_quote` card: cash and miles price for the move, plus
/// whether the member's balance covers it.
///
/// The quote always arrives with `needsConfirmation: true`, so this card
/// never carries its own Confirm button — approving it goes through the
/// single confirmation bar above the composer.
class UpgradeQuoteCard extends StatelessWidget {
  const UpgradeQuoteCard({super.key, required this.quote});

  final UpgradeQuote quote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final affordable = quote.canAffordWithMiles;

    return CardShell(
      icon: Icons.upgrade,
      title: quote.fromCabin.isEmpty
          ? 'Upgrade to ${quote.toCabin}'
          : '${quote.fromCabin} → ${quote.toCabin}',
      accent: scheme.tertiary,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (quote.cash != null)
              Expanded(
                child: _PriceBlock(
                  label: 'Cash',
                  value: formatMoney(quote.cash, quote.currency),
                ),
              ),
            if (quote.cash != null && quote.miles != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.outline),
                ),
              ),
            if (quote.miles != null)
              Expanded(
                child: _PriceBlock(
                  label: 'Miles',
                  value: formatCount(quote.miles),
                ),
              ),
          ],
        ),
        if (quote.milesBalance != null) ...[
          const CardDivider(),
          CardRow(
            label: 'Your balance',
            value: '${formatCount(quote.milesBalance)} miles',
          ),
        ],
        if (affordable != null) ...[
          const SizedBox(height: 8),
          CardBadge(
            label: affordable
                ? 'Covered by your miles'
                : 'Not enough miles — pay with cash',
            color: affordable ? const Color(0xFF1E8E3E) : scheme.error,
          ),
        ],
        if (quote.seatsAvailable != null) ...[
          const SizedBox(height: 8),
          Text(
            '${quote.seatsAvailable} seat'
            '${quote.seatsAvailable == 1 ? '' : 's'} left in ${quote.toCabin}',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
          ),
        ],
      ],
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
