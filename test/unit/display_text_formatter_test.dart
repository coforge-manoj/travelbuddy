import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/services/display_text_formatter.dart';

void main() {
  test('times use a normal clock, not speech "oh"', () {
    expect(DisplayTextFormatter.time(DateTime(2026, 1, 2, 5, 5)), '5:05 AM');
    expect(DisplayTextFormatter.time(DateTime(2026, 1, 2, 17, 0)), '5:00 PM');
  });

  test('prices use a currency symbol when known', () {
    expect(DisplayTextFormatter.price(165), r'$165');
    expect(DisplayTextFormatter.price(45.5, 'EUR'), contains('45'));
  });

  test('codes and seats stay compact', () {
    expect(DisplayTextFormatter.flightNumber('b6935'), 'B6935');
    expect(DisplayTextFormatter.seat('14 a'), '14A');
    expect(DisplayTextFormatter.code('b12'), 'B12');
  });
}
