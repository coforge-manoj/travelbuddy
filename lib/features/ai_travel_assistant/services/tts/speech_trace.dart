import 'dart:io';

import 'package:flutter/foundation.dart';

/// Stopwatch for one utterance's trip from committed text to audible audio.
///
/// The speech path spans four files and two network calls, so a delay is only
/// diagnosable if every stage reports where it handed off. Each mark prints the
/// time since the trace began and since the previous mark — the second number
/// is the one that names the culprit.
///
/// Stages reach the trace through [current] rather than a threaded parameter:
/// `ChatViewModel._speechChain` runs exactly one utterance at a time, so an
/// ambient trace is unambiguous, and the alternative would put a trace argument
/// on [SpeechSynthesizer] and every fake that implements it.
class SpeechTrace {
  SpeechTrace._(this.id, this.label);

  /// Off in unit tests (the fakes there make the output noise, not signal) and
  /// in release builds; on for `flutter run` in debug, which is where the
  /// delay is being chased.
  static bool enabled =
      kDebugMode && !Platform.environment.containsKey('FLUTTER_TEST');

  /// The utterance currently being prepared or played, if tracing is on.
  static SpeechTrace? current;

  static int _counter = 0;

  final int id;
  final String label;
  final Stopwatch _elapsed = Stopwatch()..start();
  int _lastMarkMs = 0;

  /// Begins a trace and installs it as [current]. Returns `null` when tracing
  /// is off, so callers pay nothing beyond a null check.
  static SpeechTrace? begin(String label, {String? detail}) {
    if (!enabled) return null;
    final trace = SpeechTrace._(++_counter, label);
    current = trace;
    trace._print('┌ $label', detail);
    return trace;
  }

  /// Records a stage on the in-flight utterance. Safe to call from anywhere in
  /// the speech path, including when nothing is being traced.
  static void step(String step, {String? detail}) =>
      current?.mark(step, detail: detail);

  void mark(String step, {String? detail}) {
    if (!enabled) return;
    final now = _elapsed.elapsedMilliseconds;
    final delta = now - _lastMarkMs;
    _lastMarkMs = now;
    _print('│ ${_pad('+${now}ms', 9)}${_pad('Δ${delta}ms', 9)}$step', detail);
  }

  void end({String? detail}) {
    if (!enabled) return;
    _print('└ ${_pad('+${_elapsed.elapsedMilliseconds}ms', 9)}$label done', detail);
    if (identical(current, this)) current = null;
  }

  void _print(String line, String? detail) {
    debugPrint('[tts#$id] $line${detail == null ? '' : '  $detail'}');
  }

  static String _pad(String value, int width) =>
      value.length >= width ? '$value ' : value.padRight(width);
}
