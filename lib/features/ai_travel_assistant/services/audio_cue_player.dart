import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_audio_contexts.dart';

/// The non-verbal feedback vocabulary of the assistant.
enum AudioCue {
  /// The microphone just opened.
  listeningStart('sounds/listening_start.wav'),

  /// A rich card just landed in the conversation.
  resultsReady('sounds/results_ready.wav'),

  /// A booking or purchase completed.
  success('sounds/success.wav'),

  /// Something went wrong.
  error('sounds/error.wav'),

  /// A proactive follow-up is about to be spoken.
  prompt('sounds/prompt.wav');

  const AudioCue(this.asset);

  final String asset;
}

/// Plays the short interface cues that make the assistant feel responsive
/// before speech has a chance to start.
///
/// Cues are intentionally independent of the talk-back setting: someone who
/// has muted the spoken summaries still benefits from knowing that the
/// microphone is live or that results arrived.
class AudioCuePlayer {
  AudioCuePlayer({AudioPlayer? player}) : _injectedPlayer = player;

  final AudioPlayer? _injectedPlayer;

  /// Created on first use rather than in the constructor, so building one of
  /// these never reaches for a platform channel that may not exist.
  AudioPlayer? _player;
  bool _configured = false;

  /// Fire-and-forget: a cue that fails to play is never worth surfacing.
  Future<void> play(AudioCue cue) async {
    try {
      final player = await _ready();
      await player.stop();
      await player.play(AssetSource(cue.asset));
    } catch (_) {
      // No audio device, missing asset, or no platform channel under test.
    }
  }

  /// Plays [cue] and resolves only once the sound has finished.
  ///
  /// Needed before opening the microphone. audioplayers deactivates the
  /// shared iOS audio session (`setActive(false)`) as soon as its last
  /// player completes; if that lands while the recognizer is already
  /// running, it tears the session out from under the mic and recording
  /// goes silent with no error. Letting the cue finish first keeps the
  /// deactivation strictly before the recognizer activates the session.
  ///
  /// The timeout is a backstop so a cue that never reports completion can
  /// never strand voice input.
  Future<void> playAndAwait(
    AudioCue cue, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    try {
      final player = await _ready();
      await player.stop();
      final completed = player.onPlayerComplete.first;
      await player.play(AssetSource(cue.asset));
      await completed.timeout(timeout);
    } catch (_) {
      // Same rationale as [play] — plus a timed-out cue must not block the
      // microphone from opening.
    }
  }

  Future<AudioPlayer> _ready() async {
    final player = _player ??= _injectedPlayer ?? AudioPlayer();
    if (_configured) return player;
    _configured = true;

    // Scoped to this player, never to `AudioPlayer.global`: a global context
    // is shared by every player in the process, so the cue profile below
    // would also decide how spoken answers are routed. See
    // [VoiceAudioContexts].
    await player.setAudioContext(VoiceAudioContexts.cues);
    await player.setReleaseMode(ReleaseMode.stop);
    // Quiet enough to sit under speech rather than compete with it.
    await player.setVolume(0.35);
    return player;
  }

  /// A light tap for direct manipulation, complementing the audible cues.
  Future<void> tapFeedback() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {
      // Haptics are unavailable on this device.
    }
  }

  void dispose() {
    _player?.dispose();
    _player = null;
  }
}
