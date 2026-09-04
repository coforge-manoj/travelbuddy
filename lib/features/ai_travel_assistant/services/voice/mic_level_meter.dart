/// Turns the recognizer's raw sound-level callbacks into something an
/// animation can be driven from.
///
/// Deliberately pure — no plugin, no timers, no Flutter — so the behaviour that
/// decides how the orb feels can be tested directly rather than inferred from a
/// device.
///
/// Three separate problems sit between `onSoundLevelChange` and a radius:
///
/// **Range.** The scale is not portable and not fully known: `speech_to_text`
/// documents iOS as decibels and says outright that it has not determined what
/// the Android value means. So [add] clamps to a window and normalizes, and the
/// window is a constructor parameter — a device reporting outside it saturates
/// at a full-size orb rather than drawing a radius off the end of the widget.
/// Expect [minDb]/[maxDb] to need tuning against a real device per platform.
///
/// **Jitter.** Raw samples strobe between syllables. Smoothing is *asymmetric*
/// — see [attack] and [release] — which is the single thing that makes this
/// read as a voice rather than a flickering light.
///
/// **Rate.** Callbacks arrive at roughly 10-20Hz against a 60-120Hz display, so
/// [value] is a target to interpolate *towards*, not a radius to draw. The orb
/// lerps to it each frame; reading it directly gives visible stair-stepping.
class MicLevelMeter {
  MicLevelMeter({
    this.minDb = -2,
    this.maxDb = 10,
    this.attack = 0.5,
    this.release = 0.12,
  })  : assert(maxDb > minDb, 'the level window must be non-empty'),
        assert(attack > 0 && attack <= 1, 'attack is an EWMA weight'),
        assert(release > 0 && release <= 1, 'release is an EWMA weight');

  /// The bottom of the level window, normalized to 0.
  final double minDb;

  /// The top of the level window, normalized to 1.
  final double maxDb;

  /// How fast the meter rises. High, so the orb moves on the first syllable
  /// rather than a beat behind it.
  final double attack;

  /// How fast the meter falls. Much slower than [attack] on purpose.
  ///
  /// Speech is full of gaps — between words, between syllables, at every stop
  /// consonant. Falling as fast as it rises makes the orb strobe on those gaps,
  /// which reads as broken rather than responsive. Symmetric smoothing slow
  /// enough not to strobe would instead lag the onset, so the orb starts moving
  /// after the passenger has already begun talking. Asymmetric is what audio
  /// meters do, and it is most of why this feels alive.
  final double release;

  double _value = 0;

  /// The smoothed level, 0..1. A *target* — see the class doc.
  double get value => _value;

  /// Feeds one raw sample from the recognizer and returns the new [value].
  double add(double raw) {
    // Checked before clamping, not after: `num.clamp` orders with `compareTo`,
    // which ranks NaN above every finite value, so a NaN sample clamps to the
    // *top* of the window and slams the orb to full scale. Treated as silence
    // instead.
    if (raw.isNaN) return decay();

    final target = ((raw - minDb) / (maxDb - minDb)).clamp(0.0, 1.0);
    final weight = target > _value ? attack : release;
    _value += weight * (target - _value);
    return _value;
  }

  /// Decays towards silence without a sample.
  ///
  /// For the gap between the last callback and the microphone actually
  /// closing: without it the meter holds whatever it last heard, and the orb
  /// sits inflated at the size of the passenger's final word.
  double decay() {
    _value += release * (0 - _value);
    return _value;
  }

  /// Back to silence, immediately. Called when the microphone closes.
  void reset() => _value = 0;

  /// Whether the meter is close enough to zero to stop animating.
  bool get isSilent => _value < 0.01;
}
