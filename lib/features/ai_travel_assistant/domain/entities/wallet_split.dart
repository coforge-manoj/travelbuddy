import 'package:equatable/equatable.dart';

/// How a price is (or would be) settled across the member's voucher, miles
/// and card. The same `wallet` block appears on `flight_selected`, `basket`
/// and `booking_confirmed`, and — inverted — as the refund split on
/// `cancellation`, so it lives on its own rather than on any one card.
class WalletSplit extends Equatable {
  const WalletSplit({this.voucher, this.miles, this.card});

  final WalletVoucher? voucher;
  final WalletMiles? miles;
  final WalletCardPayment? card;

  /// True when nothing is actually applied — a wallet block the UI can skip
  /// rather than render as an empty "Payment applied" section.
  bool get isEmpty =>
      (voucher?.applied ?? 0) == 0 &&
      (miles?.applied ?? 0) == 0 &&
      (card?.amount ?? 0) == 0;

  num get total =>
      (voucher?.applied ?? 0) + (miles?.applied ?? 0) + (card?.amount ?? 0);

  @override
  List<Object?> get props => [voucher, miles, card];
}

class WalletVoucher extends Equatable {
  const WalletVoucher({
    required this.code,
    required this.available,
    required this.applied,
  });

  final String code;
  final num available;
  final num applied;

  @override
  List<Object?> get props => [code, available, applied];
}

class WalletMiles extends Equatable {
  const WalletMiles({
    required this.balance,
    required this.rate,
    required this.valueUSD,
    required this.applied,
    required this.milesUsed,
  });

  final num balance;

  /// Cash value of one mile, as quoted by the backend.
  final num rate;
  final num valueUSD;

  /// Cash value of the miles actually applied to this transaction.
  final num applied;
  final num milesUsed;

  @override
  List<Object?> get props => [balance, rate, valueUSD, applied, milesUsed];
}

class WalletCardPayment extends Equatable {
  const WalletCardPayment({
    required this.brand,
    required this.last4,
    required this.amount,
  });

  final String brand;
  final String last4;
  final num amount;

  @override
  List<Object?> get props => [brand, last4, amount];
}
