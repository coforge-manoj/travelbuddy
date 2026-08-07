import 'package:flutter/material.dart';

import 'package:ai_travel_assistant/core/utils/money_format.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat_confirmation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/card_shell.dart';

/// The `seat_confirmed` card: the seat now held, and — when the passenger
/// moved rather than picked for the first time — the one it replaced.
class SeatConfirmedCard extends StatelessWidget {
  const SeatConfirmedCard({super.key, required this.confirmation});

  final SeatConfirmation confirmation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const accent = Color(0xFF1E8E3E);
    final previous = confirmation.previousSeatNumber;

    final details = <String>[
      if (confirmation.cabin.isNotEmpty) confirmation.cabin,
      if (confirmation.flightNumber.isNotEmpty) confirmation.flightNumber,
      if (confirmation.type != null) confirmation.type!,
    ];

    return CardShell(
      icon: Icons.event_seat_outlined,
      title: 'Seat confirmed',
      accent: accent,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (previous != null) ...[
              Text(
                previous,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.outline,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
            Text(
              confirmation.seatNumber,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ],
        ),
        if (details.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(details.join(' · '), style: theme.textTheme.bodySmall),
        ],
        if (confirmation.price > 0) ...[
          const CardDivider(),
          CardRow(
            label: 'Seat charge',
            value: formatMoney(confirmation.price, confirmation.currency),
            emphasis: true,
          ),
        ],
      ],
    );
  }
}
