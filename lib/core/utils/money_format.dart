/// Formats [amount] the way the chat cards show money: a currency symbol
/// where we know one, thousands separators, and cents only when they are
/// not zero (the API prices whole dollars far more often than not).
String formatMoney(num? amount, [String currency = 'USD']) {
  if (amount == null) return '—';
  final symbol = _symbols[currency.toUpperCase()];
  final isWhole = amount == amount.roundToDouble();
  final digits = _group(
    isWhole ? amount.abs().round().toString() : amount.abs().toStringAsFixed(2),
  );
  final sign = amount < 0 ? '-' : '';
  return symbol != null
      ? '$sign$symbol$digits'
      : '$sign$digits ${currency.toUpperCase()}';
}

/// Miles and other point balances — same grouping, never a currency symbol.
String formatCount(num? amount) {
  if (amount == null) return '—';
  return _group(amount.round().abs().toString());
}

const _symbols = <String, String>{
  'USD': r'$',
  'EUR': '€',
  'GBP': '£',
  'INR': '₹',
};

String _group(String digits) {
  final dot = digits.indexOf('.');
  final whole = dot == -1 ? digits : digits.substring(0, dot);
  final rest = dot == -1 ? '' : digits.substring(dot);
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
    buffer.write(whole[i]);
  }
  return '$buffer$rest';
}
