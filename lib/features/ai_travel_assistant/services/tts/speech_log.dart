import 'dart:io';

import 'package:flutter/foundation.dart';

/// A running transcript of what the assistant actually says, in the order the
/// passenger hears it.
///
/// [SpeechTrace] answers "why was that slow"; this answers "what was said, and
/// when was it decided". They are separate because the ordering complaints —
/// follow-up suggestions read out before the card they follow up on — are
/// invisible in a latency trace: every stage can be fast and the queue can
/// still be in the wrong order.
///
/// Two numbers make that visible. `q#` is assigned when an utterance joins the
/// speech chain, `▶#` when audio actually starts. If the two sequences
/// disagree with what the turn produced, the ordering bug is in the queueing,
/// not in the synthesizer.
///
/// Every line is prefixed `[speech]` so a session can be pulled out of
/// `flutter run` output with a single grep.
class SpeechLog {
  SpeechLog._();

  /// Off in unit tests (the fakes there would fill the output with lines nobody
  /// is reading) and in release builds.
  static bool enabled =
      kDebugMode && !Platform.environment.containsKey('FLUTTER_TEST');

  static int _queueSeq = 0;
  static int _spokenSeq = 0;

  /// The microphone opening for a turn. Pairs with [heard] to show how long the
  /// passenger was given, and — read against the `▶` lines — whether the loop
  /// ever put the mic up while the assistant was still talking.
  static void listening() => _line('mic', 'listening', null);

  /// What the recognizer finally delivered, and what the loop did with it.
  ///
  /// The input side belongs in the same transcript as the output: an answer
  /// only looks wrong once you can see the words it was answering. The first
  /// captured session had the assistant echoing "light booking" back at the
  /// passenger, which is a recognizer problem wearing a TTS costume.
  static void heard(String transcript, String outcome, {String? detail}) {
    _line(
      'mic',
      'heard → $outcome${detail == null ? '' : ' $detail'}',
      transcript,
    );
  }

  /// A turn where nothing was said, or where what was said was the assistant's
  /// own voice coming back through the microphone.
  static void unheard(String reason, {String? detail}) {
    _line('mic', '$reason${detail == null ? '' : ' $detail'}', null);
  }

  /// A candidate line joining the current burst, before anything is merged or
  /// dropped. [origin] says where the words came from — the backend's reply, or
  /// a card narration built from a payload.
  static void source({
    required String origin,
    required bool factual,
    required String text,
  }) {
    _line('source   ', '$origin factual=$factual', text);
  }

  /// A source that was suppressed before it could be spoken, and why — the
  /// reply superseded by a card narration, or a duplicate of something already
  /// queued in this burst.
  static void dropped(String reason, String text) {
    _line('dropped  ', reason, text);
  }

  /// An utterance joining the speech chain. Returns its queue number, which is
  /// then carried through every later line about the same utterance.
  ///
  /// [kind] distinguishes the turn's answer (`burst`) from the lines spoken but
  /// never shown — the acknowledgement while a turn is in flight, and the
  /// follow-up suggestions read out after it (`aside`).
  static int queued(String kind, String text, {String? detail}) {
    if (!enabled) return 0;
    final id = ++_queueSeq;
    _line('q#$id', 'queued $kind${detail == null ? '' : ' $detail'}', text);
    return id;
  }

  /// The words as the summarizer left them — what will be sent to the
  /// synthesizer, which is not necessarily what was queued.
  static void resolved(int id, String spoken, {required bool summarized}) {
    _line('q#$id', 'resolved summarized=$summarized', spoken);
  }

  /// How a line was split for the pipelined render. Chunk boundaries are heard
  /// as seams, so they belong in the transcript.
  static void chunked(int id, List<String> chunks) {
    if (!enabled || chunks.length < 2) return;
    _line('q#$id', 'split into ${chunks.length} chunks', null);
    for (var i = 0; i < chunks.length; i++) {
      _line('q#$id', '  chunk ${i + 1}/${chunks.length}', chunks[i]);
    }
  }

  /// Audio starting. This is the line to read when the question is what the
  /// passenger heard and in what order.
  static void speaking(int id, String text, {int? chunk, int? ofChunks}) {
    if (!enabled) return;
    final n = ++_spokenSeq;
    final part =
        chunk == null || ofChunks == null || ofChunks < 2 ? '' : ' [$chunk/$ofChunks]';
    _line('▶#$n', 'SPEAKING q#$id$part', text);
  }

  /// The end of an utterance: `outcome` is `done`, or why it never played.
  static void finished(int id, String outcome, {String? detail}) {
    _line('q#$id', 'end $outcome${detail == null ? '' : ' $detail'}', null);
  }

  /// Everything queued was abandoned — an interruption, or leaving the chat.
  static void aborted(String reason) {
    _line('abort    ', reason, null);
  }

  static void _line(String tag, String stage, String? text) {
    if (!enabled) return;
    final body = text == null ? '' : '  "${_flatten(text)}"';
    debugPrint('[speech] ${_clock()} ${_pad(tag, 8)} $stage$body');
  }

  /// Newlines become `⏎` so one utterance stays one grep-able line.
  static String _flatten(String text) =>
      text.trim().replaceAll(RegExp(r'\s*\n+\s*'), ' ⏎ ');

  static String _clock() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(now.hour)}:${two(now.minute)}:${two(now.second)}'
        '.${now.millisecond.toString().padLeft(3, '0')}';
  }

  static String _pad(String value, int width) =>
      value.length >= width ? value : value.padRight(width);
}
