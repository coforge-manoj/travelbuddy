import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ai_travel_assistant/core/theme/app_theme.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_state.dart';

/// How the orb should breathe. Derived from [ChatStatus] rather than taking
/// it directly so the painting stays independent of chat plumbing.
enum VoiceOrbMode {
  idle,
  listening,
  speaking,
  busy;

  static VoiceOrbMode from(ChatStatus status) => switch (status) {
        ChatStatus.listening => VoiceOrbMode.listening,
        ChatStatus.speaking => VoiceOrbMode.speaking,
        ChatStatus.sendingMessage || ChatStatus.loadingHistory => VoiceOrbMode.busy,
        _ => VoiceOrbMode.idle,
      };
}

/// The breathing circle at the centre of the voice bar.
///
/// Driven by a [progress] value the caller animates, so a single controller
/// can keep the orb and everything around it on the same cycle.
class VoiceOrb extends StatelessWidget {
  const VoiceOrb({
    super.key,
    required this.progress,
    required this.mode,
    this.size = 88,
  });

  final double progress;
  final VoiceOrbMode mode;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _VoiceOrbPainter(progress: progress, mode: mode),
    );
  }
}

class _VoiceOrbPainter extends CustomPainter {
  _VoiceOrbPainter({required this.progress, required this.mode});

  final double progress;
  final VoiceOrbMode mode;

  static const _brand = AppTheme.brandBlue;
  static const _deep = Color(0xFF0557B8);
  static const _soft = Color(0xFF5BAEFF);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.shortestSide * 0.34;
    final t = progress * math.pi * 2;

    final breathe = switch (mode) {
      VoiceOrbMode.idle => 1 + 0.05 * math.sin(t),
      VoiceOrbMode.listening => 1 + 0.10 * math.sin(t * 1.4),
      VoiceOrbMode.speaking => 1 + 0.12 * math.sin(t * 2),
      VoiceOrbMode.busy => 1 + 0.03 * math.sin(t * 0.8),
    };

    final opacity = mode == VoiceOrbMode.busy ? 0.7 : 1.0;
    final radius = baseRadius * breathe;

    // Soft outer glow.
    final glowPaint = Paint()
      ..color = _brand.withOpacity(0.22 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(center, radius * 1.35, glowPaint);

    // Expanding ripple rings while listening / speaking.
    if (mode == VoiceOrbMode.listening || mode == VoiceOrbMode.speaking) {
      final rippleCount = mode == VoiceOrbMode.listening ? 2 : 1;
      for (var i = 0; i < rippleCount; i++) {
        final phase = (progress + i / rippleCount) % 1.0;
        final ringPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _soft.withOpacity(0.4 * (1 - phase) * opacity);
        canvas.drawCircle(center, radius * (1.1 + phase * 0.55), ringPaint);
      }
    }

    // Solid circular orb — scale only, no shape morph.
    final fill = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        radius: 1.05,
        colors: [
          Color.lerp(_soft, Colors.white, 0.45)!.withOpacity(opacity),
          _brand.withOpacity(opacity),
          _deep.withOpacity(0.98 * opacity),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, fill);

    // Soft specular highlight.
    final core = Paint()
      ..color = Colors.white.withOpacity(0.32 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(
      center.translate(-radius * 0.22, -radius * 0.26),
      radius * 0.26,
      core,
    );
  }

  @override
  bool shouldRepaint(covariant _VoiceOrbPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.mode != mode;
}
