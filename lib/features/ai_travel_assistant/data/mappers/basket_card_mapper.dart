import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/card_json.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/flight_list_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/wallet_split_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/basket.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/extras_catalogue.dart';

/// Maps the `basket` and `extras_list` cards.
class BasketCardMapper {
  const BasketCardMapper._();

  static const basketCardType = 'basket';
  static const extrasListCardType = 'extras_list';

  static Basket? fromCard(Map<String, dynamic> card) {
    final fare = CardJson.asMap(CardJson.pick(card, ['fare', 'pricing'])) ??
        const <String, dynamic>{};
    final cabin = CardJson.asString(CardJson.pick(card, ['cabin'])) ?? '';
    final extras = extrasFrom(
      CardJson.pick(card, ['extras', 'items']),
      cabin: cabin,
    );

    final total = CardJson.asNum(
      CardJson.pick(card, ['total', 'grandTotal', 'totalDue']),
    );
    // A basket with no total at all is a card we cannot price, and the reply
    // sentence already stands on its own — better to skip it than to render
    // a $0 basket.
    if (total == null) return null;

    return Basket(
      basketId: CardJson.asInt(CardJson.pick(card, ['basketId', 'id'])) ?? 0,
      flight: FlightListCardMapper.nestedFlightFrom(card),
      cabin: cabin,
      pax: CardJson.asInt(
            CardJson.pick(card, ['pax', 'passengers', 'paxCount']),
          ) ??
          1,
      baseFare: CardJson.asNum(
        CardJson.pick(fare, ['base', 'baseFare', 'subtotal']),
      ),
      perPassenger: CardJson.asNum(
        CardJson.pick(fare, ['perPassenger', 'each']),
      ),
      taxes: CardJson.asNum(
        CardJson.pick(fare, ['taxes', 'tax', 'taxesAndFees']),
      ),
      extras: extras,
      extrasTotal: CardJson.asNum(CardJson.pick(card, ['extrasTotal'])) ??
          extras.fold<num>(0, (sum, e) => sum + e.price * e.quantity),
      discounts: _discountsFrom(CardJson.pick(card, ['discounts'])),
      total: total,
      currency: CardJson.asString(CardJson.pick(card, ['currency'])) ?? 'USD',
      wallet: WalletSplitMapper.fromCard(card),
    );
  }

  static ExtrasCatalogue? extrasCatalogueFromCard(Map<String, dynamic> card) {
    final cabin = CardJson.asString(CardJson.pick(card, ['cabin'])) ?? '';
    final extras = extrasFrom(
      CardJson.pick(card, ['extras', 'items', 'options', 'catalogue']),
      cabin: cabin,
    );
    if (extras.isEmpty) return null;

    return ExtrasCatalogue(
      extras: extras,
      cabin: cabin,
      currency: CardJson.asString(CardJson.pick(card, ['currency'])) ?? 'USD',
    );
  }

  /// Shared by `basket`, `extras_list` and `booking_confirmed`, all of which
  /// carry the same ancillary rows.
  ///
  /// [cabin] is what the extras are being priced for. The catalogue marks
  /// inclusion two ways — a flat `included` flag, and an `includedIn` list
  /// of the cabins that already cover the extra — so without the cabin an
  /// Admirals Club pass would be offered at $79 to a Flagship Business
  /// passenger who already has it.
  static List<BasketExtra> extrasFrom(Object? raw, {String cabin = ''}) {
    return CardJson.asMapList(raw)
        .map((json) => _extraFromJson(json, cabin: cabin))
        .whereType<BasketExtra>()
        .toList(growable: false);
  }

  static BasketExtra? _extraFromJson(
    Map<String, dynamic> json, {
    String cabin = '',
  }) {
    final name = CardJson.asString(
      CardJson.pick(json, ['name', 'label', 'title']),
    );
    final code = CardJson.asString(CardJson.pick(json, ['code', 'id', 'sku']));
    if (name == null && code == null) return null;

    final includedIn = CardJson.asStringList(CardJson.pick(json, ['includedIn']));
    final included = CardJson.asBool(
          CardJson.pick(json, ['included', 'isIncluded', 'complimentary']),
        ) ||
        (cabin.isNotEmpty &&
            includedIn.any((c) => c.toLowerCase() == cabin.toLowerCase()));

    return BasketExtra(
      name: name ?? code!,
      code: code,
      // A basket line prices itself as `unit` × `qty` (with `total`
      // pre-computed); the standalone catalogue calls the same number
      // `price`. Falling back to `total ÷ qty` keeps the card's own
      // multiplication honest if only the line total is sent.
      price: CardJson.asNum(
            CardJson.pick(json, ['unit', 'price', 'amount', 'cost', 'listPrice']),
          ) ??
          _unitFromTotal(json) ??
          0,
      quantity:
          CardJson.asInt(CardJson.pick(json, ['qty', 'quantity', 'count'])) ??
              1,
      included: included,
      // `descr` is the catalogue's own spelling. Only a genuine second line
      // — not the value already used as the name — earns the extra row.
      description: name == null
          ? null
          : CardJson.asString(
              CardJson.pick(json, ['descr', 'description', 'detail']),
            ),
    );
  }

  static num? _unitFromTotal(Map<String, dynamic> json) {
    final total = CardJson.asNum(CardJson.pick(json, ['total']));
    final qty = CardJson.asInt(CardJson.pick(json, ['qty', 'quantity']));
    if (total == null) return null;
    return (qty == null || qty <= 0) ? total : total / qty;
  }

  static List<BasketDiscount> _discountsFrom(Object? raw) {
    return CardJson.asMapList(raw)
        .map((json) {
          // `reason` is what the basket calls it — "Executive Platinum bag
          // waiver". Without it the whole discount row goes missing and the
          // card's arithmetic stops adding up.
          final label = CardJson.asString(
            CardJson.pick(json, ['reason', 'label', 'name', 'description', 'code']),
          );
          final amount = CardJson.asNum(
            CardJson.pick(json, ['amount', 'value', 'discount']),
          );
          if (label == null || amount == null) return null;
          return BasketDiscount(label: label, amount: amount.abs());
        })
        .whereType<BasketDiscount>()
        .toList(growable: false);
  }
}
