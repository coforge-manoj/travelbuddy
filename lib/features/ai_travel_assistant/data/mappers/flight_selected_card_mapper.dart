import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/card_json.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/flight_list_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/wallet_split_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_selection.dart';

/// Maps TravelBuddy chat `flight_selected` cards into [FlightSelection].
class FlightSelectedCardMapper {
  const FlightSelectedCardMapper._();

  static const flightSelectedCardType = 'flight_selected';

  static FlightSelection? fromCard(Map<String, dynamic> card) {
    final flight = FlightListCardMapper.nestedFlightFrom(card);
    // The held flight is the card — without it there is nothing to show.
    if (flight == null) return null;

    final fare = CardJson.asMap(CardJson.pick(card, ['fare'])) ??
        const <String, dynamic>{};

    return FlightSelection(
      basketId: CardJson.asInt(CardJson.pick(card, ['basketId', 'id'])) ?? 0,
      flight: flight,
      cabin: CardJson.asString(CardJson.pick(card, ['cabin'])) ?? '',
      pax: CardJson.asInt(CardJson.pick(card, ['pax', 'passengers'])) ?? 1,
      total: CardJson.asNum(CardJson.pick(card, ['total'])) ?? flight.price,
      perPassenger:
          CardJson.asNum(CardJson.pick(fare, ['perPassenger', 'each'])),
      baseFare: CardJson.asNum(CardJson.pick(fare, ['base', 'baseFare'])),
      extrasTotal: CardJson.asNum(CardJson.pick(card, ['extrasTotal'])) ?? 0,
      currency: CardJson.asString(CardJson.pick(card, ['currency'])) ?? 'USD',
      wallet: WalletSplitMapper.fromCard(card),
    );
  }

  /// Returns the first `flight_selected` card in [cards], or `null`.
  static FlightSelection? fromCards(Object? cards) {
    for (final card in CardJson.asMapList(cards)) {
      if (CardJson.typeOf(card) != flightSelectedCardType) continue;
      return fromCard(card);
    }
    return null;
  }
}
