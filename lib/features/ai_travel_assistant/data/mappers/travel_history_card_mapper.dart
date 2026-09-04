import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/card_json.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/travel_history.dart';

/// Maps the `travel_history` card — the member's flown record.
class TravelHistoryCardMapper {
  const TravelHistoryCardMapper._();

  static const travelHistoryCardType = 'travel_history';

  static TravelHistory? fromCard(Map<String, dynamic> card) {
    final flights = CardJson.asMapList(
      CardJson.pick(card, ['flights', 'items', 'history']),
    ).map(_flightFrom).whereType<TravelHistoryFlight>().toList(growable: false);

    final count = CardJson.asInt(CardJson.pick(card, ['count', 'total']));
    // A history with neither a headline count nor a single row has nothing
    // to say that the reply sentence does not already cover.
    if (count == null && flights.isEmpty) return null;

    return TravelHistory(
      count: count ?? flights.length,
      scope: CardJson.asString(CardJson.pick(card, ['scope', 'period'])) ?? '',
      totalSpend: CardJson.asNum(
        CardJson.pick(card, ['totalSpendUSD', 'totalSpend', 'spend']),
      ),
      currency: CardJson.asString(CardJson.pick(card, ['currency'])) ?? 'USD',
      flights: flights,
    );
  }

  static TravelHistoryFlight? _flightFrom(Map<String, dynamic> json) {
    final flightNo = CardJson.asString(
      CardJson.pick(json, ['flightNo', 'flight_no', 'flightNumber']),
    );
    if (flightNo == null) return null;

    // The history card names the route as one `DFW→LHR` string rather than
    // separate origin/dest fields, but accept those too.
    final route = CardJson.asString(CardJson.pick(json, ['route'])) ??
        _routeFromParts(json);

    return TravelHistoryFlight(
      flightNumber: flightNo,
      date: CardJson.asString(
            CardJson.pick(json, ['date', 'flight_date', 'flownOn']),
          ) ??
          '',
      route: route ?? '',
      cabin: CardJson.asString(CardJson.pick(json, ['cabin'])) ?? '',
      fare: CardJson.asNum(
        CardJson.pick(json, ['fareUSD', 'fare', 'fare_usd', 'price']),
      ),
      milesEarned: CardJson.asNum(
        CardJson.pick(json, ['milesEarned', 'miles']),
      ),
      seat: CardJson.asString(CardJson.pick(json, ['seat', 'seatNumber'])),
    );
  }

  static String? _routeFromParts(Map<String, dynamic> json) {
    final origin = CardJson.asString(CardJson.pick(json, ['origin', 'from']));
    final dest =
        CardJson.asString(CardJson.pick(json, ['dest', 'destination', 'to']));
    if (origin == null || dest == null) return null;
    return '$origin→$dest';
  }
}
