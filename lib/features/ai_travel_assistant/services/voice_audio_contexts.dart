import 'package:audioplayers/audioplayers.dart';

/// The two audio profiles this feature plays through.
///
/// These are applied **per player** rather than through
/// `AudioPlayer.global.setAudioContext`, because the global context is
/// last-writer-wins across every [AudioPlayer] in the process: a context
/// tuned for short interface blips would otherwise also decide how spoken
/// answers are routed, and which one won depended on whichever player
/// happened to warm up first.
abstract final class VoiceAudioContexts {
  /// Spoken answers (Edge neural MP3, and the shared session `flutter_tts`
  /// inherits on iOS).
  ///
  /// `defaultToSpeaker` is the load-bearing option. audioplayers defaults iOS
  /// to `playAndRecord` with no options, and that category routes playback to
  /// the earpiece receiver — the audio plays perfectly and is simply
  /// inaudible unless the handset is against your ear.
  ///
  /// `playAndRecord` (rather than the output-only `playback`) is deliberate:
  /// the recognizer shares this one `AVAudioSession`, and leaving it in a
  /// playback-only category kills the microphone until something else
  /// reconfigures it.
  ///
  /// On Android, `media` + `speech` keeps speech on the music stream the
  /// volume rocker controls. A sonification/assistance usage lands on the
  /// notification stream instead, which is silent on any phone with
  /// notifications turned down.
  static AudioContext get speech => AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playAndRecord,
          options: const {
            AVAudioSessionOptions.defaultToSpeaker,
            AVAudioSessionOptions.allowBluetooth,
            AVAudioSessionOptions.allowBluetoothA2DP,
            AVAudioSessionOptions.duckOthers,
          },
        ),
        android: const AudioContextAndroid(
          contentType: AndroidContentType.speech,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      );

  /// Short interface cues (mic open, results ready, success, error).
  ///
  /// Record-capable for the same reason as [speech], and ducking rather than
  /// seizing focus so a blip never pauses the passenger's music outright.
  static AudioContext get cues => AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playAndRecord,
          options: const {
            AVAudioSessionOptions.defaultToSpeaker,
            AVAudioSessionOptions.allowBluetooth,
            AVAudioSessionOptions.allowBluetoothA2DP,
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
        android: const AudioContextAndroid(
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceSonification,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      );
}
