import 'package:equatable/equatable.dart';

/// The `upgrade_quote` card: what moving up a cabin costs in cash and in
/// miles, and whether the member can actually cover it.
class UpgradeQuote extends Equatable {
  const UpgradeQuote({
    required this.toCabin,
    this.fromCabin = '',
    this.cash,
    this.miles,
    this.currency = 'USD',
    this.milesBalance,
    this.affordable,
    this.flightNumber = '',
    this.pnr,
    this.seatsAvailable,
  });

  final String fromCabin;
  final String toCabin;

  /// Cash price of the upgrade; `null` when it is miles-only.
  final num? cash;

  /// Miles price of the upgrade; `null` when it is cash-only.
  final num? miles;
  final String currency;
  final num? milesBalance;

  /// The backend's own affordability verdict. `null` when it did not say —
  /// the card then falls back to comparing [miles] against [milesBalance].
  final bool? affordable;

  final String flightNumber;
  final String? pnr;
  final int? seatsAvailable;

  /// Whether the member's miles cover the quote, from whichever signal is
  /// available.
  bool? get canAffordWithMiles {
    if (affordable != null) return affordable;
    if (miles == null || milesBalance == null) return null;
    return milesBalance! >= miles!;
  }

  @override
  List<Object?> get props => [
        fromCabin,
        toCabin,
        cash,
        miles,
        currency,
        milesBalance,
        affordable,
        flightNumber,
        pnr,
        seatsAvailable,
      ];
}
