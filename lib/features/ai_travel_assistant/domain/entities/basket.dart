import 'package:equatable/equatable.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/wallet_split.dart';

/// The `basket` card: fare, extras, discounts, total and the wallet split.
/// Sent after "add wifi and a bag", and again as the preview alongside
/// `needsConfirmation: true` when the passenger says "book it".
class Basket extends Equatable {
  const Basket({
    required this.basketId,
    required this.total,
    this.flight,
    this.cabin = '',
    this.pax = 1,
    this.baseFare,
    this.perPassenger,
    this.taxes,
    this.extras = const [],
    this.extrasTotal = 0,
    this.discounts = const [],
    this.currency = 'USD',
    this.wallet,
  });

  final int basketId;

  /// Absent on a basket the backend sends as a pure price preview.
  final FlightOffer? flight;
  final String cabin;
  final int pax;

  final num? baseFare;
  final num? perPassenger;
  final num? taxes;

  final List<BasketExtra> extras;
  final num extrasTotal;
  final List<BasketDiscount> discounts;

  final num total;
  final String currency;
  final WalletSplit? wallet;

  num get discountTotal =>
      discounts.fold<num>(0, (sum, discount) => sum + discount.amount);

  @override
  List<Object?> get props => [
        basketId,
        flight,
        cabin,
        pax,
        baseFare,
        perPassenger,
        taxes,
        extras,
        extrasTotal,
        discounts,
        total,
        currency,
        wallet,
      ];
}

/// One ancillary on the basket. [included] marks an extra the cabin already
/// covers — it still appears on the card, priced at zero, because "included
/// with Flagship Business" is the answer to "why wasn't I charged".
class BasketExtra extends Equatable {
  const BasketExtra({
    required this.name,
    this.code,
    this.price = 0,
    this.quantity = 1,
    this.included = false,
    this.description,
  });

  final String name;
  final String? code;
  final num price;
  final int quantity;
  final bool included;
  final String? description;

  @override
  List<Object?> get props =>
      [name, code, price, quantity, included, description];
}

class BasketDiscount extends Equatable {
  const BasketDiscount({required this.label, required this.amount});

  final String label;

  /// Always positive — the UI renders the minus sign.
  final num amount;

  @override
  List<Object?> get props => [label, amount];
}
