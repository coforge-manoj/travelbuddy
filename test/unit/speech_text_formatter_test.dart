import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/services/speech_text_formatter.dart';

void main() {
  group('airport', () {
    test('known codes become city names', () {
      expect(SpeechTextFormatter.airport('EWR'), 'Newark');
      expect(SpeechTextFormatter.airport('ord'), 'Chicago');
      expect(SpeechTextFormatter.airport('DXB'), 'Dubai');
    });

    test('unknown codes are spelled out rather than guessed at', () {
      expect(SpeechTextFormatter.airport('ZZZ'), 'Z Z Z');
    });
  });

  group('price', () {
    test('whole amounts use the currency name', () {
      expect(SpeechTextFormatter.price(189), '189 dollars');
      expect(SpeechTextFormatter.price(45, 'GBP'), '45 pounds');
    });

    test('one unit is singular', () {
      expect(SpeechTextFormatter.price(1), '1 dollar');
    });

    test('fractional amounts are spoken as cents', () {
      expect(SpeechTextFormatter.price(45.5), '45 dollars and 50 cents');
    });

    test('unknown currencies fall back to spelled-out codes', () {
      expect(SpeechTextFormatter.price(20, 'XYZ'), '20 X Y Z');
    });
  });

  group('time', () {
    test('reads the part of day rather than AM/PM', () {
      expect(SpeechTextFormatter.time(DateTime(2026, 1, 2, 8, 15)), '8 15 in the morning');
      expect(SpeechTextFormatter.time(DateTime(2026, 1, 2, 16, 40)), '4 40 in the afternoon');
      expect(SpeechTextFormatter.time(DateTime(2026, 1, 2, 19, 0)), '7 in the evening');
      expect(SpeechTextFormatter.time(DateTime(2026, 1, 2, 23, 30)), '11 30 at night');
    });

    test('single-digit minutes get an "oh" so they are not misheard', () {
      expect(SpeechTextFormatter.time(DateTime(2026, 1, 2, 6, 5)), '6 oh 5 in the morning');
    });

    test('midnight and noon map to 12', () {
      expect(SpeechTextFormatter.time(DateTime(2026, 1, 2, 0, 0)), '12 at night');
      expect(SpeechTextFormatter.time(DateTime(2026, 1, 2, 12, 0)), '12 in the afternoon');
    });
  });

  group('relativeDay', () {
    final now = DateTime(2026, 3, 2, 9);

    test('uses relative wording for nearby days', () {
      expect(SpeechTextFormatter.relativeDay(DateTime(2026, 3, 2, 18), now: now), 'today');
      expect(SpeechTextFormatter.relativeDay(DateTime(2026, 3, 3, 6), now: now), 'tomorrow');
    });

    test('names the weekday within the week and the date beyond it', () {
      expect(SpeechTextFormatter.relativeDay(DateTime(2026, 3, 5), now: now), 'on Thursday');
      expect(SpeechTextFormatter.relativeDay(DateTime(2026, 4, 20), now: now), 'on April 20');
    });
  });

  test('codes are spelled out so letters and digits do not run together', () {
    expect(SpeechTextFormatter.code('UA482'), 'U A 4 8 2');
    expect(SpeechTextFormatter.flightNumber('fz123'), 'F Z 1 2 3');
  });

  test('seats separate the row number from the column letter', () {
    expect(SpeechTextFormatter.seat('14A'), '14 A');
    expect(SpeechTextFormatter.seat('7c'), '7 C');
  });

  group('clean', () {
    test('strips markdown markers', () {
      expect(SpeechTextFormatter.clean('**Delayed** by _20_ minutes'), 'Delayed by 20 minutes');
    });

    test('keeps link text and drops the target', () {
      expect(SpeechTextFormatter.clean('See [the map](https://x.dev)'), 'See the map');
    });

    test('speaks display glyphs instead of dropping their meaning', () {
      expect(SpeechTextFormatter.clean('EWR → ORD · PNR ABC'), 'EWR to ORD, PNR ABC');
    });

    test('removes emoji', () {
      expect(SpeechTextFormatter.clean('Seat 14A confirmed. ✅ Want bags?'),
          'Seat 14A confirmed. Want bags?');
    });
  });

  group('truncateForSpeech', () {
    test('leaves short text alone', () {
      expect(SpeechTextFormatter.truncateForSpeech('All set.'), 'All set.');
    });

    test('cuts long answers down and points at the screen', () {
      final long = 'First sentence here. Second sentence here. ${'Filler words. ' * 40}';
      final spoken = SpeechTextFormatter.truncateForSpeech(long);

      expect(spoken, startsWith('First sentence here. Second sentence here.'));
      expect(spoken, endsWith('Details are on screen.'));
      expect(spoken.length, lessThan(long.length));
    });
  });
}
