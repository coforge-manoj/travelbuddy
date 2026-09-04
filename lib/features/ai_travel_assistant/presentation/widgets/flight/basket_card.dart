import 'package:flutter/material.dart';

import 'package:ai_travel_assistant/core/utils/money_format.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/basket.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/card_shell.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/flight/flight_summary_line.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/wallet_split_section.dart';

/// The `basket` card: fare, extras, discounts, total and wallet split.
///
/// The same card is sent as the preview for "book it", where it arrives
/// alongside `needsConfirmation: true` — the Confirm control for that lives
/// above the composer (see `ConfirmActionBar`) rather than on the card, so
/// there is only ever one place to approve a payment.
class BasketCard extends StatelessWidget {
  const BasketCard({super.key, required this.basket});

  final Basket basket;

  @override
  Widget build(BuildContext context) {
    final currency = basket.currency;
    final flight = basket.flight;
    final paidExtras = basket.extras.where((e) => !e.included).toList();
    final includedExtras = basket.extras.where((e) => e.included).toList();

    return CardShell(
      icon: Icons.shopping_bag_outlined,
      title: 'Your basket',
      trailing: Text(
        formatMoney(basket.total, currency),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
      children: [
        if (flight != null) ...[
          FlightSummaryLine(flight: flight),
          const SizedBox(height: 8),
        ],
        if (basket.cabin.isNotEmpty || basket.pax > 0)
          Text(
            [
              if (basket.cabin.isNotEmpty) basket.cabin,
              '${basket.pax} passenger${basket.pax == 1 ? '' : 's'}',
            ].join(' · '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const CardDivider(),
        if (basket.baseFare != null)
          CardRow(
            label: basket.pax > 1 && basket.perPassenger != null
                ? 'Fare (${formatMoney(basket.perPassenger, currency)} × ${basket.pax})'
                : 'Fare',
            value: formatMoney(basket.baseFare, currency),
          ),
        if (basket.taxes != null)
          CardRow(
            label: 'Taxes & fees',
            value: formatMoney(basket.taxes, currency),
          ),
        for (final extra in paidExtras)
          CardRow(
            label: extra.quantity > 1
                ? '${extra.name} × ${extra.quantity}'
                : extra.name,
            value: formatMoney(extra.price * extra.quantity, currency),
          ),
        for (final extra in includedExtras)
          CardRow(
            label: extra.name,
            value: 'Included',
            muted: true,
          ),
        for (final discount in basket.discounts)
          CardRow(
            label: discount.label,
            value: '−${formatMoney(discount.amount, currency)}',
            valueColor: Theme.of(context).colorScheme.tertiary,
          ),
        const CardDivider(),
        CardRow(
          label: 'Total',
          value: formatMoney(basket.total, currency),
          emphasis: true,
        ),
        if (basket.wallet != null)
          WalletSplitSection(
            wallet: basket.wallet!,
            currency: currency,
            title: 'Wallet covers',
          ),
      ],
    );
  }
}
