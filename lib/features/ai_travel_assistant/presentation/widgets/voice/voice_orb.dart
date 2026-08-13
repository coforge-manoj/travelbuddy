import 'package:flutter/material.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/voice_conversation_state.dart';

/// The single control in audio mode: shows what the assistant is doing, and
/// takes a tap to interrupt.
///
/// Every phase gets its own colour and motion, because in a hands-free
/// conversation this is the only feedback the passenger has about whose turn it
/// is. A still orb while the assistant is thinking looks identical to a broken
/// one.
class VoiceOrb extends StatefulWidget {
  const VoiceOrb({
    super.key,
    required this.phase,
    required this.onTap,
    this.size = 132,
  });

  final VoicePhase phase;
  final VoidCallback onTap;
  final double size;

  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<VoiceOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  static const _brandBlue = Color(0xFF0883F9);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Color get _color => switch (widget.phase) {
        VoicePhase.listening => _brandBlue,
        VoicePhase.capturing => const Color(0xFF12B76A),
        VoicePhase.thinking || VoicePhase.preparing => const Color(0xFF7A5AF8),
        VoicePhase.speaking => const Color(0xFF0BA5EC),
        VoicePhase.recovering => const Color(0xFFF79009),
        VoicePhase.permissionDenied => const Color(0xFFF04438),
        VoicePhase.idle => const Color(0xFF98A2B3),
      };

  /// Only the phases where something is genuinely happening animate. A pulsing
  /// orb in `idle` would suggest the assistant is still listening when it is
  /// not, which is the one thing this must never imply.
  bool get _animated => switch (widget.phase) {
        VoicePhase.listening ||
        VoicePhase.capturing ||
        VoicePhase.thinking ||
        VoicePhase.preparing ||
        VoicePhase.speaking =>
          true,
        _ => false,
      };

  IconData get _icon => switch (widget.phase) {
        VoicePhase.idle => Icons.mic_none,
        VoicePhase.permissionDenied => Icons.mic_off,
        VoicePhase.speaking => Icons.graphic_eq,
        VoicePhase.thinking || VoicePhase.preparing => Icons.more_horiz,
        VoicePhase.recovering => Icons.refresh,
        _ => Icons.mic,
      };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: switch (widget.phase) {
        VoicePhase.listening || VoicePhase.capturing => 'Listening. Tap to stop.',
        VoicePhase.speaking => 'Speaking. Tap to interrupt.',
        VoicePhase.thinking || VoicePhase.preparing => 'Thinking.',
        VoicePhase.idle => 'Tap to start talking.',
        VoicePhase.recovering => 'Reconnecting.',
        VoicePhase.permissionDenied => 'Microphone unavailable.',
      },
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final t = _animated ? _pulse.value : 0.0;
            return SizedBox(
              width: widget.size,
              height: widget.size,
              child: Center(
                child: Container(
                  width: widget.size * (0.68 + 0.10 * t),
                  height: widget.size * (0.68 + 0.10 * t),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _color.withValues(alpha: 0.16 + 0.10 * t),
                    border: Border.all(color: _color, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: _color.withValues(alpha: 0.22 * t),
                        blurRadius: 28 * t,
                        spreadRadius: 6 * t,
                      ),
                    ],
                  ),
                  child: Icon(_icon, color: _color, size: widget.size * 0.26),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
