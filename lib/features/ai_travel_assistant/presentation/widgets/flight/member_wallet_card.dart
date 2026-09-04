import 'package:flutter/material.dart';

import 'package:ai_travel_assistant/core/utils/money_format.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/member_wallet.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/card_shell.dart';

/// The `wallet` card: what the member can pay with, before any booking
/// exists. Miles lead, because that is what the question ("can we do this on
/// miles?") is actually about.
///
/// Not to be confused with [WalletSplitSection], which breaks down a
/// *specific* payment inside the basket and booking cards.
class MemberWalletCard extends StatelessWidget {
  const MemberWalletCard({super.key, required this.wallet});

  final MemberWallet wallet;

  @override
  Widget build(BuildContext context) {
    final voucher = wallet.voucher;
    final card = wallet.card;

    return CardShell(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Your wallet',
      trailing: wallet.tier == null
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                wallet.tier!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
      children: [
        if (wallet.miles != null)
          CardRow(
            label: 'AAdvantage miles',
            value: formatCount(wallet.miles),
          ),
        // Status-qualifying points, not spendable — labelled so the two
        // numbers are not mistaken for each other.
        if (wallet.loyaltyPoints != null)
          CardRow(
            label: 'Loyalty points',
            value: formatCount(wallet.loyaltyPoints),
          ),
        // Most members have no voucher — the live payload sends `null` — so
        // this row stays absent rather than showing a zero.
        if (voucher != null)
          CardRow(
            label: voucher.code == null ? 'Voucher' : 'Voucher ${voucher.code}',
            value: voucher.amount == null
                ? '—'
                : formatMoney(voucher.amount, 'USD'),
          ),
        if (card != null)
          CardRow(
            label: card.brand ?? 'Card on file',
            value: card.last4 == null ? '—' : '•••• ${card.last4}',
          ),
      ],
    );
  }
}
