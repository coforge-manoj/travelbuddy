import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice/mic_level_meter.dart';

/// The meter decides how the orb feels, so the behaviour is pinned here rather
/// than judged on a device. The asymmetry between attack and release is the
/// whole point — a symmetric meter either strobes on the gaps between syllables
/// or lags the start of a word.
void main() {
  group('normalization', () {
    test('maps the level window onto 0..1', () {
      // One sample cannot reach the target — the EWMA moves a fraction of the
      // way — so drive it to convergence to see the mapping itself.
      final meter = MicLevelMeter();
      for (var i = 0; i < 40; i++) {
        meter.add(10);
      }
      expect(meter.value, closeTo(1.0, 0.01));
    });

    test('clamps below the window instead of going negative', () {
      final meter = MicLevelMeter();
      meter.add(-50);
      expect(meter.value, 0.0);
    });

    test('clamps above the window instead of overshooting', () {
      final meter = MicLevelMeter();
      for (var i = 0; i < 40; i++) {
        meter.add(999);
      }
      expect(meter.value, lessThanOrEqualTo(1.0));
    });

    test('a NaN sample cannot poison the meter', () {
      // One NaN through the EWMA would make every subsequent frame draw a
      // radius of NaN for the rest of the session.
      final meter = MicLevelMeter();
      for (var i = 0; i < 10; i++) {
        meter.add(8);
      }
      final before = meter.value;
      meter.add(double.nan);

      expect(meter.value.isNaN, isFalse);
      expect(meter.value, lessThan(before));
    });
  });

  group('asymmetric smoothing', () {
    test('rises faster than it falls', () {
      // The load-bearing property. Same distance travelled, measured in steps.
      final rising = MicLevelMeter();
      var stepsUp = 0;
      while (rising.value < 0.5 && stepsUp < 100) {
        rising.add(10);
        stepsUp++;
      }

      final falling = MicLevelMeter();
      for (var i = 0; i < 60; i++) {
        falling.add(10);
      }
      var stepsDown = 0;
      while (falling.value > 0.5 && stepsDown < 100) {
        falling.add(-2);
        stepsDown++;
      }

      expect(stepsUp, lessThan(stepsDown));
    });

    test('a single loud sample moves the meter most of a step immediately', () {
      // Attack 0.5: the orb should be visibly moving on the first syllable,
      // not a beat behind it.
      final meter = MicLevelMeter();
      meter.add(10);
      expect(meter.value, closeTo(0.5, 0.001));
    });

    test('a gap between syllables barely moves it', () {
      // Release 0.12: this is what stops the orb strobing on stop consonants.
      final meter = MicLevelMeter();
      for (var i = 0; i < 60; i++) {
        meter.add(10);
      }
      meter.add(-2);
      expect(meter.value, greaterThan(0.85));
    });
  });

  group('silence', () {
    test('decay walks towards zero without a sample', () {
      final meter = MicLevelMeter();
      for (var i = 0; i < 60; i++) {
        meter.add(10);
      }
      final before = meter.value;
      meter.decay();

      expect(meter.value, lessThan(before));
      expect(meter.value, greaterThan(0));
    });

    test('reset drops to silence at once', () {
      // The microphone closing must not leave the orb inflated at the size of
      // the passenger's last word.
      final meter = MicLevelMeter();
      for (var i = 0; i < 60; i++) {
        meter.add(10);
      }

      meter.reset();

      expect(meter.value, 0.0);
      expect(meter.isSilent, isTrue);
    });

    test('isSilent is false while a voice is present', () {
      final meter = MicLevelMeter();
      meter.add(10);
      expect(meter.isSilent, isFalse);
    });
  });
}
