import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/card_json.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/upgrade_quote.dart';

/// Maps the `upgrade_quote` card — cash and miles price for moving cabin,
/// plus whether the member can cover it.
class UpgradeQuoteCardMapper {
  const UpgradeQuoteCardMapper._();

  static const upgradeQuoteCardType = 'upgrade_quote';

  static UpgradeQuote? fromCard(Map<String, dynamic> card) {
    final toCabin = CardJson.asString(
      CardJson.pick(card, ['to', 'toCabin', 'targetCabin', 'cabin']),
    );
    // Without the destination cabin the quote has nothing to name.
    if (toCabin == null) return null;

    // Price can arrive flat (`cash`/`miles`) or nested under `price`.
    final price = CardJson.asMap(CardJson.pick(card, ['price', 'quote'])) ??
        const <String, dynamic>{};
    // The live quote nests the miles option under `payWithMiles` and calls
    // the cash price `difference` — it is the fare gap, not a new fare.
    final milesBlock =
        CardJson.asMap(CardJson.pick(card, ['payWithMiles', 'miles']));

    return UpgradeQuote(
      fromCabin: CardJson.asString(
            CardJson.pick(card, ['from', 'fromCabin', 'currentCabin']),
          ) ??
          '',
      toCabin: toCabin,
      cash: CardJson.asNum(
            CardJson.pick(card, ['difference', 'cash', 'amount', 'price']),
          ) ??
          CardJson.asNum(CardJson.pick(price, ['cash', 'amount'])),
      // `miles` is a bare number on a flat card and a block with its own
      // balance when the backend expands it.
      miles: milesBlock == null
          ? CardJson.asNum(CardJson.pick(card, ['miles', 'milesPrice'])) ??
              CardJson.asNum(CardJson.pick(price, ['miles']))
          : CardJson.asNum(
              CardJson.pick(
                milesBlock,
                ['miles', 'required', 'price', 'amount', 'cost'],
              ),
            ),
      currency: CardJson.asString(CardJson.pick(card, ['currency'])) ?? 'USD',
      milesBalance: CardJson.asNum(
            CardJson.pick(card, ['milesBalance', 'balance']),
          ) ??
          (milesBlock == null
              ? null
              : CardJson.asNum(CardJson.pick(milesBlock, ['balance']))),
      affordable: CardJson.asBoolOrNull(
            CardJson.pick(card, ['affordable', 'canAfford', 'affordability']),
          ) ??
          (milesBlock == null
              ? null
              : CardJson.asBoolOrNull(
                  CardJson.pick(milesBlock, ['affordable', 'canAfford']),
                )),
      flightNumber: CardJson.asString(
            CardJson.pick(card, ['flight_no', 'flightNumber']),
          ) ??
          '',
      pnr: CardJson.asString(CardJson.pick(card, ['pnr'])),
      seatsAvailable: CardJson.asInt(
        CardJson.pick(card, ['seatsAvailable', 'seats_left', 'available']),
      ),
    );
  }
}
