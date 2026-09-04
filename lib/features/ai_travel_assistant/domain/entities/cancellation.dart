import 'package:equatable/equatable.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/wallet_split.dart';

/// The `cancellation` card — sent twice: first as the preview alongside
/// `needsConfirmation: true`, then again once the refund has been made.
/// [isConfirmed] is what tells the two apart, so the second card does not
/// read as another thing to approve.
class Cancellation extends Equatable {
  const Cancellation({
    required this.pnr,
    this.isConfirmed = false,
    this.status,
    this.refund,
    this.refundTotal,
    this.penalty,
    this.currency = 'USD',
    this.flightNumber = '',
    this.reason,
  });

  final String pnr;
  final bool isConfirmed;
  final String? status;

  /// The refund split back across the methods the booking was paid with.
  final WalletSplit? refund;
  final num? refundTotal;

  /// Cancellation fee withheld from the refund, if any.
  final num? penalty;
  final String currency;
  final String flightNumber;
  final String? reason;

  /// Falls back to summing the split when the backend does not total it.
  num? get effectiveRefundTotal => refundTotal ?? refund?.total;

  @override
  List<Object?> get props => [
        pnr,
        isConfirmed,
        status,
        refund,
        refundTotal,
        penalty,
        currency,
        flightNumber,
        reason,
      ];
}
