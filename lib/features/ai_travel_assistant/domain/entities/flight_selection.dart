import 'package:equatable/equatable.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/wallet_split.dart';

/// Basket snapshot from a TravelBuddy `flight_selected` card — the flight
/// held after "take the cheapest one", before any extras are added. Once
/// extras land the backend sends a `basket` card instead (see [Basket]).
class FlightSelection extends Equatable {
  const FlightSelection({
    required this.basketId,
    required this.flight,
    required this.cabin,
    required this.pax,
    required this.total,
    this.perPassenger,
    this.baseFare,
    this.extrasTotal = 0,
    this.currency = 'USD',
    this.wallet,
  });

  final int basketId;
  final FlightOffer flight;
  final String cabin;
  final int pax;
  final num total;
  final num? perPassenger;
  final num? baseFare;
  final num extrasTotal;
  final String currency;
  final WalletSplit? wallet;

  @override
  List<Object?> get props => [
        basketId,
        flight,
        cabin,
        pax,
        total,
        perPassenger,
        baseFare,
        extrasTotal,
        currency,
        wallet,
      ];
}
