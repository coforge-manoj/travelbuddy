import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/card_json.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/member_wallet.dart';

/// Reads the standalone `wallet` card — the member's balances, not a payment
/// split. See [MemberWallet] for why this is not [WalletSplitMapper].
class MemberWalletMapper {
  const MemberWalletMapper._();

  static const walletCardType = 'wallet';

  /// Returns `null` when the card carries nothing worth drawing, so the
  /// caller falls back to the reply text.
  static MemberWallet? fromCard(Map<String, dynamic> card) {
    final wallet = MemberWallet(
      miles: CardJson.asNum(CardJson.pick(card, ['miles', 'milesBalance'])),
      voucher: _voucher(CardJson.pick(card, ['voucher'])),
      card: _card(CardJson.pick(card, ['card', 'paymentCard'])),
      tier: CardJson.asString(CardJson.pick(card, ['tier', 'tierName'])),
      loyaltyPoints:
          CardJson.asNum(CardJson.pick(card, ['loyaltyPoints', 'points'])),
    );
    return wallet.isEmpty ? null : wallet;
  }

  /// The live payload sends `voucher: null` for a member without one, so an
  /// absent voucher must stay absent rather than becoming an empty row.
  static WalletVoucherBalance? _voucher(Object? value) {
    // A bare number is tolerated in case the backend ever flattens this to
    // just an amount.
    final amount = CardJson.asNum(value);
    if (amount != null) return WalletVoucherBalance(amount: amount);

    final json = CardJson.asMap(value);
    if (json == null) return null;
    final voucher = WalletVoucherBalance(
      code: CardJson.asString(CardJson.pick(json, ['code', 'id'])),
      amount: CardJson.asNum(
        CardJson.pick(json, ['amount', 'value', 'available', 'balance']),
      ),
    );
    return (voucher.code == null && voucher.amount == null) ? null : voucher;
  }

  static WalletCardOnFile? _card(Object? value) {
    final json = CardJson.asMap(value);
    if (json == null) return null;
    final card = WalletCardOnFile(
      brand: CardJson.asString(CardJson.pick(json, ['brand', 'network'])),
      last4: CardJson.asString(CardJson.pick(json, ['last4', 'lastFour'])),
    );
    return (card.brand == null && card.last4 == null) ? null : card;
  }
}
