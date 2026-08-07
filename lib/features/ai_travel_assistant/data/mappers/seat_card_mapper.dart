import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/card_json.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/cabin_seat_map.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat_confirmation.dart';

/// Maps the `seat_map` and `seat_confirmed` cards.
class SeatCardMapper {
  const SeatCardMapper._();

  static const seatMapCardType = 'seat_map';
  static const seatConfirmedCardType = 'seat_confirmed';

  /// Accepts either shape the map can arrive in: cabins each holding their
  /// own seats, or one flat `seats` array with the cabin named per seat.
  static CabinSeatMap? fromSeatMapCard(Map<String, dynamic> card) {
    final currency =
        CardJson.asString(CardJson.pick(card, ['currency'])) ?? 'USD';
    final flightNumber = CardJson.asString(
          CardJson.pick(card, ['flight_no', 'flightNumber', 'flight']),
        ) ??
        '';
    final currentSeat = CardJson.asString(
      CardJson.pick(card, ['currentSeat', 'seat', 'currentSeatNumber']),
    );

    final cabins = <SeatCabin>[];

    final cabinsRaw = CardJson.asMapList(CardJson.pick(card, ['cabins']));
    for (final cabinJson in cabinsRaw) {
      final name = CardJson.asString(
            CardJson.pick(cabinJson, ['name', 'cabin', 'label']),
          ) ??
          '';
      final seats = _seatsFrom(
        CardJson.pick(cabinJson, ['seats', 'rows']),
      );
      if (seats.isNotEmpty) cabins.add(SeatCabin(name: name, seats: seats));
    }

    if (cabins.isEmpty) {
      final flat = _seatsFrom(CardJson.pick(card, ['seats', 'rows']));
      if (flat.isEmpty) return null;
      final cabinName =
          CardJson.asString(CardJson.pick(card, ['cabin'])) ?? 'Cabin';
      cabins.add(SeatCabin(name: cabinName, seats: flat));
    }

    return CabinSeatMap(
      cabins: cabins,
      flightNumber: flightNumber,
      currency: currency,
      currentSeat: currentSeat,
    );
  }

  static SeatConfirmation? fromSeatConfirmedCard(Map<String, dynamic> card) {
    final seat = CardJson.asString(
      CardJson.pick(card, ['seat', 'seatNumber', 'newSeat', 'seat_no']),
    );
    if (seat == null) return null;

    return SeatConfirmation(
      seatNumber: seat,
      previousSeatNumber: CardJson.asString(
        CardJson.pick(card, ['previous', 'previousSeat', 'from', 'oldSeat']),
      ),
      cabin: CardJson.asString(CardJson.pick(card, ['cabin'])) ?? '',
      flightNumber: CardJson.asString(
            CardJson.pick(card, ['flight_no', 'flightNumber']),
          ) ??
          '',
      price:
          CardJson.asNum(CardJson.pick(card, ['price', 'amount', 'fee'])) ?? 0,
      currency: CardJson.asString(CardJson.pick(card, ['currency'])) ?? 'USD',
      type: CardJson.asString(CardJson.pick(card, ['type_label', 'seatType'])) ??
          _typeFromAttributes(CardJson.asMap(CardJson.pick(card, ['attributes']))),
    );
  }

  /// The confirmation describes the seat with flags rather than a label —
  /// `{window: true, aisle: false, extraLegroom: false}` — so this turns
  /// the ones that are set into the phrase the card shows.
  static String? _typeFromAttributes(Map<String, dynamic>? attributes) {
    if (attributes == null) return null;
    const labels = {
      'window': 'window',
      'aisle': 'aisle',
      'middle': 'middle',
      'extraLegroom': 'extra legroom',
      'exitRow': 'exit row',
    };
    final set = labels.entries
        .where((e) => CardJson.asBool(CardJson.pick(attributes, [e.key])))
        .map((e) => e.value)
        .toList();
    return set.isEmpty ? null : set.join(' · ');
  }

  /// Reads seats from either a plain list of seat objects or a list of row
  /// objects that each nest their own `seats`.
  static List<CabinSeat> _seatsFrom(Object? raw) {
    final entries = CardJson.asMapList(raw);
    final seats = <CabinSeat>[];

    for (final entry in entries) {
      final nested = CardJson.pick(entry, ['seats']);
      if (nested is List) {
        final rowNumber = CardJson.asInt(CardJson.pick(entry, ['row', 'number']));
        for (final seatJson in CardJson.asMapList(nested)) {
          final seat = _seatFromJson(seatJson, fallbackRow: rowNumber);
          if (seat != null) seats.add(seat);
        }
        continue;
      }
      final seat = _seatFromJson(entry);
      if (seat != null) seats.add(seat);
    }

    return seats;
  }

  static CabinSeat? _seatFromJson(
    Map<String, dynamic> json, {
    int? fallbackRow,
  }) {
    final seatNumber = CardJson.asString(
      CardJson.pick(json, ['seat', 'seatNumber', 'seat_no', 'number', 'id']),
    );
    if (seatNumber == null) return null;

    // `12A` splits into the row and column the grid is laid out on; the
    // backend usually sends them separately too, and those win when present.
    final match = RegExp(r'^(\d+)\s*([A-Za-z]+)$').firstMatch(seatNumber);
    final row = CardJson.asInt(CardJson.pick(json, ['row'])) ??
        fallbackRow ??
        int.tryParse(match?.group(1) ?? '') ??
        0;
    final column =
        CardJson.asString(CardJson.pick(json, ['column', 'col', 'letter'])) ??
            match?.group(2)?.toUpperCase() ??
            '';

    // `available` is the common spelling; an `availability`/`status` string
    // is treated as available only when it actually says so.
    final availableFlag = CardJson.asBoolOrNull(
      CardJson.pick(json, ['available', 'isAvailable', 'free']),
    );
    final statusText = CardJson.asString(
      CardJson.pick(json, ['availability', 'status', 'state']),
    )?.toLowerCase();

    return CabinSeat(
      seatNumber: seatNumber,
      row: row,
      column: column,
      available: availableFlag ??
          (statusText == null ? true : statusText == 'available'),
      price: CardJson.asNum(
            CardJson.pick(json, ['price', 'priceDelta', 'amount', 'fee']),
          ) ??
          0,
      // The map flags each seat with flat booleans rather than a label.
      type: CardJson.asString(CardJson.pick(json, ['type', 'position'])) ??
          _typeFromAttributes(json),
      isExitRow: CardJson.asBool(
        CardJson.pick(json, ['isExitRow', 'exitRow', 'exit']),
      ),
    );
  }
}
