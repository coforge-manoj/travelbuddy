import 'package:equatable/equatable.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/basket.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/wallet_split.dart';

/// The `booking_confirmed` card — the PNR and how it was paid for — and
/// `booking_detail`, which is the same booking read back later. They carry
/// the same fields, so one entity backs both; [isDetail] only picks the
/// heading ("Booked" vs "Your booking").
class BookingConfirmation extends Equatable {
  const BookingConfirmation({
    required this.pnr,
    this.isDetail = false,
    this.status,
    this.passengerName,
    this.flight,
    this.cabin = '',
    this.pax = 1,
    this.seat,
    this.extras = const [],
    this.total,
    this.milesEarned,
    this.currency = 'USD',
    this.wallet,
  });

  final String pnr;
  final bool isDetail;
  final String? status;
  final String? passengerName;
  final FlightOffer? flight;
  final String cabin;
  final int pax;
  final String? seat;
  final List<BasketExtra> extras;
  final num? total;

  /// Miles this booking earned the member — the backend reports it on the
  /// confirmation, and it is the one number on the card that is a gain
  /// rather than a cost.
  final num? milesEarned;
  final String currency;
  final WalletSplit? wallet;

  @override
  List<Object?> get props => [
        pnr,
        isDetail,
        status,
        passengerName,
        flight,
        cabin,
        pax,
        seat,
        extras,
        total,
        milesEarned,
        currency,
        wallet,
      ];
}
