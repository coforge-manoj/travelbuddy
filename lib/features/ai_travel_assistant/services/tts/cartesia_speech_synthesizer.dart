import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/cartesia_tts_client.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/speech_synthesizer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/speech_trace.dart';

/// Cartesia neural TTS: synthesizes to mp3 bytes up front, then plays them.
///
/// [prepare] returning `null` is the fallback signal — the caller should try
/// the on-device engine instead of leaving the passenger in silence.
class CartesiaSpeechSynthesizer implements SpeechSynthesizer {
  CartesiaSpeechSynthesizer({
    CartesiaTtsClient? client,
    AudioPlayer? player,
  })  : _client = client ?? CartesiaTtsClient(),
        _injectedPlayer = player;

  final CartesiaTtsClient _client;

  /// Constructed on first playback, not in the constructor: `AudioPlayer`
  /// touches a platform channel, and this class is built eagerly by
  /// `VoiceService` — including in unit tests, where no plugin exists.
  final AudioPlayer? _injectedPlayer;
  AudioPlayer? _lazyPlayer;

  AudioPlayer get _player => _injectedPlayer ?? (_lazyPlayer ??= AudioPlayer());

  /// Playback needs a real file on iOS, so each utterance is written to the
  /// temp dir and the previous one deleted.
  File? _currentClip;

  /// Completion of the clip currently playing. `AudioPlayer.stop()` does not
  /// emit [AudioPlayer.onPlayerComplete], so [stop] must resolve this or the
  /// next utterance would wait on a future that never finishes.
  Completer<void>? _playback;

  /// Cartesia is HTTP per utterance — nothing to open ahead of time. Kept so
  /// [VoiceService.warmUpSpeech] can call a uniform hook.
  Future<void> warmUp() async {}

  @override
  Future<PreparedSpeech?> prepare(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final audio = await _client.synthesize(trimmed);
    if (audio == null || audio.isEmpty) return null;

    return PreparedSpeech(spokenText: trimmed, audioBytes: audio);
  }

  /// Starts the clip and resolves only once it has finished (or been stopped).
  ///
  /// `audioplayers`' [AudioPlayer.play] returns as soon as playback is
  /// *dispatched*. If we returned then, the ViewModel's speech chain would
  /// start the next utterance immediately and [stop] would cut this one off
  /// after the first second or two.
  @override
  Future<void> play(PreparedSpeech speech) async {
    final audio = speech.audioBytes;
    if (audio == null || audio.isEmpty) return;

    await stop();
    final clip = await _writeClip(audio);
    _currentClip = clip;
    SpeechTrace.step('clip.written', detail: 'bytes=${audio.length}');

    final player = _player;
    await player.setReleaseMode(ReleaseMode.stop);

    final completed = Completer<void>();
    _playback = completed;
    final subscription = player.onPlayerComplete.listen((_) {
      if (!completed.isCompleted) completed.complete();
    });

    try {
      await player.play(
        DeviceFileSource(clip.path, mimeType: 'audio/mpeg'),
      );
      // The end of the silent wait: everything above this line is delay the
      // passenger hears as nothing happening.
      SpeechTrace.step('audio.playing');
      await completed.future.timeout(
        const Duration(seconds: 90),
        onTimeout: () {},
      );
      SpeechTrace.step('audio.finished');
    } finally {
      if (identical(_playback, completed)) _playback = null;
      await subscription.cancel();
    }
  }

  @override
  Future<void> stop() async {
    // Released before the player is told to stop: `stop()` produces no
    // completion event, so the clip's own wait would otherwise run to its
    // timeout and keep the caller's play future pending long after silence.
    final playback = _playback;
    _playback = null;
    if (playback != null && !playback.isCompleted) playback.complete();

    await _activePlayer?.stop();
    await _deleteCurrentClip();
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _activePlayer?.dispose();
    _lazyPlayer = null;
    _client.dispose();
  }

  /// The player only if one was ever needed — stopping or disposing must not
  /// be the thing that first spins up a platform channel.
  AudioPlayer? get _activePlayer => _injectedPlayer ?? _lazyPlayer;

  Future<File> _writeClip(Uint8List audio) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/cartesia_tts_${DateTime.now().microsecondsSinceEpoch}.mp3',
    );
    await file.writeAsBytes(audio, flush: true);
    return file;
  }

  Future<void> _deleteCurrentClip() async {
    final clip = _currentClip;
    _currentClip = null;
    if (clip == null) return;
    try {
      if (clip.existsSync()) await clip.delete();
    } catch (_) {
      // A leftover temp file is harmless; the OS reclaims it.
    }
  }
}
