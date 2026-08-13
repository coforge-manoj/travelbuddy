import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/voice_conversation_state.dart';

/// The single control in audio mode: shows what the assistant is doing, and
/// takes a tap to interrupt.
///
/// **Form carries the meaning; colour only reinforces it.** The orb is the one
/// piece of feedback a passenger has about whose turn it is, and the phone is
/// usually face-up on a table being read out of the corner of an eye. Six
/// phases distinguished only by hue — three of which are neighbouring blues —
/// are six phases that look alike. So each stage of the conversation gets a
/// distinct *shape* of motion: the orb breathes while it is taking input,
/// orbits while it is working, and ripples while it is talking.
///
/// While the passenger is speaking the motion comes from their actual voice
/// (see [level]), not from a clock. An orb that pulses on a timer regardless of
/// what the microphone hears is what reads as "it isn't listening to me".
class VoiceOrb extends StatefulWidget {
  const VoiceOrb({
    super.key,
    required this.phase,
    required this.onTap,
    this.level,
    this.size = 132,
  });

  final VoicePhase phase;
  final VoidCallback onTap;

  /// The passenger's smoothed microphone level, 0..1 — see `MicLevelMeter`.
  ///
  /// A [ValueListenable] rather than a plain value on purpose: it updates at
  /// roughly 10-20Hz, and routing that through the widget tree would rebuild
  /// the page and every card on it several times a second for a number only
  /// this widget reads.
  ///
  /// Null is fine, and so is a listenable that never moves off zero — a
  /// platform that does not report levels just gets the breathe it blends into.
  final ValueListenable<double>? level;

  final double size;

  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<VoiceOrb> with TickerProviderStateMixin {
  /// The clock every period-based form reads.
  ///
  /// A [Ticker] rather than a repeating [AnimationController] because the forms
  /// have periods that do not share a common multiple (1100, 1400, 1600, 2200).
  /// Driving them off a controller that wraps would put a visible jump in every
  /// motion whose period does not divide the controller's duration.
  late final Ticker _ticker = createTicker(_onTick);

  /// How "awake" the orb is, 0..1.
  ///
  /// Multiplied into every amplitude, so entering a still phase eases the
  /// motion out over 300ms. Previously the animation value was simply read as
  /// zero the moment the phase stopped animating, which made the orb visibly
  /// pop to a smaller size mid-breath.
  late final AnimationController _activity = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: _motionFor(widget.phase).form == _Form.still ? 0 : 1,
  );

  final ValueNotifier<Duration> _elapsed = ValueNotifier(Duration.zero);

  /// What the orb is currently drawing, as opposed to what the microphone last
  /// reported.
  ///
  /// Levels arrive at ~10-20Hz against a 60-120Hz display, so drawing them
  /// directly stair-steps. This chases [VoiceOrb.level] on every frame.
  final ValueNotifier<double> _displayLevel = ValueNotifier(0);

  Duration _lastTick = Duration.zero;

  static const _brandBlue = Color(0xFF0883F9);

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(VoiceOrb old) {
    super.didUpdateWidget(old);
    if (old.phase != widget.phase) _syncTicker();
  }

  /// Runs the clock only while something is moving.
  ///
  /// The orb sits in `permissionDenied` — a terminal phase — for as long as the
  /// passenger leaves it there, and previously kept rebuilding at the display's
  /// refresh rate to draw an unchanging circle.
  void _syncTicker() {
    final still = _motionFor(widget.phase).form == _Form.still;
    if (still) {
      _activity.reverse();
    } else {
      _activity.forward();
      if (!_ticker.isActive) {
        _lastTick = Duration.zero;
        _ticker.start();
      }
    }
  }

  void _onTick(Duration elapsed) {
    // Clamped so a frame dropped to a background pause cannot jump the level
    // chase to its target in one step.
    final dt = ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _lastTick = elapsed;
    _elapsed.value = elapsed;

    final target = widget.level?.value ?? 0.0;
    final gap = target - _displayLevel.value;
    if (gap.abs() > 0.0005) {
      // Exponential chase against elapsed time rather than a fixed per-frame
      // fraction, so the orb responds identically at 60 and 120Hz.
      _displayLevel.value += gap * (1 - math.exp(-dt / 0.06));
    }

    // Nothing is moving and nothing is fading out: stop until the phase
    // changes.
    if (_motionFor(widget.phase).form == _Form.still && _activity.value == 0) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _activity.dispose();
    _elapsed.dispose();
    _displayLevel.dispose();
    super.dispose();
  }

  Color get _color => switch (widget.phase) {
        VoicePhase.listening => _brandBlue,
        VoicePhase.capturing => const Color(0xFF12B76A),
        VoicePhase.thinking || VoicePhase.preparing => const Color(0xFF7A5AF8),
        // Coloured as speech, not as thinking: it is the assistant's voice, and
        // the orb changing while it talks is what tells the passenger to wait
        // rather than answer.
        VoicePhase.acknowledging ||
        VoicePhase.speaking =>
          const Color(0xFF0BA5EC),
        VoicePhase.recovering => const Color(0xFFF79009),
        VoicePhase.permissionDenied => const Color(0xFFF04438),
        VoicePhase.idle => const Color(0xFF98A2B3),
      };

  IconData get _icon => switch (widget.phase) {
        VoicePhase.idle => Icons.mic_none,
        VoicePhase.permissionDenied => Icons.mic_off,
        VoicePhase.acknowledging || VoicePhase.speaking => Icons.graphic_eq,
        VoicePhase.thinking || VoicePhase.preparing => Icons.more_horiz,
        VoicePhase.recovering => Icons.refresh,
        _ => Icons.mic,
      };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      // Announced on change, because in a hands-free conversation the phase is
      // the entire interface — a screen-reader user who is not told the
      // assistant has started listening has been told nothing.
      liveRegion: true,
      label: switch (widget.phase) {
        VoicePhase.listening || VoicePhase.capturing => 'Listening. Tap to stop.',
        VoicePhase.speaking => 'Speaking. Tap to interrupt.',
        VoicePhase.acknowledging => 'Answering, and still working. Tap to '
            'interrupt.',
        VoicePhase.thinking || VoicePhase.preparing => 'Thinking.',
        VoicePhase.idle => 'Tap to start talking.',
        VoicePhase.recovering => 'Reconnecting.',
        VoicePhase.permissionDenied => 'Microphone unavailable.',
      },
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: _color),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          builder: (context, color, _) {
            final resolved = color ?? _color;
            return SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _OrbPainter(
                        phase: widget.phase,
                        color: resolved,
                        elapsed: _elapsed,
                        activity: _activity,
                        level: _displayLevel,
                      ),
                    ),
                  ),
                  Icon(_icon, color: resolved, size: widget.size * 0.26),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The shape of a phase's motion. Three of these do the communicative work:
/// breathe and level are input, orbit is work, ripple is output.
enum _Form { breathe, level, orbit, ripple, sweep, still }

@immutable
class _Motion {
  const _Motion(this.form, {this.periodMs = 1400, this.amplitude = 0});

  final _Form form;
  final int periodMs;

  /// How far the core swells, as a fraction of its radius.
  final double amplitude;
}

/// Tuned against the 132px orb. The amplitudes are fractions of the core
/// radius, so they hold if [VoiceOrb.size] changes.
_Motion _motionFor(VoicePhase phase) => switch (phase) {
      // Slow and shallow: the assistant is waiting, and should look like it is
      // waiting rather than like it is working.
      VoicePhase.listening =>
        const _Motion(_Form.breathe, periodMs: 2200, amplitude: 0.05),
      VoicePhase.capturing => const _Motion(_Form.level, amplitude: 0.22),
      VoicePhase.thinking ||
      VoicePhase.preparing =>
        const _Motion(_Form.orbit, periodMs: 1100),
      VoicePhase.acknowledging ||
      VoicePhase.speaking =>
        const _Motion(_Form.ripple, periodMs: 1600),
      VoicePhase.recovering => const _Motion(_Form.sweep, periodMs: 1400),
      VoicePhase.idle || VoicePhase.permissionDenied => const _Motion(_Form.still),
    };

/// How far the core is swollen, as a multiple of its resting radius.
///
/// Pulled out of the painter so the motion can be asserted directly: a canvas
/// gives a widget test nothing to compare, and this is the part worth pinning —
/// that the orb follows the voice, and that it comes to rest exactly at 1.0
/// rather than near it.
///
/// [activity] is the 0..1 wake-up factor; at 0 this returns exactly 1.0, which
/// is what makes leaving a phase ease out instead of snapping.
@visibleForTesting
double orbCoreScale({
  required VoicePhase phase,
  required double elapsedMs,
  required double level,
  required double activity,
}) {
  final motion = _motionFor(phase);
  final act = Curves.easeInOut.transform(activity.clamp(0.0, 1.0));

  switch (motion.form) {
    case _Form.breathe:
      return 1 + motion.amplitude * _eased(elapsedMs, motion.periodMs) * act;

    case _Form.level:
      final lvl = level.clamp(0.0, 1.0);
      // The breathe is blended back in as the level falls, so a pause between
      // words — or a platform that never reports a level at all — still leaves
      // the orb moving. A motionless orb while the microphone is open is the
      // one thing this must never look like.
      final breath = _eased(elapsedMs, 2200);
      return 1 + (motion.amplitude * lvl + 0.05 * (1 - lvl) * breath) * act;

    case _Form.orbit:
    case _Form.ripple:
    case _Form.sweep:
    case _Form.still:
      return 1;
  }
}

/// A triangle wave over [periodMs], eased. Linear would read mechanical —
/// nothing in nature changes direction at a constant speed.
double _eased(double ms, int periodMs) {
  final t = (ms % periodMs) / periodMs;
  return Curves.easeInOut.transform(1 - (t * 2 - 1).abs());
}

/// How lit the core is, 0..1 — brightens with the motion so the orb reads as
/// alive rather than merely larger.
double _glow(_Motion motion, double ms, double level, double act) {
  return switch (motion.form) {
    _Form.breathe => _eased(ms, motion.periodMs) * act,
    _Form.level =>
      math.max(level.clamp(0.0, 1.0), _eased(ms, 2200) * 0.35) * act,
    _Form.orbit => 0.4 * act,
    _Form.ripple => 0.35 * act,
    _Form.sweep => 0.3 * act,
    _Form.still => 0,
  };
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({
    required this.phase,
    required this.color,
    required this.elapsed,
    required this.activity,
    required this.level,
  })  : motion = _motionFor(phase),
        super(repaint: Listenable.merge([elapsed, activity, level]));

  final VoicePhase phase;
  final _Motion motion;
  final Color color;
  final ValueListenable<Duration> elapsed;
  final Animation<double> activity;
  final ValueListenable<double> level;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final base = size.shortestSide * 0.34;
    final act = Curves.easeInOut.transform(activity.value);
    final ms = elapsed.value.inMilliseconds.toDouble();
    final lvl = level.value;

    final radius = base *
        orbCoreScale(
          phase: phase,
          elapsedMs: ms,
          level: lvl,
          activity: activity.value,
        );
    _core(canvas, centre, radius, _glow(motion, ms, lvl, act));

    switch (motion.form) {
      case _Form.breathe:
      case _Form.level:
      case _Form.still:
        break;

      case _Form.orbit:
        final rotation = (ms % motion.periodMs) / motion.periodMs * 2 * math.pi;
        final dot = Paint()..color = color;
        for (var i = 0; i < 3; i++) {
          final angle = rotation + i * 2 * math.pi / 3;
          canvas.drawCircle(
            centre +
                Offset(math.cos(angle), math.sin(angle)) * base * 1.42 * act,
            size.shortestSide * 0.026,
            dot,
          );
        }

      case _Form.ripple:
        // Two rings half a period apart, so one is always leaving as the other
        // arrives. Drawn as strokes rather than the blurred shadow this
        // replaces: an animated `boxShadow` re-rasterizes a gaussian every
        // frame, which is among the most expensive things to put on a screen
        // that stays up for the length of a conversation.
        //
        // Deliberately on a fixed beat, not driven by the audio: real output
        // amplitude is not available — the player reports position, not
        // levels — and a faked envelope gets caught out at every pause and
        // chunk boundary. The distinct *form* is what says "the assistant is
        // talking"; it does not need to lip-sync to say it.
        for (var i = 0; i < 2; i++) {
          final p = ((ms % motion.periodMs) / motion.periodMs + i * 0.5) % 1;
          canvas.drawCircle(
            centre,
            base * (1 + 0.62 * p * act),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = color.withValues(alpha: (1 - p) * 0.55 * act),
          );
        }

      case _Form.sweep:
        final from = (ms % motion.periodMs) / motion.periodMs * 2 * math.pi;
        canvas.drawArc(
          Rect.fromCircle(center: centre, radius: base * 1.42),
          from,
          1.25 * act,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round
            ..color = color,
        );
    }
  }

  /// The filled, outlined disc every form is built around. [glow] brightens the
  /// fill with the motion so the orb reads as lit rather than merely larger.
  void _core(Canvas canvas, Offset centre, double radius, double glow) {
    canvas.drawCircle(
      centre,
      radius,
      Paint()..color = color.withValues(alpha: 0.16 + 0.10 * glow),
    );
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
  }

  /// A triangle wave over [periodMs], eased. Linear would read mechanical —
  /// nothing in nature changes direction at a constant speed.
  double _eased(double ms, int periodMs) {
    final t = (ms % periodMs) / periodMs;
    return Curves.easeInOut.transform(1 - (t * 2 - 1).abs());
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.phase != phase || old.color != color;
}
