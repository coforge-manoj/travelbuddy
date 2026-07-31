import 'dart:async';
import 'dart:collection';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/spoken_draft.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/speech_phraser.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/speech_prosody_planner.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_service.dart';

/// Serializes text-to-speech so a single conversational turn is spoken as
/// one continuous stretch of audio.
///
/// This exists because [VoiceService.speak] stops whatever is currently
/// playing before it starts, and several chat flows append two or more
/// messages in quick succession (a text recap immediately followed by a rich
/// card, for instance). Speaking those directly would cut each utterance off
/// part-way through. Utterances that arrive within [coalesceWindow] of each
/// other are joined into one sentence run; anything later simply queues.
///
/// Callers may enqueue either finished text (for messages the passenger is
/// also reading on screen) or a [SpokenDraft], whose wording is chosen by the
/// [SpeechPhraser] just before it is spoken. Because phrasing is asynchronous,
/// the narrator is also the thing that keeps spoken order intact: batches
/// resolve one after another, so a slow phrasing can never let a later turn
/// overtake an earlier one on its way to the speaker.
///
/// After coalescing, text is split into [SpeechSegment]s so questions and
/// soft leads get light pitch/rate changes instead of one flat reading.
///
/// How far along a turn is is reported as a [NarrationPhase] rather than a
/// bare "speaking" flag, because the gap between the two is audible: wording
/// and network synthesis both happen before the first sample plays.
enum NarrationPhase {
  /// Nothing queued, nothing playing.
  idle,

  /// The turn is committed but inaudible so far — its wording is being
  /// chosen, or its audio is still being synthesized. UI should keep showing
  /// a loader here, not a speaking indicator.
  preparing,

  /// Sound is actually coming out of the speaker.
  speaking,
}

class VoiceNarrator {
  VoiceNarrator({
    required VoiceService voiceService,
    SpeechPhraser phraser = const FallbackSpeechPhraser(),
    Duration coalesceWindow = const Duration(milliseconds: 120),
    int memoryDepth = 6,
  })  : _voiceService = voiceService,
        _phraser = phraser,
        _coalesceWindow = coalesceWindow,
        _memoryDepth = memoryDepth;

  final VoiceService _voiceService;
  final SpeechPhraser _phraser;
  final Duration _coalesceWindow;

  /// How many past utterances the phraser is shown. Enough for it to avoid
  /// repeating itself, short enough that the prompt stays small.
  final int _memoryDepth;

  final List<_PendingUtterance> _buffer = <_PendingUtterance>[];
  final Queue<SpeechSegment> _queue = Queue<SpeechSegment>();
  final Queue<String> _recentlySpoken = Queue<String>();
  final _phaseController = StreamController<NarrationPhase>.broadcast();

  /// Batches still on their way to the speech queue. A batch dropped from this
  /// set has been cancelled and its resolved text is discarded.
  final Set<int> _liveBatches = <int>{};
  int _nextBatchId = 0;
  Future<void> _resolutions = Future<void>.value();

  Timer? _coalesceTimer;
  bool _draining = false;

  /// The generation the running drain loop belongs to, so a loop left over
  /// from a cancelled turn can be told apart from the live one.
  int _drainGeneration = -1;
  NarrationPhase _phase = NarrationPhase.idle;

  /// When false (app backgrounded / not visible), [enqueue] is a no-op and
  /// any in-flight speech is discarded by [setSpeechAllowed].
  bool _speechAllowed = true;

  /// Bumped by [stopAll] so an in-flight drain loop abandons the rest of its
  /// work instead of carrying on with utterances the user just cancelled.
  int _generation = 0;

  /// Emits [NarrationPhase.preparing] when a turn is committed,
  /// [NarrationPhase.speaking] once its audio is actually audible, and
  /// [NarrationPhase.idle] when the queue has fully drained. The idle edge is
  /// the signal a proactive follow-up should wait for — it means the
  /// passenger has actually heard the whole turn.
  Stream<NarrationPhase> get phaseChanges => _phaseController.stream;

  NarrationPhase get phase => _phase;

  bool get isBusy => _draining || _hasPendingWork;

  bool get _hasPendingWork =>
      _buffer.isNotEmpty || _queue.isNotEmpty || _liveBatches.isNotEmpty;

  bool get isSpeechAllowed => _speechAllowed;

  /// Allows or blocks spoken output. Turning speech off silences anything
  /// already queued or playing — used when the app leaves the foreground so
  /// talkback never continues in the background.
  Future<void> setSpeechAllowed(bool allowed) async {
    if (_speechAllowed == allowed) return;
    _speechAllowed = allowed;
    if (!allowed) await stopAll();
  }

  /// Queues [utterance] to be spoken exactly as given. Returns immediately;
  /// speech happens on the drain loop.
  void enqueue(String utterance) {
    if (!_speechAllowed) return;
    final trimmed = utterance.trim();
    if (trimmed.isEmpty) return;
    _add(_PendingUtterance.text(trimmed));
  }

  /// Queues [draft] to be worded by the phraser and then spoken. Use this for
  /// card summaries, which exist only as speech and so have no on-screen
  /// wording to stay faithful to.
  void enqueueDraft(SpokenDraft draft) {
    if (!_speechAllowed) return;
    _add(_PendingUtterance.draft(draft));
  }

  void _add(_PendingUtterance utterance) {
    _buffer.add(utterance);
    _emitPhase(NarrationPhase.preparing);

    _coalesceTimer?.cancel();
    _coalesceTimer = Timer(_coalesceWindow, _flushBuffer);
  }

  /// Cancels everything: the coalescing buffer, any phrasing still resolving,
  /// the queue, and whatever is currently playing. Used by the mute toggle,
  /// barge-in, and disposal.
  Future<void> stopAll() async {
    _generation++;
    _coalesceTimer?.cancel();
    _coalesceTimer = null;
    _buffer.clear();
    _liveBatches.clear();
    _queue.clear();
    _emitPhase(NarrationPhase.idle);
    try {
      await _voiceService.stopSpeaking();
    } catch (_) {
      // Nothing was playing, or there is no TTS engine. Either way the
      // caller's intent (silence) is satisfied.
    }
  }

  void dispose() {
    _coalesceTimer?.cancel();
    _buffer.clear();
    _liveBatches.clear();
    _queue.clear();
    _phaseController.close();
  }

  void _flushBuffer() {
    _coalesceTimer = null;
    if (_buffer.isEmpty) return;

    final batch = List<_PendingUtterance>.of(_buffer);
    _buffer.clear();

    final id = _nextBatchId++;
    _liveBatches.add(id);
    _resolutions = _resolutions.then((_) => _resolveAndQueue(id, batch));
  }

  Future<void> _resolveAndQueue(int id, List<_PendingUtterance> batch) async {
    try {
      // Cancelled while waiting its turn behind an earlier batch.
      if (!_liveBatches.contains(id)) return;

      final texts = <String>[];
      for (final utterance in batch) {
        final text = await utterance.resolve(_phraser, recentlySpoken: _recentlySpoken.toList());
        if (!_liveBatches.contains(id)) return;

        final trimmed = text.trim();
        if (trimmed.isEmpty) continue;
        texts.add(trimmed);
        _remember(trimmed);
      }
      if (texts.isEmpty) return;

      for (final segment in SpeechProsodyPlanner.plan(_joinSentences(texts))) {
        _queue.add(segment);
      }
    } finally {
      _liveBatches.remove(id);
      // Runs on every path, including the early returns above. A batch that
      // resolved to nothing still has to hand back the `preparing` phase it
      // claimed on enqueue, or the UI is left announcing a turn that will
      // never make a sound.
      unawaited(_drain());
    }
  }

  /// Keeps the tail of what the passenger has heard, so the phraser can vary
  /// its openers instead of greeting them the same way every turn.
  void _remember(String utterance) {
    _recentlySpoken.addLast(utterance);
    while (_recentlySpoken.length > _memoryDepth) {
      _recentlySpoken.removeFirst();
    }
  }

  Future<void> _drain() async {
    // A loop belonging to a cancelled generation may still be unwinding the
    // utterance it was interrupted on. It will never speak from this queue
    // again — the generation check below sends it home — so the new turn
    // starts draining now instead of waiting behind it and never running.
    if (_draining && _drainGeneration == _generation) return;
    final generation = _generation;
    _draining = true;
    _drainGeneration = generation;

    try {
      while (_queue.isNotEmpty) {
        if (generation != _generation || !_speechAllowed) return;
        final next = _queue.removeFirst();
        // Peeked before speaking so synthesis of the follow-on segment can
        // start the moment this one becomes audible — otherwise every
        // sentence break costs another network round trip of silence.
        final upcoming = _queue.isEmpty ? null : _queue.first;
        try {
          await _voiceService.speak(
            next.text,
            pitch: next.pitch,
            rate: next.rate,
            onAudible: () {
              if (generation != _generation) return;
              _emitPhase(NarrationPhase.speaking);
              if (upcoming != null) {
                _voiceService.prewarm(
                  upcoming.text,
                  pitch: upcoming.pitch,
                  rate: upcoming.rate,
                );
              }
            },
          );
        } catch (_) {
          // Voice output is a nice-to-have. A missing TTS engine or a
          // platform hiccup must never interrupt the chat itself.
        }
      }
    } finally {
      // Only the loop that still owns the flag may clear it: a straggler from
      // an earlier generation finishing late must not hand the live loop's
      // turn back to the next caller.
      if (_drainGeneration == generation) {
        _draining = false;
        if (!_hasPendingWork) _emitPhase(NarrationPhase.idle);
      }
    }
  }

  void _emitPhase(NarrationPhase phase) {
    if (_phase == phase) return;
    // An utterance appended mid-turn must not knock a live turn back to
    // `preparing`: the previous sentence is still playing.
    if (phase == NarrationPhase.preparing && _phase == NarrationPhase.speaking) {
      return;
    }
    _phase = phase;
    if (!_phaseController.isClosed) _phaseController.add(phase);
  }

  /// Joins fragments into one utterance, adding sentence breaks only where
  /// the previous fragment did not already end in punctuation — otherwise
  /// engines pause twice and it sounds stilted.
  static String _joinSentences(List<String> parts) {
    final buffer = StringBuffer();
    for (final part in parts) {
      if (buffer.isNotEmpty) {
        final previous = buffer.toString();
        buffer.write(RegExp(r'[.!?]$').hasMatch(previous) ? ' ' : '. ');
      }
      buffer.write(part);
    }
    return buffer.toString();
  }
}

/// One queued unit of speech: either finished text, or a draft whose wording
/// is still to be chosen.
class _PendingUtterance {
  const _PendingUtterance.text(String text)
      : _text = text,
        _draft = null;

  const _PendingUtterance.draft(SpokenDraft draft)
      : _draft = draft,
        _text = null;

  final String? _text;
  final SpokenDraft? _draft;

  Future<String> resolve(
    SpeechPhraser phraser, {
    required List<String> recentlySpoken,
  }) async {
    final draft = _draft;
    if (draft == null) return _text!;
    try {
      return await phraser.phrase(draft, recentlySpoken: recentlySpoken);
    } catch (_) {
      // A phraser is contractually not allowed to throw, but a broken one
      // must still cost variety rather than the whole utterance.
      return draft.fallbackText;
    }
  }
}
