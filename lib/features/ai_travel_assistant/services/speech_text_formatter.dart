import 'package:intl/intl.dart';

/// Turns display-oriented strings into speech-ready ones.
///
/// Screen copy and spoken copy have different needs: `EWR` reads as
/// "ee double-you arr", `$189` is pronounced inconsistently across engines,
/// and emoji are either skipped or announced by name. Everything handed to
/// `VoiceService.speak` should pass through here first.
class SpeechTextFormatter {
  const SpeechTextFormatter._();

  /// Cities for the airport codes this module actually serves. Anything
  /// unknown falls back to spelled-out letters, which is still better than
  /// letting the engine guess at a three-letter word.
  static const _airportCities = <String, String>{
    'EWR': 'Newark',
    'ORD': 'Chicago',
    'JFK': 'New York',
    'LGA': 'New York La Guardia',
    'LAX': 'Los Angeles',
    'SFO': 'San Francisco',
    'DXB': 'Dubai',
    'AUH': 'Abu Dhabi',
    'SHJ': 'Sharjah',
    'LHR': 'London Heathrow',
    'LGW': 'London Gatwick',
    'CDG': 'Paris',
    'FRA': 'Frankfurt',
    'AMS': 'Amsterdam',
    'SIN': 'Singapore',
    'HKG': 'Hong Kong',
    'BOM': 'Mumbai',
    'DEL': 'Delhi',
    'BLR': 'Bangalore',
    'SYD': 'Sydney',
    'YYZ': 'Toronto',
    'BOS': 'Boston',
    'ATL': 'Atlanta',
    'DFW': 'Dallas',
    'MIA': 'Miami',
    'SEA': 'Seattle',
    'DEN': 'Denver',
  };

  static const _currencyNames = <String, (String, String)>{
    'USD': ('dollar', 'dollars'),
    'EUR': ('euro', 'euros'),
    'GBP': ('pound', 'pounds'),
    'AED': ('dirham', 'dirhams'),
    'INR': ('rupee', 'rupees'),
    'CAD': ('Canadian dollar', 'Canadian dollars'),
    'AUD': ('Australian dollar', 'Australian dollars'),
  };

  /// "EWR" to "Newark"; unknown codes to "E W R".
  static String airport(String code) {
    final normalized = code.trim().toUpperCase();
    final city = _airportCities[normalized];
    if (city != null) return city;
    return _spellOut(normalized);
  }

  /// "189 dollars", "1 dollar", "45 dollars and 50 cents".
  static String price(num amount, [String currency = 'USD']) {
    final names = _currencyNames[currency.trim().toUpperCase()];
    final whole = amount.floor();
    final fraction = ((amount - whole) * 100).round();

    if (names == null) {
      final formatted = NumberFormat.decimalPattern('en_US').format(amount);
      return '$formatted ${_spellOut(currency.toUpperCase())}';
    }

    final (singular, plural) = names;
    final unit = whole == 1 && fraction == 0 ? singular : plural;
    final wholeText = '${NumberFormat.decimalPattern('en_US').format(whole)} $unit';
    if (fraction == 0) return wholeText;
    return '$wholeText and $fraction cents';
  }

  /// "8:15 in the morning", "4:40 in the afternoon", "7 in the evening".
  static String time(DateTime when) {
    final hour24 = when.hour;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = when.minute;

    final String clock;
    if (minute == 0) {
      clock = '$hour12';
    } else if (minute < 10) {
      clock = '$hour12 oh $minute';
    } else {
      clock = '$hour12 $minute';
    }

    return '$clock ${_partOfDay(hour24)}';
  }

  /// "today", "tomorrow", "on Friday", or "on March 4" for anything further out.
  static String relativeDay(DateTime when, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final target = _dateOnly(when);
    final days = target.difference(today).inDays;

    if (days == 0) return 'today';
    if (days == 1) return 'tomorrow';
    if (days == -1) return 'yesterday';
    if (days > 1 && days < 7) return 'on ${DateFormat('EEEE').format(when)}';
    return 'on ${DateFormat('MMMM d').format(when)}';
  }

  /// "UA482" to "U A 4 8 2" — engines otherwise run the letters and digits
  /// together into an unintelligible word. Also the right treatment for
  /// PNRs, gates, and any other alphanumeric reference.
  static String code(String value) {
    final normalized = value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) return '';
    return _spellOut(normalized);
  }

  static String flightNumber(String number) => code(number);

  /// "14A" to "14 A" — row as a number, column as a letter.
  static String seat(String seatNumber) {
    final match = RegExp(r'^(\d+)\s*([A-Za-z])$').firstMatch(seatNumber.trim());
    if (match == null) return seatNumber.trim();
    return '${match.group(1)} ${match.group(2)!.toUpperCase()}';
  }

  /// Strips markdown, emoji, and display-only glyphs so the engine reads
  /// prose rather than punctuation. Safe to run on any string.
  static String clean(String text) {
    var out = text;

    out = out.replaceAllMapped(RegExp(r'\[(.*?)\]\(.*?\)'), (match) => match.group(1)!);
    out = out.replaceAll(RegExp(r'[*_`#]'), '');

    // Display glyphs that carry meaning: speak them rather than drop them.
    out = out.replaceAll('→', ' to ');
    out = out.replaceAll('·', ', ');
    out = out.replaceAll('—', ', ');
    out = out.replaceAll('–', ', ');

    out = out.replaceAll(_emoji, '');

    return out
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAllMapped(RegExp(r'\s+([,.!?])'), (match) => match.group(1)!)
        .trim();
  }

  /// Keeps spoken replies short. Long FAQ answers are readable on screen but
  /// exhausting to listen to.
  static String truncateForSpeech(String text, {int maxSentences = 2, int maxChars = 240}) {
    final cleaned = clean(text);
    if (cleaned.length <= maxChars) return cleaned;

    final sentences = RegExp(r'[^.!?]+[.!?]?').allMatches(cleaned).map((m) => m.group(0)!.trim());
    final kept = sentences.take(maxSentences).join(' ').trim();
    if (kept.isEmpty || kept.length >= cleaned.length) return cleaned;
    return '$kept Details are on screen.';
  }

  static String _partOfDay(int hour24) {
    // The small hours read as night, not morning — "12 in the morning" for
    // midnight is the kind of phrasing that makes an assistant sound wrong.
    if (hour24 < 5) return 'at night';
    if (hour24 < 12) return 'in the morning';
    if (hour24 < 17) return 'in the afternoon';
    if (hour24 < 21) return 'in the evening';
    return 'at night';
  }

  static String _spellOut(String value) => value.split('').join(' ');

  static DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

  static final _emoji = RegExp(
    '[\u{1F000}-\u{1FAFF}\u{2190}-\u{21FF}\u{2300}-\u{23FF}'
    '\u{2460}-\u{24FF}\u{25A0}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}\u{200D}]',
    unicode: true,
  );
}
