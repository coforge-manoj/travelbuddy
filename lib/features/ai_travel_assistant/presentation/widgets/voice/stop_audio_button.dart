import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ai_travel_assistant/core/theme/app_theme.dart';

/// The stop-audio control that sits opposite the keyboard button. Its
/// equalizer bars move only while narration is actually playing, so the
/// button reads as "audio is coming out right now — tap to cut it" rather
/// than as a dead icon. Deliberately calmer than the orb: same brand blue,
/// smaller amplitude, slower cycle, no glow.
class StopAudioButton extends StatefulWidget {
  const StopAudioButton({super.key, required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  State<StopAudioButton> createState() => _StopAudioButtonState();
}

class _StopAudioButtonState extends State<StopAudioButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant StopAudioButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    // Parked at rest rather than left spinning: the button is invisible
    // between turns and an idle ticker would repaint for nothing.
    if (widget.active) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Stop audio',
      child: Semantics(
        button: true,
        label: 'Stop audio',
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  size: const Size(44, 44),
                  painter: _StopAudioPainter(progress: _controller.value),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _StopAudioPainter extends CustomPainter {
  _StopAudioPainter({required this.progress});

  final double progress;

  static const _brand = AppTheme.brandBlue;
  static const _barCount = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final t = progress * math.pi * 2;
    final discRadius = size.shortestSide * 0.41;

    // Soft tinted disc — the same family as the orb, a fraction of its weight.
    canvas.drawCircle(center, discRadius, Paint()..color = _brand.withOpacity(0.12));

    // One slow ring breathing just outside the disc.
    final ringPhase = (math.sin(t) + 1) / 2;
    canvas.drawCircle(
      center,
      discRadius + 1.5 + ringPhase * 2.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = _brand.withOpacity(0.30 * (1 - ringPhase * 0.6)),
    );

    // Equalizer bars, each offset a third of a cycle so they ripple.
    const barWidth = 3.0;
    const gap = 3.5;
    const minHeight = 6.0;
    const maxHeight = 17.0;
    final barPaint = Paint()..color = _brand;
    const totalWidth = _barCount * barWidth + (_barCount - 1) * gap;
    var x = center.dx - totalWidth / 2;

    for (var i = 0; i < _barCount; i++) {
      final phase = math.sin(t + i * (math.pi * 2 / _barCount));
      final height = minHeight + (maxHeight - minHeight) * ((phase + 1) / 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x + barWidth / 2, center.dy),
            width: barWidth,
            height: height,
          ),
          const Radius.circular(2),
        ),
        barPaint,
      );
      x += barWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _StopAudioPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
