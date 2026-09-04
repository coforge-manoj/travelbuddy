import 'package:equatable/equatable.dart';

/// The `wallet` card: what the member has *available* to pay with — a miles
/// balance, a voucher if they hold one, the card on file, and their tier.
///
/// Deliberately separate from [WalletSplit], which is the near-identically
/// named block embedded in `basket` / `flight_selected` / `booking_confirmed`.
/// That one describes amounts **applied** to a specific payment; this one is
/// a **balance**, with no transaction attached. They share a word and nothing
/// else, so merging them would mean a class where half the fields are always
/// null.
class MemberWallet extends Equatable {
  const MemberWallet({
    this.miles,
    this.voucher,
    this.card,
    this.tier,
    this.loyaltyPoints,
  });

  /// Redeemable AAdvantage miles.
  final num? miles;

  /// Travel voucher on file. Null for members without one — which is the
  /// common case, so the UI must skip the row rather than render a zero.
  final WalletVoucherBalance? voucher;

  /// The payment card on file, identified only by brand and last four.
  final WalletCardOnFile? card;

  /// Loyalty tier, e.g. "Platinum Pro".
  final String? tier;

  /// Loyalty points — the status-qualifying figure, distinct from [miles],
  /// which are the spendable ones.
  final num? loyaltyPoints;

  /// True when there is nothing worth drawing, so the caller can fall back to
  /// the reply text instead of showing an empty card.
  bool get isEmpty =>
      miles == null && voucher == null && card == null && tier == null;

  @override
  List<Object?> get props => [miles, voucher, card, tier, loyaltyPoints];
}

class WalletVoucherBalance extends Equatable {
  const WalletVoucherBalance({this.code, this.amount});

  final String? code;
  final num? amount;

  @override
  List<Object?> get props => [code, amount];
}

class WalletCardOnFile extends Equatable {
  const WalletCardOnFile({this.brand, this.last4});

  final String? brand;
  final String? last4;

  @override
  List<Object?> get props => [brand, last4];
}
