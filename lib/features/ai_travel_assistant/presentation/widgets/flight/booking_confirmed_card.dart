import 'package:flutter/material.dart';

import 'package:ai_travel_assistant/core/utils/money_format.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking_confirmation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/card_shell.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/flight/flight_summary_line.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/wallet_split_section.dart';

/// The `booking_confirmed` card (and `booking_detail`, read back later):
/// the PNR the passenger quotes at the airport, and how it was paid for.
///
/// The PNR gets the most weight on the card — it is the one thing they will
/// be asked for.
class BookingConfirmedCard extends StatelessWidget {
  const BookingConfirmedCard({super.key, required this.booking});

  final BookingConfirmation booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final flight = booking.flight;
    final accent = booking.isDetail ? scheme.primary : const Color(0xFF1E8E3E);

    return CardShell(
      icon: booking.isDetail
          ? Icons.confirmation_number_outlined
          : Icons.check_circle_outline,
      title: booking.isDetail ? 'Your booking' : 'Booking confirmed',
      accent: accent,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              booking.pnr,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: accent,
              ),
            ),
            const SizedBox(width: 10),
            if (booking.status != null) CardBadge(label: booking.status!, color: accent),
          ],
        ),
        const SizedBox(height: 10),
        if (flight != null) ...[
          FlightSummaryLine(flight: flight),
          const SizedBox(height: 8),
        ],
        Text(
          [
            if (booking.passengerName != null) booking.passengerName!,
            if (booking.cabin.isNotEmpty) booking.cabin,
            if (booking.seat != null) 'Seat ${booking.seat}',
            '${booking.pax} passenger${booking.pax == 1 ? '' : 's'}',
          ].join(' · '),
          style: theme.textTheme.bodySmall,
        ),
        if (booking.extras.isNotEmpty) ...[
          const CardDivider(),
          for (final extra in booking.extras)
            CardRow(
              label: extra.quantity > 1
                  ? '${extra.name} × ${extra.quantity}'
                  : extra.name,
              value: extra.included
                  ? 'Included'
                  : formatMoney(extra.price * extra.quantity, booking.currency),
              muted: extra.included,
            ),
        ],
        if (booking.total != null) ...[
          const CardDivider(),
          CardRow(
            label: 'Total paid',
            value: formatMoney(booking.total, booking.currency),
            emphasis: true,
          ),
        ],
        if (booking.milesEarned != null && booking.milesEarned! > 0)
          CardRow(
            label: 'Miles earned',
            value: '+${formatCount(booking.milesEarned)}',
            valueColor: accent,
          ),
        if (booking.wallet != null)
          WalletSplitSection(
            wallet: booking.wallet!,
            currency: booking.currency,
          ),
      ],
    );
  }
}
