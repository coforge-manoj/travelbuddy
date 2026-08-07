import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_selection.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/wallet_split.dart';

/// Basket / held-flight card from a TravelBuddy `flight_selected` response.
class FlightSelectedCard extends StatelessWidget {
  const FlightSelectedCard({super.key, required this.selection});

  final FlightSelection selection;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final timeFormat = DateFormat.Hm();
    final flight = selection.flight;
    final arrivalSuffix = flight.arrivesNextDay ? ' +1' : '';
    // Never computed — see [FlightSummaryLine] for why local times cannot
    // be subtracted to get a duration.
    final duration = flight.durationLabel;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(14),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_bag_outlined,
                    size: 18, color: scheme.onSecondaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Flight held in basket',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.onSecondaryContainer,
                        ),
                  ),
                ),
                Text(
                  '\$${selection.total.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${flight.flightNumber} · ${flight.origin} → ${flight.destination}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              '${timeFormat.format(flight.departureTime)} – '
              '${timeFormat.format(flight.arrivalTime)}$arrivalSuffix'
              '${duration != null ? ' · $duration' : ''}'
              '${flight.aircraft != null ? ' · ${flight.aircraft}' : ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSecondaryContainer.withOpacity(0.85),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '${selection.cabin} · ${selection.pax} passenger'
              '${selection.pax == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
            ),
            if (selection.wallet != null) ...[
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: scheme.onSecondaryContainer.withOpacity(0.2),
              ),
              const SizedBox(height: 10),
              Text(
                'Payment applied',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 6),
              ..._walletLines(context, selection.wallet!),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _walletLines(
    BuildContext context,
    WalletSplit wallet,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.onSecondaryContainer.withOpacity(0.9),
        );
    final lines = <Widget>[];

    final voucher = wallet.voucher;
    if (voucher != null && voucher.applied > 0) {
      lines.add(
        Text(
          'Voucher ${voucher.code}: −\$${voucher.applied.toStringAsFixed(0)}',
          style: style,
        ),
      );
    }

    final miles = wallet.miles;
    if (miles != null && miles.applied > 0) {
      lines.add(
        Text(
          'Miles ${miles.milesUsed.toStringAsFixed(0)}: '
          '−\$${miles.applied.toStringAsFixed(0)}',
          style: style,
        ),
      );
    }

    final card = wallet.card;
    if (card != null) {
      lines.add(
        Text(
          '${card.brand} •••• ${card.last4}: '
          '\$${card.amount.toStringAsFixed(0)}',
          style: style,
        ),
      );
    }

    return [
      for (var i = 0; i < lines.length; i++) ...[
        if (i > 0) const SizedBox(height: 2),
        lines[i],
      ],
    ];
  }
}
