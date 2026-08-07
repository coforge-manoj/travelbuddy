import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/card_json.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/boarding_pass.dart';

/// Maps the `boarding_pass` card issued by "check me in".
class BoardingPassCardMapper {
  const BoardingPassCardMapper._();

  static const boardingPassCardType = 'boarding_pass';

  static BoardingPass? fromCard(Map<String, dynamic> card) {
    // A flight object may carry the route when the card itself does not.
    final flight = CardJson.asMap(CardJson.pick(card, ['flight'])) ??
        const <String, dynamic>{};

    final pnr = CardJson.asString(
      CardJson.pick(card, ['pnr', 'recordLocator', 'bookingRef']),
    );
    final flightNumber = CardJson.asString(
          CardJson.pick(card, ['flight_no', 'flightNumber']),
        ) ??
        CardJson.asString(CardJson.pick(flight, ['flight_no'])) ??
        '';
    // Nothing identifies the pass without one of these two.
    if (pnr == null && flightNumber.isEmpty) return null;

    return BoardingPass(
      pnr: pnr ?? '',
      passengerName: CardJson.asString(
            CardJson.pick(card, ['passenger', 'passengerName', 'name']),
          ) ??
          '',
      flightNumber: flightNumber,
      origin: CardJson.asString(CardJson.pick(card, ['origin', 'from'])) ??
          CardJson.asString(CardJson.pick(flight, ['origin'])) ??
          '',
      destination:
          CardJson.asString(CardJson.pick(card, ['dest', 'destination', 'to'])) ??
              CardJson.asString(CardJson.pick(flight, ['dest'])) ??
              '',
      date: CardJson.asString(
        CardJson.pick(card, ['date', 'flight_date', 'departureDate']),
      ),
      departureTime: CardJson.asString(
            CardJson.pick(card, ['dep', 'departure', 'departureTime']),
          ) ??
          CardJson.asString(CardJson.pick(flight, ['dep'])),
      boardingTime: CardJson.asString(
        CardJson.pick(card, ['boardingTime', 'boarding', 'boards']),
      ),
      gate: CardJson.asString(CardJson.pick(card, ['gate'])),
      terminal: CardJson.asString(CardJson.pick(card, ['terminal'])),
      seat: CardJson.asString(CardJson.pick(card, ['seat', 'seatNumber'])),
      boardingGroup: CardJson.asString(
        CardJson.pick(card, ['group', 'boardingGroup', 'zone']),
      ),
      cabin: CardJson.asString(CardJson.pick(card, ['cabin'])) ?? '',
      barcode: CardJson.asString(
        CardJson.pick(card, ['barcode', 'barcodeData', 'qr']),
      ),
      sequenceNumber: CardJson.asString(
        CardJson.pick(card, ['sequence', 'sequenceNumber', 'seq']),
      ),
    );
  }
}
