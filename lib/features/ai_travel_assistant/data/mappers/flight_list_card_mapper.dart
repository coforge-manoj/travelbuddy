import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/card_json.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';

/// Maps TravelBuddy chat `flight_list` cards into domain [FlightOffer]s for
/// [ChatMessageType.flightOffersCard].
class FlightListCardMapper {
  const FlightListCardMapper._();

  static const flightListCardType = 'flight_list';

  /// Returns the offers on a single `flight_list` card.
  static List<FlightOffer> fromCard(Map<String, dynamic> card) {
    final flights = card['flights'];
    if (flights is! List) return const [];

    final origin = card['origin']?.toString() ?? '';
    final dest = card['dest']?.toString() ?? '';
    final date = card['date']?.toString() ?? '';

    return flights
        .whereType<Map>()
        .map(
          (flight) => fromFlightJson(
            Map<String, dynamic>.from(flight),
            cardOrigin: origin,
            cardDest: dest,
            cardDate: date,
          ),
        )
        .whereType<FlightOffer>()
        .toList(growable: false);
  }

  /// Returns offers from the first `flight_list` card in [cards], or an empty
  /// list when none are present / parseable.
  static List<FlightOffer> fromCards(Object? cards) {
    for (final card in CardJson.asMapList(cards)) {
      if (CardJson.typeOf(card) != flightListCardType) continue;
      return fromCard(card);
    }
    return const [];
  }

  /// The flight a basket / booking / boarding-pass card refers to.
  ///
  /// Some cards nest it under `flight`; others carry the flight's fields
  /// flat on the card itself — `GET /bookings/current` returns the flat
  /// form (`flight_no`, `dep_time`, `arr_time`, …), so both are read here
  /// rather than at each call site.
  static FlightOffer? nestedFlightFrom(Map<String, dynamic> card) {
    final flight = CardJson.asMap(CardJson.pick(card, ['flight'])) ??
        (CardJson.pick(card, ['flight_no']) == null ? null : card);
    if (flight == null) return null;

    return fromFlightJson(
      flight,
      cardOrigin: CardJson.asString(CardJson.pick(card, ['origin', 'from'])) ?? '',
      cardDest:
          CardJson.asString(CardJson.pick(card, ['dest', 'destination', 'to'])) ??
              '',
      cardDate:
          CardJson.asString(CardJson.pick(card, ['date', 'flight_date'])) ?? '',
    );
  }

  /// Parses one API flight object. Returns `null` when required fields are
  /// missing so a bad row does not break the whole card.
  static FlightOffer? fromFlightJson(
    Map<String, dynamic> json, {
    String cardOrigin = '',
    String cardDest = '',
    String cardDate = '',
  }) {
    // Search results say `flight_no`; a booking's nested flight says
    // `flightNo` and dates it with `date` rather than `flight_date`.
    final flightNo =
        CardJson.asString(CardJson.pick(json, ['flight_no', 'flightNumber']));
    if (flightNo == null) return null;

    final origin =
        CardJson.asString(CardJson.pick(json, ['origin'])) ?? cardOrigin;
    final dest = CardJson.asString(CardJson.pick(json, ['dest'])) ?? cardDest;
    final flightDate =
        CardJson.asString(CardJson.pick(json, ['flight_date', 'date'])) ??
            cardDate;

    // Search results say `dep`/`arr`; a stored booking says
    // `dep_time`/`arr_time` for the same thing.
    final dep = CardJson.asString(CardJson.pick(json, ['dep', 'dep_time'])) ?? '';
    final arr = CardJson.asString(CardJson.pick(json, ['arr', 'arr_time'])) ?? '';
    // A stored booking omits `arrives_next_day` entirely, so an overnight
    // leg (dep 16:21, arr 01:26) would otherwise land before it took off
    // and report a negative duration. An arrival earlier than the departure
    // can only mean the next day.
    final arrivesNextDay =
        _asBool(json['arrives_next_day']) || _wrapsPastMidnight(dep, arr);

    final departureTime = _combineDateAndTime(flightDate, dep);
    final arrivalTime = _combineDateAndTime(
      flightDate,
      arr,
      addDays: arrivesNextDay ? 1 : 0,
    );
    if (departureTime == null || arrivalTime == null) return null;

    final price = _asNum(CardJson.pick(json, ['price', 'fare_usd'])) ?? 0;
    final cabinPrices = _parseCabinPrices(json['cabin_prices']);

    return FlightOffer(
      id: flightNo,
      airline: _airlineFromFlightNo(flightNo),
      flightNumber: flightNo,
      origin: origin,
      destination: dest,
      departureTime: departureTime,
      arrivalTime: arrivalTime,
      price: price,
      aircraft: json['aircraft']?.toString(),
      seatsLeft: _asInt(json['seats_left']),
      durationLabel: json['duration']?.toString(),
      recommended: _asBool(json['recommended']),
      lowest: _asBool(json['lowest']),
      arrivesNextDay: arrivesNextDay,
      cabinPrices: cabinPrices,
    );
  }

  /// True when [arr] is earlier in the day than [dep] — both are local
  /// `HH:mm` at their own airport, so this is a heuristic for an overnight
  /// leg, used only when the payload does not say outright.
  static bool _wrapsPastMidnight(String dep, String arr) {
    final depMinutes = _minutesOfDay(dep);
    final arrMinutes = _minutesOfDay(arr);
    if (depMinutes == null || arrMinutes == null) return false;
    return arrMinutes < depMinutes;
  }

  static int? _minutesOfDay(String time) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(time.trim());
    if (match == null) return null;
    return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
  }

  static String _airlineFromFlightNo(String flightNo) {
    final match = RegExp(r'^[A-Za-z]+').firstMatch(flightNo);
    return match?.group(0)?.toUpperCase() ?? flightNo;
  }

  static DateTime? _combineDateAndTime(
    String date,
    String time, {
    int addDays = 0,
  }) {
    if (date.isEmpty || time.isEmpty) return null;
    final normalizedTime = time.length == 5 ? '$time:00' : time;
    final parsed = DateTime.tryParse('${date}T$normalizedTime');
    if (parsed == null) return null;
    return addDays == 0 ? parsed : parsed.add(Duration(days: addDays));
  }

  static Map<String, num> _parseCabinPrices(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, num>{};
    raw.forEach((key, value) {
      final n = _asNum(value);
      if (n != null) out[key.toString()] = n;
    });
    return out;
  }

  static bool _asBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == '1' || lower == 'true' || lower == 'yes';
    }
    return false;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static num? _asNum(Object? value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '');
  }
}
