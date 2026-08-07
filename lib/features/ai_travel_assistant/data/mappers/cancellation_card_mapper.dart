import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/card_json.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/wallet_split_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/cancellation.dart';

/// Maps the `cancellation` card — sent first as a refund preview awaiting
/// confirmation, then again once the refund has gone through.
class CancellationCardMapper {
  const CancellationCardMapper._();

  static const cancellationCardType = 'cancellation';

  /// [needsConfirmation] is the turn-level flag from the `/chat` envelope:
  /// while it is set this card is still a preview, so the UI must not claim
  /// the booking is already cancelled.
  static Cancellation? fromCard(
    Map<String, dynamic> card, {
    bool needsConfirmation = false,
  }) {
    final pnr = CardJson.asString(
      CardJson.pick(card, ['pnr', 'recordLocator', 'bookingRef']),
    );
    if (pnr == null) return null;

    // Status and the settlement note live inside the refund block.
    final refundJson = CardJson.asMap(CardJson.pick(card, ['refund'])) ??
        const <String, dynamic>{};
    final status = CardJson.asString(CardJson.pick(card, ['status'])) ??
        CardJson.asString(CardJson.pick(refundJson, ['status']));
    final refund = WalletSplitMapper.fromCard(card);

    return Cancellation(
      pnr: pnr,
      isConfirmed: !needsConfirmation &&
          (status == null || !status.toLowerCase().contains('pending')),
      status: status,
      refund: refund,
      refundTotal: CardJson.asNum(
            CardJson.pick(card, ['refundTotal', 'total', 'refundAmount']),
          ) ??
          CardJson.asNum(
            CardJson.pick(refundJson, ['total', 'refundTotal']),
          ),
      penalty: CardJson.asNum(
        CardJson.pick(card, ['penalty', 'fee', 'cancellationFee']),
      ),
      currency: CardJson.asString(CardJson.pick(card, ['currency'])) ?? 'USD',
      flightNumber: CardJson.asString(
            CardJson.pick(card, ['flight_no', 'flightNumber']),
          ) ??
          '',
      reason: CardJson.asString(CardJson.pick(card, ['reason', 'note'])) ??
          CardJson.asString(CardJson.pick(refundJson, ['note', 'reason'])),
    );
  }
}
