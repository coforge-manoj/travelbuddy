import 'package:intl/intl.dart';

/// Readable on-screen counterparts to [SpeechTextFormatter].
///
/// Chat bubbles should show normal times and codes ("5:05 AM", "B6935"), while
/// speech keeps "5 oh 5" / "B 6 9 3 5" for the engine. The two are allowed to
/// diverge on purpose.
class DisplayTextFormatter {
  const DisplayTextFormatter._();

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

  /// "Newark" for known codes; otherwise the code itself ("EWR").
  static String airport(String code) {
    final normalized = code.trim().toUpperCase();
    return _airportCities[normalized] ?? normalized;
  }

  /// "$189" / "€45" style when the symbol is known, else "189 USD".
  static String price(num amount, [String currency = 'USD']) {
    final code = currency.trim().toUpperCase();
    final format = NumberFormat.currency(
      locale: 'en_US',
      symbol: _symbolFor(code),
      decimalDigits: amount == amount.roundToDouble() ? 0 : 2,
    );
    if (_symbolFor(code) != null) return format.format(amount);
    final plain = NumberFormat.decimalPattern('en_US').format(amount);
    return '$plain $code';
  }

  /// "5:05 AM", "5:00 PM".
  static String time(DateTime when) => DateFormat('h:mm a').format(when);

  /// "today", "tomorrow", "Friday", or "Mar 4".
  static String relativeDay(DateTime when, {DateTime? now}) {
    final anchor = now ?? DateTime.now();
    final today = DateTime(anchor.year, anchor.month, anchor.day);
    final target = DateTime(when.year, when.month, when.day);
    final days = target.difference(today).inDays;
    if (days == 0) return 'today';
    if (days == 1) return 'tomorrow';
    if (days == -1) return 'yesterday';
    if (days > 1 && days < 7) return DateFormat('EEEE').format(when);
    return DateFormat('MMM d').format(when);
  }

  static String flightNumber(String number) => number.trim().toUpperCase();

  static String code(String value) => value.trim().toUpperCase();

  static String seat(String seatNumber) =>
      seatNumber.trim().toUpperCase().replaceAll(' ', '');

  static String? _symbolFor(String currency) => switch (currency) {
        'USD' => '\$',
        'EUR' => '€',
        'GBP' => '£',
        'INR' => '₹',
        _ => null,
      };
}
