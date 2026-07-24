import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A replayable voice-message bubble (voice mode 2). Renders a play/pause
/// button, a scrubbable progress bar, and a duration label. [audioPath] is a
/// local file path (mobile/desktop) or a blob URL (web).
class AudioMessageBubble extends StatefulWidget {
  const AudioMessageBubble({
    super.key,
    required this.audioPath,
    this.duration,
  });

  final String audioPath;
  final Duration? duration;

  @override
  State<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<AudioMessageBubble> {
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subs = [];

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;

  Source get _source =>
      kIsWeb ? UrlSource(widget.audioPath) : DeviceFileSource(widget.audioPath);

  @override
  void initState() {
    super.initState();
    _duration = widget.duration ?? Duration.zero;

    _subs.add(_player.onDurationChanged.listen((d) {
      if (mounted && d > Duration.zero) setState(() => _duration = d);
    }),);
    _subs.add(_player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    }),);
    _subs.add(_player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    }),);
    _subs.add(_player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
      }
    }),);

    // Preload so we get a duration before the first play.
    _player.setSource(_source).catchError((_) {});
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      return;
    }
    // Restart from the beginning if the last play finished.
    if (_position >= _duration && _duration > Duration.zero) {
      await _player.seek(Duration.zero);
    }
    await _player.play(_source);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onColor = theme.colorScheme.onPrimary;
    final total = _duration.inMilliseconds;
    final progress =
        total == 0 ? 0.0 : (_position.inMilliseconds / total).clamp(0.0, 1.0);
    final label = _duration == Duration.zero
        ? _fmt(_position)
        : (_playing ? _fmt(_position) : _fmt(_duration));

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: _toggle,
              customBorder: const CircleBorder(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: onColor.withValues(alpha: 0.18),
                ),
                child: Icon(
                  _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: onColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 20,
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        activeTrackColor: onColor,
                        inactiveTrackColor: onColor.withValues(alpha: 0.3),
                        thumbColor: onColor,
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 12),
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 6),
                      ),
                      child: Slider(
                        value: progress,
                        onChanged: total == 0
                            ? null
                            : (v) {
                                final target =
                                    Duration(milliseconds: (v * total).round());
                                setState(() => _position = target);
                                _player.seek(target);
                              },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Row(
                      children: [
                        Icon(Icons.graphic_eq_rounded,
                            size: 14, color: onColor.withValues(alpha: 0.8),),
                        const SizedBox(width: 4),
                        Text(
                          label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: onColor.withValues(alpha: 0.9),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
