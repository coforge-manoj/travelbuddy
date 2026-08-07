import 'package:flutter/material.dart';

import 'package:ai_travel_assistant/core/utils/money_format.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/wallet_split.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/card_shell.dart';

/// The voucher / miles / card breakdown shared by the basket, booking and
/// cancellation cards. [isRefund] only changes the wording — the same split
/// describes money going out and money coming back.
class WalletSplitSection extends StatelessWidget {
  const WalletSplitSection({
    super.key,
    required this.wallet,
    required this.currency,
    this.isRefund = false,
    this.title,
  });

  final WalletSplit wallet;
  final String currency;
  final bool isRefund;
  final String? title;

  @override
  Widget build(BuildContext context) {
    if (wallet.isEmpty) return const SizedBox.shrink();

    final voucher = wallet.voucher;
    final miles = wallet.miles;
    final card = wallet.card;
    final sign = isRefund ? '' : '−';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const CardDivider(),
        Text(
          title ?? (isRefund ? 'Refunded to' : 'Paid with'),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        if (voucher != null && voucher.applied > 0)
          CardRow(
            label: voucher.code.isEmpty
                ? 'Voucher'
                : 'Voucher ${voucher.code}',
            value: '$sign${formatMoney(voucher.applied, currency)}',
          ),
        if (miles != null && miles.applied > 0)
          CardRow(
            // The miles count is the number the member recognises; the cash
            // column stays in the same currency as every other row.
            label: '${formatCount(miles.milesUsed)} miles',
            value: '$sign${formatMoney(miles.applied, currency)}',
          ),
        if (card != null && card.amount > 0)
          CardRow(
            label: [
              if (card.brand.isNotEmpty) card.brand,
              if (card.last4.isNotEmpty) '•••• ${card.last4}',
            ].join(' ').trim().isEmpty
                ? 'Card'
                : [
                    if (card.brand.isNotEmpty) card.brand,
                    if (card.last4.isNotEmpty) '•••• ${card.last4}',
                  ].join(' '),
            value: '$sign${formatMoney(card.amount, currency)}',
          ),
      ],
    );
  }
}
