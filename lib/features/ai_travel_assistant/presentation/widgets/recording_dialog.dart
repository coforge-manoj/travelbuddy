import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_service.dart';

/// Full-screen modal shown while the passenger records a voice message
/// (voice mode 2).
///
/// On iOS / web / desktop it captures audio (via [AudioRecorder]) and a live
/// transcript (via [stt.SpeechToText]) at the same time. On Android the OS
/// will not share the microphone between those two APIs — attempting both
/// exits the process — so we use speech-to-text only and skip the file.
class RecordingDialog extends StatefulWidget {
  const RecordingDialog({super.key});

  static Future<AudioRecordingResult?> show(BuildContext context) {
    return showDialog<AudioRecordingResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const RecordingDialog(),
    );
  }

  @override
  State<RecordingDialog> createState() => _RecordingDialogState();
}

class _RecordingDialogState extends State<RecordingDialog> {
  final AudioRecorder _recorder = AudioRecorder();
  final stt.SpeechToText _speech = stt.SpeechToText();

  StreamSubscription<Amplitude>? _ampSub;

  /// Fires once the passenger has been silent for [_silenceTimeout] after
  /// speaking, auto-submitting the recording so they never have to tap stop.
  Timer? _silenceTimer;
  static const _silenceTimeout = Duration(seconds: 3);

  String _transcript = '';
  double _level = 0; // 0..1, drives the wave
  DateTime? _startedAt;
  bool _recording = false;
  bool _stopping = false;
  String? _error;

  /// Android cannot open the mic for MediaRecorder and SpeechRecognizer at
  /// once; see https://pub.dev/packages/speech_to_text (Recording audio).
  bool get _androidExclusiveMic =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      if (_androidExclusiveMic) {
        await _startSpeechOnly();
      } else {
        await _startRecordAndSpeech();
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not start recording: $e');
    }
  }

  /// Android-safe path: live transcript + sound-level wave, no file write.
  Future<void> _startSpeechOnly() async {
    final available = await _speech.initialize(
      onError: (_) {},
      onStatus: (_) {},
    );
    if (!available) {
      if (mounted) {
        setState(() => _error = 'Speech recognition is unavailable on this device.');
      }
      return;
    }

    await _speech.listen(
      onResult: (r) => _onTranscript(r.recognizedWords),
      onSoundLevelChange: _onSpeechSoundLevel,
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(minutes: 1),
      ),
    );

    _startedAt = DateTime.now();
    if (mounted) setState(() => _recording = true);
  }

  /// Platforms that can share the mic: file + live transcript together.
  Future<void> _startRecordAndSpeech() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        setState(() => _error = 'Microphone permission was denied.');
      }
      return;
    }

    // Web records WebM/Opus; native platforms use AAC in an m4a container.
    // Native paths must be absolute — a bare filename crashes MediaRecorder.
    const encoder = kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc;
    final fileName =
        'voice_${DateTime.now().millisecondsSinceEpoch}.${kIsWeb ? 'webm' : 'm4a'}';
    final path = kIsWeb
        ? fileName
        : '${(await getTemporaryDirectory()).path}/$fileName';

    await _recorder.start(const RecordConfig(encoder: encoder), path: path);

    _ampSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 120))
        .listen(_onAmplitude);

    // Transcribe in parallel. Speech may be unavailable; the recording still
    // works, we just end up with an empty transcript.
    final available =
        await _speech.initialize(onError: (_) {}, onStatus: (_) {});
    if (available) {
      await _speech.listen(
        onResult: (r) => _onTranscript(r.recognizedWords),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenFor: const Duration(minutes: 5),
          pauseFor: const Duration(minutes: 1),
        ),
      );
    }

    _startedAt = DateTime.now();
    if (mounted) setState(() => _recording = true);
  }

  void _onAmplitude(Amplitude amp) {
    if (!mounted) return;
    // dBFS is roughly -45 (quiet) .. 0 (loud). Map onto 0..1.
    final norm = ((amp.current + 45) / 45).clamp(0.0, 1.0);
    setState(() => _level = norm);
  }

  /// speech_to_text reports roughly 0..10 on Android / -2..10 on iOS.
  void _onSpeechSoundLevel(double level) {
    if (!mounted) return;
    setState(() => _level = (level / 10).clamp(0.0, 1.0));
  }

  /// Handles each partial/final transcript: mirrors it into the UI and, since
  /// new words mean the passenger is still talking, restarts the silence timer.
  void _onTranscript(String words) {
    if (!mounted) return;
    setState(() => _transcript = words);
    _armSilenceTimer();
  }

  /// (Re)starts the 3-second countdown to auto-submit. Each new word bumps it,
  /// so we only fire once speech has actually paused. We never auto-submit an
  /// empty recording — if nothing was heard, keep listening.
  void _armSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(_silenceTimeout, () {
      if (!_stopping && _transcript.trim().isNotEmpty) {
        _stop();
      }
    });
  }

  Future<void> _stop() async {
    if (_stopping) return;
    setState(() => _stopping = true);

    _silenceTimer?.cancel();
    await _ampSub?.cancel();

    String? path;
    if (!_androidExclusiveMic) {
      try {
        path = await _recorder.stop();
      } catch (_) {
        path = null;
      }
    }
    try {
      await _speech.stop();
    } catch (_) {}

    final duration = _startedAt == null
        ? Duration.zero
        : DateTime.now().difference(_startedAt!);

    if (!mounted) return;

    // Android STT-only: no file is expected. Other platforms need a path.
    if (!_androidExclusiveMic && path == null) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pop(
      AudioRecordingResult(
        audioPath: path,
        transcript: _transcript.trim(),
        duration: duration,
      ),
    );
  }

  Future<void> _cancel() async {
    _silenceTimer?.cancel();
    await _ampSub?.cancel();
    if (!_androidExclusiveMic) {
      try {
        await _recorder.stop();
      } catch (_) {}
    }
    try {
      await _speech.cancel();
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _ampSub?.cancel();
    unawaited(_speech.cancel());
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: _error != null ? _buildError(theme) : _buildRecording(theme),
      ),
    );
  }

  Widget _buildRecording(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.topRight,
          child: IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: _stopping ? null : _cancel,
            icon: Icon(
              Icons.close_rounded,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        _ListeningHeader(
          color: theme.colorScheme.primary,
          active: _recording && !_stopping,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 64,
          child: _Waveform(
            level: _level,
            color: theme.colorScheme.primary,
            active: _recording,
          ),
        ),
        const SizedBox(height: 28),
        _MicButton(
          color: theme.colorScheme.primary,
          iconColor: theme.colorScheme.onPrimary,
          busy: _stopping,
          onTap: (_recording && !_stopping) ? _stop : null,
        ),
        const SizedBox(height: 12),
        Text(
          _stopping ? 'Processing…' : 'Pause when you\'re done, or tap to stop',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        if (_transcript.isNotEmpty) _YouSaidBubble(transcript: _transcript),
      ],
    );
  }

  Widget _buildError(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.mic_off_rounded, size: 40, color: theme.colorScheme.error),
        const SizedBox(height: 12),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// "Listening…" title sitting on top of the waveform, with a pulsing dot to
/// signal the mic is live.
class _ListeningHeader extends StatefulWidget {
  const _ListeningHeader({required this.color, required this.active});

  final Color color;
  final bool active;

  @override
  State<_ListeningHeader> createState() => _ListeningHeaderState();
}

class _ListeningHeaderState extends State<_ListeningHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: widget.active
              ? _c.drive(Tween(begin: 0.3, end: 1))
              : const AlwaysStoppedAnimation(0.3),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          widget.active ? 'Listening…' : 'Getting ready…',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Animated bar-style sound wave. Bars ripple continuously and swell with the
/// live microphone [level] (0..1).
class _Waveform extends StatefulWidget {
  const _Waveform({
    required this.level,
    required this.color,
    required this.active,
  });

  final double level;
  final Color color;
  final bool active;

  @override
  State<_Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<_Waveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  static const _bars = 42;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(double.infinity, 64),
          painter: _WavePainter(
            phase: _c.value * 2 * math.pi,
            level: widget.active ? widget.level : 0,
            color: widget.color,
            bars: _bars,
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.phase,
    required this.level,
    required this.color,
    required this.bars,
  });

  final double phase;
  final double level;
  final Color color;
  final int bars;

  // Deterministic per-bar "randomness" so the wave has an irregular, natural
  // profile instead of a smooth sine.
  double _hash(int i) {
    final x = math.sin(i * 12.9898) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.fill;

    final slot = size.width / bars;
    final barWidth = slot * 0.45;
    final midY = size.height / 2;

    for (var i = 0; i < bars; i++) {
      final rnd = _hash(i);
      final shimmer = 0.5 + 0.5 * math.sin(phase * 1.6 + i * 0.9 + rnd * 6.28);
      final base = 0.12 + rnd * 0.30;
      final amp = base * (0.6 + 0.4 * shimmer) + level * (0.35 + 0.55 * rnd);
      final edge = math.sin((i / (bars - 1)) * math.pi).clamp(0.35, 1.0);
      final h = (amp * edge).clamp(0.04, 1.0) * size.height;

      final x = i * slot + (slot - barWidth) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, midY - h / 2, barWidth, h),
        Radius.circular(barWidth),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.phase != phase || old.level != level || old.color != color;
}

/// Circular mic button — tapping it stops the recording.
class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.color,
    required this.iconColor,
    required this.busy,
    required this.onTap,
  });

  final Color color;
  final Color iconColor;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.12),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: busy
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(iconColor),
                  ),
                )
              : Icon(Icons.mic, color: iconColor, size: 28),
        ),
      ),
    );
  }
}

/// Chat-style "You said:" bubble showing the live transcript on a single line
/// that scrolls horizontally, keeping the most recently spoken words in view.
/// `reverse: true` rests the viewport at the tail, so new words stay visible as
/// the transcript grows without any manual scrolling.
class _YouSaidBubble extends StatelessWidget {
  const _YouSaidBubble({required this.transcript});

  final String transcript;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primary,
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.smart_toy_rounded,
            size: 18,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Text(
                '"$transcript"',
                maxLines: 1,
                softWrap: false,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
