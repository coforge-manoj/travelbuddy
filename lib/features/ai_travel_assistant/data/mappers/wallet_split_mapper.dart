import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/card_json.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/wallet_split.dart';

/// Reads the `wallet` / `payment` / `refund` block shared by the basket,
/// booking and cancellation cards into a [WalletSplit].
class WalletSplitMapper {
  const WalletSplitMapper._();

  /// Looks for the block under any of the names the cards use for it, so a
  /// caller can just hand over the whole card.
  static WalletSplit? fromCard(Map<String, dynamic> card) {
    final raw = CardJson.asMap(
      CardJson.pick(
        card,
        ['wallet', 'payment', 'paid', 'paymentSplit', 'refund'],
      ),
    );
    return raw == null ? null : fromJson(raw);
  }

  /// Reads both shapes the backend uses for this block.
  ///
  /// A basket's `wallet` describes the methods themselves — `voucher` and
  /// `card` are objects with a code and a last-4. A booking's `payment`
  /// describes only the amounts, so `voucher` and `card` come back as bare
  /// numbers and miles as `{used, value}`. Treating the number form as
  /// "no payment" is what left the confirmed booking with no split at all.
  static WalletSplit? fromJson(Map<String, dynamic> json) {
    // A refund names the same three methods differently again —
    // `milesRestored` and `voucherReissued`, both bare numbers.
    final voucherRaw = CardJson.pick(json, ['voucher', 'voucherReissued']);
    final milesRaw = CardJson.pick(json, ['miles', 'milesRestored']);
    final cardRaw = CardJson.pick(json, ['card', 'creditCard']);

    final voucher = CardJson.asMap(voucherRaw);
    final miles = CardJson.asMap(milesRaw);
    final card = CardJson.asMap(cardRaw);

    final voucherAmount = voucher == null ? CardJson.asNum(voucherRaw) : null;
    final milesAmount = miles == null ? CardJson.asNum(milesRaw) : null;
    final cardAmount = card == null ? CardJson.asNum(cardRaw) : null;

    if (voucher == null &&
        miles == null &&
        card == null &&
        voucherAmount == null &&
        milesAmount == null &&
        cardAmount == null) {
      return null;
    }

    return WalletSplit(
      voucher: voucher != null
          ? WalletVoucher(
              code: CardJson.asString(CardJson.pick(voucher, ['code'])) ?? '',
              available:
                  CardJson.asNum(CardJson.pick(voucher, ['available'])) ?? 0,
              applied: CardJson.asNum(
                    CardJson.pick(voucher, ['applied', 'amount']),
                  ) ??
                  0,
            )
          : voucherAmount == null
              ? null
              : WalletVoucher(
                  code: '',
                  available: voucherAmount,
                  applied: voucherAmount,
                ),
      miles: miles == null
          ? (milesAmount == null || milesAmount == 0
              ? null
              // A bare number here is miles put back, not a cash value.
              : WalletMiles(
                  balance: 0,
                  rate: 0,
                  valueUSD: 0,
                  applied: 0,
                  milesUsed: milesAmount,
                ))
          : WalletMiles(
              balance: CardJson.asNum(CardJson.pick(miles, ['balance'])) ?? 0,
              rate: CardJson.asNum(CardJson.pick(miles, ['rate'])) ?? 0,
              valueUSD:
                  CardJson.asNum(CardJson.pick(miles, ['valueUSD', 'value'])) ??
                      0,
              // `value` is the cash the miles covered on a booking; on a
              // basket that same number is `applied`.
              applied: CardJson.asNum(
                    CardJson.pick(miles, ['applied', 'amount', 'value']),
                  ) ??
                  0,
              milesUsed: CardJson.asNum(
                    CardJson.pick(miles, ['milesUsed', 'used', 'quantity']),
                  ) ??
                  0,
            ),
      card: card != null
          ? WalletCardPayment(
              brand: CardJson.asString(CardJson.pick(card, ['brand'])) ?? '',
              last4: CardJson.asString(
                    CardJson.pick(card, ['last4', 'lastFour']),
                  ) ??
                  '',
              amount: CardJson.asNum(
                    CardJson.pick(card, ['amount', 'applied', 'charged']),
                  ) ??
                  0,
            )
          : cardAmount == null
              ? null
              : WalletCardPayment(brand: '', last4: '', amount: cardAmount),
    );
  }
}
