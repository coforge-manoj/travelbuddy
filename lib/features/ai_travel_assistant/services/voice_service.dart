import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:edge_tts/edge_tts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:ai_travel_assistant/features/ai_travel_assistant/services/speech_prosody_planner.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_audio_contexts.dart';

/// Why a listen session finished, so the caller can tell "you said nothing"
/// apart from "the microphone never worked".
enum VoiceListenEndReason {
  /// The recognizer closed the session the normal way — a final result, or
  /// the silence timeout. A transcript may still land shortly afterwards.
  completed,

  /// The recognizer ran but could not turn anything into words.
  noSpeechDetected,

  /// The recognizer itself failed: unavailable, busy, or denied.
  recognizerFailed,
}

/// Wraps speech-to-text (voice input) and text-to-speech (voice output)
/// behind a single, platform-agnostic surface so the ViewModel/UI never
/// touch the underlying plugins directly.
///
/// When the device is online, spoken output uses Microsoft Edge neural
/// voices via [edge_tts] (played through [AudioPlayer]). Offline — or if
/// Edge synthesis fails — it falls back to the on-device [FlutterTts] engine.
///
/// Text handed to [speak] is expected to already be speech-ready — see
/// `SpeechTextFormatter`. Callers should go through `VoiceNarrator` rather
/// than calling [speak] directly, so utterances queue instead of cutting
/// each other off.
class VoiceService {
  VoiceService({
    stt.SpeechToText? speechToText,
    FlutterTts? flutterTts,
    AudioPlayer? edgePlayer,
    Connectivity? connectivity,
    this.edgeVoice = 'en-US-EmmaMultilingualNeural',
  })  : _speech = speechToText ?? stt.SpeechToText(),
        _tts = flutterTts ?? FlutterTts(),
        _injectedEdgePlayer = edgePlayer,
        _connectivity = connectivity ?? Connectivity();

  /// How long Edge synthesis may take before we give up and use the
  /// on-device engine.
  ///
  /// Every second spent here is a second of the passenger staring at a
  /// "speaking" indicator in silence, and the fallback is instant — so this
  /// is deliberately short. The Edge socket either answers quickly or is
  /// having a bad day.
  static const edgeSynthesisTimeout = Duration(seconds: 5);

  /// After [_edgeFailureThreshold] consecutive Edge failures, stop paying the
  /// timeout on every single utterance and go straight to the on-device
  /// engine for a while.
  static const edgeCooldown = Duration(seconds: 90);
  static const _edgeFailureThreshold = 2;

  /// Recognizer errors that mean "nothing usable was heard" rather than "the
  /// recognizer is broken". Android raises these routinely — including
  /// immediately after `listen()` when the passenger takes a beat before
  /// speaking — so they must never tear down the initialized recognizer.
  static const _noSpeechErrors = {
    'error_no_match',
    'error_speech_timeout',
    'error_retry',
  };

  /// Edge neural voice used while online. Override for locale experiments.
  final String edgeVoice;

  final stt.SpeechToText _speech;
  final FlutterTts _tts;
  final AudioPlayer? _injectedEdgePlayer;
  final Connectivity _connectivity;

  /// Created on first Edge speak — constructing [AudioPlayer] eagerly breaks
  /// unit tests that have no audioplayers platform channel.
  AudioPlayer? _edgePlayer;
  bool _speechInitialized = false;
  bool _ttsConfigured = false;
  bool _isSpeaking = false;

  /// Set whenever something else has reconfigured the shared audio session —
  /// the recognizer claims it for recording, and `flutter_tts` sets its own
  /// iOS category. Until the speech context is re-applied, Edge playback can
  /// come out of the earpiece receiver, or not at all.
  bool _audioSessionDirty = true;

  /// Bumped by [stopSpeaking] so an in-flight Edge download/play is abandoned.
  int _speakGeneration = 0;

  /// Consecutive Edge synthesis failures, and when Edge may be tried again.
  int _edgeFailures = 0;
  DateTime? _edgeRetryAt;

  /// One-slot lookahead so the next segment of a sentence run is already
  /// downloaded by the time the current one finishes playing.
  String? _prewarmKey;
  Future<Uint8List>? _prewarmed;

  /// Invoked by [_speakWithFlutterTts] via the engine's start handler.
  VoidCallback? _pendingTtsStart;

  /// Completion of the Edge clip currently playing, so [stopSpeaking] can end
  /// the wait for it. `AudioPlayer.stop()` emits no completion event, so
  /// without this an interrupted utterance would sit on its own timeout while
  /// the caller believes it is still speaking.
  Completer<void>? _edgePlayback;

  /// Updated per [startListening] call so [initialize]'s one-shot handlers
  /// can forward into the active session.
  void Function(String status)? _statusHandler;
  void Function(VoiceListenEndReason reason)? _errorEndedHandler;

  /// Requests the microphone/speech-recognition permission and initializes
  /// the recognizer. Safe to call more than once. Returns false if the
  /// platform denies permission or has no recognizer available — the
  /// caller should surface a voice-recognition-failed message in that case.
  Future<bool> ensureReady() async {
    if (_speechInitialized) return true;
    try {
      _speechInitialized = await _speech.initialize(
        debugLogging: kDebugMode,
        onError: (error) {
          final noSpeech = _noSpeechErrors.contains(error.errorMsg);
          if (kDebugMode) {
            debugPrint(
              '[voice] stt error: ${error.errorMsg} permanent=${error.permanent}',
            );
          }
          // Only a genuinely broken recognizer is worth re-initializing for.
          // Treating "I heard nothing" as a dead engine forces a re-init on
          // every quiet moment, and re-initializing mid-conversation is
          // exactly when the platform starts refusing to listen at all.
          if (!noSpeech && error.permanent) _speechInitialized = false;
          _errorEndedHandler?.call(
            noSpeech
                ? VoiceListenEndReason.noSpeechDetected
                : VoiceListenEndReason.recognizerFailed,
          );
        },
        onStatus: (status) => _statusHandler?.call(status),
      );
    } catch (error) {
      if (kDebugMode) debugPrint('[voice] stt initialize failed: $error');
      _speechInitialized = false;
    }
    return _speechInitialized;
  }

  bool get isListening => _speech.isListening;

  bool get isSpeaking => _isSpeaking;

  /// Starts listening, invoking [onResult] with each partial/final
  /// transcript. Returns false (without calling [onResult]) if the
  /// recognizer couldn't be initialized or refused to start.
  Future<bool> startListening({
    required void Function(String transcript, bool isFinal) onResult,
    void Function(VoiceListenEndReason reason)? onListeningEnded,
    String? localeId,
    Duration listenFor = const Duration(seconds: 15),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    final ready = await ensureReady();
    if (!ready) return false;

    final resolvedLocaleId = localeId ?? await _resolveLocaleId();

    var ended = false;
    void notifyEnded(VoiceListenEndReason reason) {
      if (ended) return;
      ended = true;
      onListeningEnded?.call(reason);
    }

    _statusHandler = (status) {
      if (status == stt.SpeechToText.doneStatus ||
          status == stt.SpeechToText.notListeningStatus) {
        notifyEnded(VoiceListenEndReason.completed);
      }
    };
    _errorEndedHandler = notifyEnded;

    // The recognizer takes the shared audio session for recording; spoken
    // output has to re-claim it before its next clip.
    _audioSessionDirty = true;

    try {
      await _speech.listen(
        onResult: (result) => onResult(result.recognizedWords, result.finalResult),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          // A transient error must not kill a session the passenger is still
          // talking into. Real session ends arrive via the status handler,
          // and the caller runs a watchdog for the case where they don't.
          cancelOnError: false,
          localeId: resolvedLocaleId,
          listenFor: listenFor,
          pauseFor: pauseFor,
        ),
      );
    } catch (error) {
      // Most often the previous session has not finished tearing down yet.
      if (kDebugMode) debugPrint('[voice] stt listen failed: $error');
      _statusHandler = null;
      _errorEndedHandler = null;
      return false;
    }
    return true;
  }

  Future<void> stopListening() async {
    _statusHandler = null;
    _errorEndedHandler = null;
    try {
      await _speech.stop();
    } catch (_) {
      // Nothing was listening, or the platform already tore the session down.
    }
  }

  Future<String?>? _localeIdFuture;

  Future<String?> _resolveLocaleId() => _localeIdFuture ??= _computeLocaleId();

  Future<String?> _computeLocaleId() async {
    try {
      final available = await _speech.locales();
      if (available.isEmpty) return null;

      String canonical(String id) => id.replaceAll('-', '_').toLowerCase();
      String languageOf(String id) => canonical(id).split('_').first;

      final byCanonicalId = {
        for (final locale in available) canonical(locale.localeId): locale.localeId,
      };

      final systemLocaleId = (await _speech.systemLocale())?.localeId;
      if (systemLocaleId != null) {
        final exact = byCanonicalId[canonical(systemLocaleId)];
        if (exact != null) return exact;

        final language = languageOf(systemLocaleId);
        for (final locale in available) {
          if (languageOf(locale.localeId) == language) return locale.localeId;
        }
      }

      return byCanonicalId['en_us'] ?? systemLocaleId;
    } catch (_) {
      return null;
    }
  }

  /// Speaks [text], resolving only once the utterance has actually finished.
  ///
  /// [onAudible] fires the moment sound actually reaches the speaker, which
  /// is materially later than this method being called: network synthesis
  /// sits in between. Callers that show a "speaking" indicator should wait
  /// for it rather than assume audio starts immediately.
  ///
  /// Prefers Edge neural TTS when a network interface is up; otherwise (or
  /// on synthesis failure) uses on-device [FlutterTts].
  Future<void> speak(
    String text, {
    double pitch = SpeechProsodyPlanner.statementPitch,
    double rate = SpeechProsodyPlanner.statementRate,
    VoidCallback? onAudible,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final generation = ++_speakGeneration;
    _isSpeaking = true;
    try {
      if (_edgeUsable && await _hasNetwork()) {
        try {
          final played = await _speakWithEdge(
            trimmed,
            pitch: pitch,
            rate: rate,
            generation: generation,
            onAudible: onAudible,
          );
          if (played) return;
        } catch (error, stack) {
          _noteEdgeFailure();
          if (kDebugMode) {
            debugPrint('[voice] edge_tts failed, falling back to flutter_tts: $error');
            debugPrint('$stack');
          }
        }
      }

      if (generation != _speakGeneration) return;
      await _speakWithFlutterTts(
        trimmed,
        pitch: pitch,
        rate: rate,
        onAudible: onAudible,
      );
    } finally {
      if (generation == _speakGeneration) _isSpeaking = false;
    }
  }

  /// Starts downloading [text] so the next [speak] can begin playing without
  /// a network round trip. Fire-and-forget: a prewarm that fails simply
  /// leaves [speak] to synthesize normally.
  void prewarm(
    String text, {
    double pitch = SpeechProsodyPlanner.statementPitch,
    double rate = SpeechProsodyPlanner.statementRate,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || !_edgeUsable) return;

    final key = _synthesisKey(trimmed, pitch, rate);
    if (_prewarmKey == key) return;
    _prewarmKey = key;
    // Swallowed here and re-thrown from `speak` if it ends up awaiting this
    // future, so a prewarm nobody consumes is never an unhandled error.
    _prewarmed = _synthesizeWithEdge(trimmed, pitch: pitch, rate: rate)
      ..ignore();
  }

  Future<void> stopSpeaking() async {
    _speakGeneration++;
    _isSpeaking = false;
    _pendingTtsStart = null;
    _prewarmKey = null;
    _prewarmed = null;
    // Released before the player is told to stop: `stop()` produces no
    // completion event, so the clip's own wait would otherwise run to its
    // timeout and keep the caller's speak future pending long after silence.
    final playback = _edgePlayback;
    _edgePlayback = null;
    if (playback != null && !playback.isCompleted) playback.complete();
    try {
      await _edgePlayer?.stop();
    } catch (_) {}
    try {
      await _tts.stop();
    } catch (_) {}
  }

  void dispose() {
    _speech.cancel();
    _tts.stop();
    _edgePlayer?.dispose();
    _edgePlayer = null;
  }

  Future<bool> _hasNetwork() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((result) => result != ConnectivityResult.none);
    } catch (_) {
      // If connectivity cannot be queried, try Edge and let it fail open.
      return true;
    }
  }

  /// False while Edge is in its post-failure cooldown, so a Microsoft-side
  /// outage costs one timeout rather than one per utterance.
  bool get _edgeUsable {
    final retryAt = _edgeRetryAt;
    if (retryAt == null) return true;
    if (DateTime.now().isBefore(retryAt)) return false;
    _edgeRetryAt = null;
    _edgeFailures = 0;
    return true;
  }

  void _noteEdgeFailure() {
    _prewarmKey = null;
    _prewarmed = null;
    if (++_edgeFailures < _edgeFailureThreshold) return;
    _edgeRetryAt = DateTime.now().add(edgeCooldown);
  }

  static String _synthesisKey(String text, double pitch, double rate) =>
      '$pitch|$rate|$text';

  Future<Uint8List> _synthesizeWithEdge(
    String text, {
    required double pitch,
    required double rate,
  }) {
    return Communicate(
      text: text,
      voice: edgeVoice,
      rate: edgeRatePercent(rate),
      pitch: edgePitchHz(pitch),
    ).toBytes().timeout(edgeSynthesisTimeout);
  }

  /// Returns true when Edge audio actually played (or was superseded), false
  /// when it produced nothing usable and the caller should fall back.
  Future<bool> _speakWithEdge(
    String text, {
    required double pitch,
    required double rate,
    required int generation,
    VoidCallback? onAudible,
  }) async {
    final key = _synthesisKey(text, pitch, rate);
    final pending = _prewarmKey == key ? _prewarmed : null;
    _prewarmKey = null;
    _prewarmed = null;

    final bytes =
        await (pending ?? _synthesizeWithEdge(text, pitch: pitch, rate: rate));

    if (generation != _speakGeneration) return true;
    if (bytes.isEmpty) {
      _noteEdgeFailure();
      return false;
    }
    _edgeFailures = 0;

    final player = await _readyEdgePlayer();
    // Ordered before the subscription so a completion event still queued from
    // the previous clip is delivered (and discarded) while we await, instead
    // of resolving this clip the instant it starts.
    await player.stop();
    if (generation != _speakGeneration) return true;

    final completed = Completer<void>();
    _edgePlayback = completed;
    final subscription = player.onPlayerComplete.listen((_) {
      if (!completed.isCompleted) completed.complete();
    });

    try {
      await player.play(BytesSource(bytes, mimeType: 'audio/mpeg'));
      if (generation != _speakGeneration) return true;
      onAudible?.call();
      await completed.future.timeout(
        const Duration(seconds: 90),
        onTimeout: () {},
      );
    } finally {
      if (identical(_edgePlayback, completed)) _edgePlayback = null;
      await subscription.cancel();
    }
    return true;
  }

  Future<AudioPlayer> _readyEdgePlayer() async {
    final player = _edgePlayer ??= _injectedEdgePlayer ?? AudioPlayer();
    if (!_audioSessionDirty) return player;
    _audioSessionDirty = false;

    // Re-applied rather than set once: the recognizer and `flutter_tts` both
    // reconfigure the shared iOS session behind our back, and audioplayers'
    // own default (`playAndRecord` with no options) routes playback to the
    // earpiece receiver — audible only with the phone against your ear.
    await player.setAudioContext(VoiceAudioContexts.speech);
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setVolume(1.0);
    return player;
  }

  Future<void> _speakWithFlutterTts(
    String text, {
    required double pitch,
    required double rate,
    VoidCallback? onAudible,
  }) async {
    await _ensureTtsConfigured();
    // flutter_tts owns the iOS session while it speaks.
    _audioSessionDirty = true;
    _pendingTtsStart = onAudible;
    try {
      await _tts.setPitch(pitch);
      await _tts.setSpeechRate(rate);
      await _tts.speak(text);
    } finally {
      _pendingTtsStart = null;
    }
  }

  Future<void> _ensureTtsConfigured() async {
    if (_ttsConfigured) return;
    _ttsConfigured = true;
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(SpeechProsodyPlanner.statementRate);
    await _tts.setPitch(SpeechProsodyPlanner.statementPitch);
    _tts.setStartHandler(() {
      final onAudible = _pendingTtsStart;
      _pendingTtsStart = null;
      onAudible?.call();
    });
    await _preferQualityVoice();

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playAndRecord,
        [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );
    }
  }

  Future<void> _preferQualityVoice() async {
    try {
      final raw = await _tts.getVoices;
      if (raw is! List) return;

      final voices = <Map<String, String>>[
        for (final entry in raw)
          if (entry is Map)
            {
              for (final key in entry.keys)
                if (entry[key] != null) '$key': '${entry[key]}',
            },
      ];

      final enUs = voices.where((voice) {
        final locale = (voice['locale'] ?? voice['localeId'] ?? '').toLowerCase();
        return locale == 'en-us' || locale == 'en_us';
      }).toList();
      if (enUs.isEmpty) return;

      int score(Map<String, String> voice) {
        final quality = (voice['quality'] ?? '').toLowerCase();
        if (quality.contains('enhanced') || quality.contains('premium')) return 3;
        if (quality.contains('default') || quality.contains('normal')) return 1;
        final name = (voice['name'] ?? '').toLowerCase();
        if (name.contains('enhanced') || name.contains('premium') || name.contains('neural')) {
          return 2;
        }
        return 0;
      }

      enUs.sort((a, b) => score(b).compareTo(score(a)));
      final best = enUs.first;
      final name = best['name'];
      final locale = best['locale'] ?? best['localeId'] ?? 'en-US';
      if (name == null || name.isEmpty) return;
      await _tts.setVoice({'name': name, 'locale': locale});
    } catch (_) {}
  }

  /// Maps [SpeechProsodyPlanner] rates (~0.42–0.50) onto Edge's `±N%` scale,
  /// with [SpeechProsodyPlanner.statementRate] as `+0%`.
  @visibleForTesting
  static String edgeRatePercent(double rate) {
    final percent = (((rate / SpeechProsodyPlanner.statementRate) - 1.0) * 100).round();
    final clamped = percent.clamp(-50, 100);
    return clamped >= 0 ? '+$clamped%' : '$clamped%';
  }

  /// Maps [SpeechProsodyPlanner] pitch (~0.95–1.35) onto Edge's `±NHz` scale,
  /// with 1.0 as `+0Hz`.
  @visibleForTesting
  static String edgePitchHz(double pitch) {
    final hz = ((pitch - 1.0) * 80).round().clamp(-50, 50);
    return hz >= 0 ? '+${hz}Hz' : '${hz}Hz';
  }
}
