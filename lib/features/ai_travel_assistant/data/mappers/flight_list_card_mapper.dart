import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';

/// Maps TravelBuddy chat `flight_list` cards into domain [FlightOffer]s for
/// [ChatMessageType.flightOffersCard].
class FlightListCardMapper {
  const FlightListCardMapper._();

  static const searchFlightsTool = 'search_flights';
  static const searchFlightToolAlias = 'search_flight';
  static const flightListCardType = 'flight_list';

  static bool isSearchFlightsTool(String? tool) {
    final normalized = tool?.trim().toLowerCase();
    return normalized == searchFlightsTool ||
        normalized == searchFlightToolAlias;
  }

  /// Returns offers from the first `flight_list` card in [cards], or an empty
  /// list when none are present / parseable.
  static List<FlightOffer> fromCards(Object? cards) {
    if (cards is! List) return const [];

    for (final raw in cards) {
      if (raw is! Map) continue;
      final card = Map<String, dynamic>.from(raw);
      if (card['type']?.toString() != flightListCardType) continue;

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

    return const [];
  }

  /// Parses one API flight object. Returns `null` when required fields are
  /// missing so a bad row does not break the whole card.
  static FlightOffer? fromFlightJson(
    Map<String, dynamic> json, {
    String cardOrigin = '',
    String cardDest = '',
    String cardDate = '',
  }) {
    final flightNo = json['flight_no']?.toString().trim();
    if (flightNo == null || flightNo.isEmpty) return null;

    final origin = (json['origin']?.toString().trim().isNotEmpty ?? false)
        ? json['origin'].toString()
        : cardOrigin;
    final dest = (json['dest']?.toString().trim().isNotEmpty ?? false)
        ? json['dest'].toString()
        : cardDest;
    final flightDate =
        (json['flight_date']?.toString().trim().isNotEmpty ?? false)
            ? json['flight_date'].toString()
            : cardDate;

    final dep = json['dep']?.toString() ?? '';
    final arr = json['arr']?.toString() ?? '';
    final arrivesNextDay = _asBool(json['arrives_next_day']);

    final departureTime = _combineDateAndTime(flightDate, dep);
    final arrivalTime = _combineDateAndTime(
      flightDate,
      arr,
      addDays: arrivesNextDay ? 1 : 0,
    );
    if (departureTime == null || arrivalTime == null) return null;

    final price = _asNum(json['price']) ?? 0;
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
