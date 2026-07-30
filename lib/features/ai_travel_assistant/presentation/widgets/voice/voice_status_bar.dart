import 'package:flutter/material.dart';

import 'package:ai_travel_assistant/core/theme/app_theme.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_state.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/voice/stop_audio_button.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/voice/voice_orb.dart';

/// Bottom surface shown while talkback is on: a breathing circular orb
/// that reflects idle / listening / speaking, flanked by two calm, static
/// buttons — stop-the-audio on the left, keyboard escape hatch on the right.
///
/// The orb itself only ever means "start / stop listening". Silencing the
/// assistant is [onStopSpeaking]'s job: one control that both starts and stops
/// listening *and* cuts narration is ambiguous the moment both are in play.
class VoiceStatusBar extends StatefulWidget {
  const VoiceStatusBar({
    super.key,
    required this.status,
    required this.onOrbTap,
    required this.onStopSpeaking,
    required this.onPreferTyping,
    this.enabled = true,
  });

  final ChatStatus status;
  final VoidCallback onOrbTap;
  final VoidCallback onStopSpeaking;
  final VoidCallback onPreferTyping;
  final bool enabled;

  @override
  State<VoiceStatusBar> createState() => _VoiceStatusBarState();
}

class _VoiceStatusBarState extends State<VoiceStatusBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _durationFor(widget.status))
      ..repeat();
  }

  @override
  void didUpdateWidget(covariant VoiceStatusBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _controller.duration = _durationFor(widget.status);
      if (!_controller.isAnimating) _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Duration _durationFor(ChatStatus status) => switch (status) {
        ChatStatus.listening => const Duration(milliseconds: 1400),
        ChatStatus.speaking => const Duration(milliseconds: 900),
        ChatStatus.sendingMessage || ChatStatus.loadingHistory =>
          const Duration(milliseconds: 3200),
        _ => const Duration(milliseconds: 2500),
      };

  String get _label => switch (widget.status) {
        ChatStatus.listening => 'Listening…',
        ChatStatus.speaking => 'Speaking — stop at left, or tap orb to talk',
        ChatStatus.sendingMessage || ChatStatus.loadingHistory => 'Working on it…',
        _ => 'Tap to speak',
      };

  @override
  Widget build(BuildContext context) {
    final mode = VoiceOrbMode.from(widget.status);
    final isSpeaking = widget.status == ChatStatus.speaking;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ChatColors.bar(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 96,
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      // Fades in only while there is audio to cut, but always
                      // holds its 48px so the orb stays optically centred.
                      child: AnimatedOpacity(
                        opacity: isSpeaking ? 1 : 0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        child: IgnorePointer(
                          ignoring: !isSpeaking,
                          child: StopAudioButton(
                            active: isSpeaking,
                            onTap: widget.onStopSpeaking,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: GestureDetector(
                          onTap: widget.enabled ? widget.onOrbTap : null,
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (context, _) {
                              return VoiceOrb(progress: _controller.value, mode: mode);
                            },
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: IconButton(
                        tooltip: 'Type instead',
                        onPressed: widget.enabled ? widget.onPreferTyping : null,
                        icon: Icon(
                          Icons.keyboard_alt_outlined,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.grey.shade500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
