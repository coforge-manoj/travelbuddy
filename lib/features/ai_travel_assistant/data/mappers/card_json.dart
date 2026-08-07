/// Shared, deliberately forgiving readers for TravelBuddy chat card JSON.
///
/// The `/chat` payload mixes conventions — flight objects are snake_case
/// (`flight_no`, `cabin_prices`) while card-level fields are camelCase
/// (`basketId`, `extrasTotal`) — and the card contract can gain fields
/// without a client release. Every mapper therefore reads through [pick],
/// which accepts several spellings for the same value, so a rename on the
/// backend degrades one field rather than dropping a whole card.
class CardJson {
  const CardJson._();

  /// First non-null value in [json] under any of [keys], also trying the
  /// snake_case/camelCase counterpart of each key.
  static Object? pick(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      for (final candidate in {key, _snake(key), _camel(key)}) {
        final value = json[candidate];
        if (value != null) return value;
      }
    }
    return null;
  }

  static String? asString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static num? asNum(Object? value) {
    if (value is num) return value;
    if (value is String) {
      // Tolerates money already formatted for display, e.g. "$1,205.00".
      return num.tryParse(value.replaceAll(RegExp(r'[^0-9.\-]'), ''));
    }
    return null;
  }

  static int? asInt(Object? value) {
    final n = asNum(value);
    return n?.toInt();
  }

  static bool asBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == '1' || lower == 'true' || lower == 'yes';
    }
    return false;
  }

  /// `null` unless [value] is explicitly boolean-ish — lets a card
  /// distinguish "the backend said false" from "the backend said nothing",
  /// which matters for flags like `affordable`.
  static bool? asBoolOrNull(Object? value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == '1' || lower == 'true' || lower == 'yes') return true;
      if (lower == '0' || lower == 'false' || lower == 'no') return false;
    }
    return null;
  }

  static Map<String, dynamic>? asMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  /// Every map in [value], skipping anything else — the API pads truncated
  /// example arrays with strings like `"... 6 more flights"`.
  static List<Map<String, dynamic>> asMapList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
  }

  static List<String> asStringList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  /// The `type` discriminator every card carries, lower-cased.
  static String? typeOf(Map<String, dynamic> card) =>
      asString(card['type'])?.toLowerCase();

  static String _snake(String key) => key
      .replaceAllMapped(
        RegExp(r'[A-Z]'),
        (m) => '_${m.group(0)!.toLowerCase()}',
      )
      .replaceAll(RegExp(r'^_'), '');

  static String _camel(String key) {
    final parts = key.split('_').where((p) => p.isNotEmpty).toList();
    if (parts.length < 2) return key;
    return parts.first +
        parts
            .skip(1)
            .map((p) => p[0].toUpperCase() + p.substring(1))
            .join();
  }
}
