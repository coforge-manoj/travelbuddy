import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/spoken_draft.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/speech_phraser.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/speech_prosody_planner.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_narrator.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_service.dart';

/// Records what would be spoken and lets each utterance be completed by the
/// test, so serialization can be observed rather than guessed at.
class _FakeVoiceService extends VoiceService {
  final List<String> spoken = [];
  final List<double> pitches = [];
  final List<double> rates = [];
  final List<Completer<void>> _pending = [];
  int stopCount = 0;

  @override
  Future<void> speak(
    String text, {
    double pitch = SpeechProsodyPlanner.statementPitch,
    double rate = SpeechProsodyPlanner.statementRate,
  }) {
    spoken.add(text);
    pitches.add(pitch);
    rates.add(rate);
    final completer = Completer<void>();
    _pending.add(completer);
    return completer.future;
  }

  @override
  Future<void> stopSpeaking() async {
    stopCount++;
    for (final completer in _pending) {
      if (!completer.isCompleted) completer.complete();
    }
    _pending.clear();
  }

  /// Finishes the utterance currently playing.
  void finishCurrent() {
    final pending = _pending.where((completer) => !completer.isCompleted).toList();
    if (pending.isEmpty) return;
    pending.first.complete();
  }
}

void main() {
  // `VoiceService`'s superclass constructor builds a FlutterTts, which
  // registers a method-call handler and needs a binding to exist first.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeVoiceService voice;
  late VoiceNarrator narrator;

  const window = Duration(milliseconds: 20);

  setUp(() {
    voice = _FakeVoiceService();
    narrator = VoiceNarrator(voiceService: voice, coalesceWindow: window);
  });

  tearDown(() => narrator.dispose());

  /// Waits for coalesce, then completes each segment until the narrator is idle.
  Future<void> drainUntilIdle() async {
    await Future<void>.delayed(window * 3);
    for (var i = 0; i < 50 && narrator.isBusy; i++) {
      voice.finishCurrent();
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  test('messages appended in the same turn are spoken as sentence segments', () async {
    narrator.enqueue('Flight U A 4 8 2 is reserved.');
    narrator.enqueue('The seat map is on screen. Window or aisle?');

    await drainUntilIdle();

    expect(voice.spoken, [
      'Flight U A 4 8 2 is reserved.',
      'The seat map is on screen.',
      'Window or aisle?',
    ]);
    expect(voice.pitches[0], SpeechProsodyPlanner.densePitch);
    expect(voice.rates[0], SpeechProsodyPlanner.denseRate);
    expect(voice.pitches[1], SpeechProsodyPlanner.statementPitch);
    expect(voice.pitches[2], SpeechProsodyPlanner.questionPitch);
  });

  test('a sentence break is only added where one is missing', () async {
    narrator.enqueue('Seat 14 A confirmed');
    narrator.enqueue('Want to add bags?');

    await drainUntilIdle();

    expect(voice.spoken, [
      'Seat 14 A confirmed.',
      'Want to add bags?',
    ]);
    expect(voice.pitches.last, SpeechProsodyPlanner.questionPitch);
  });

  test('a later utterance queues behind the current one instead of cutting it off', () async {
    narrator.enqueue('First turn.');
    await Future<void>.delayed(window * 3);
    expect(voice.spoken, ['First turn.']);

    // Arrives while the first is still playing.
    narrator.enqueue('Second turn.');
    await Future<void>.delayed(window * 3);
    expect(voice.spoken, ['First turn.'], reason: 'must wait for the first to finish');

    voice.finishCurrent();
    await Future<void>.delayed(window * 3);
    expect(voice.spoken, ['First turn.', 'Second turn.']);
  });

  test('stopAll discards the queue rather than letting it resume', () async {
    narrator.enqueue('Playing now.');
    await Future<void>.delayed(window * 3);
    narrator.enqueue('Queued behind it.');
    await Future<void>.delayed(window * 3);

    await narrator.stopAll();
    await Future<void>.delayed(window * 3);

    expect(voice.spoken, ['Playing now.']);
    expect(voice.stopCount, 1);
    expect(narrator.isBusy, isFalse);
  });

  test('reports speaking while busy and idle once drained', () async {
    final states = <bool>[];
    narrator.speakingChanges.listen(states.add);

    narrator.enqueue('Anything.');
    await Future<void>.delayed(window * 3);
    expect(states, [true]);

    voice.finishCurrent();
    await Future<void>.delayed(window * 3);
    expect(states, [true, false]);
  });

  test('blank utterances are ignored', () async {
    narrator.enqueue('   ');
    await Future<void>.delayed(window * 3);

    expect(voice.spoken, isEmpty);
    expect(narrator.isBusy, isFalse);
  });

  test('coalesced statement then question use different pitch', () async {
    narrator.enqueue('I found one flight from Newark to Dubai.');
    narrator.enqueue('Would you like me to book it for you?');

    await drainUntilIdle();

    expect(voice.spoken, [
      'I found one flight from Newark to Dubai.',
      'Would you like me to book it for you?',
    ]);
    expect(voice.pitches[0], SpeechProsodyPlanner.statementPitch);
    expect(voice.rates[0], SpeechProsodyPlanner.statementRate);
    expect(voice.pitches[1], SpeechProsodyPlanner.questionPitch);
    expect(voice.rates[1], SpeechProsodyPlanner.questionRate);
  });

  group('phrased drafts', () {
    late _ScriptedPhraser phraser;
    late VoiceNarrator phrasing;

    setUp(() {
      phraser = _ScriptedPhraser();
      phrasing = VoiceNarrator(
        voiceService: voice,
        phraser: phraser,
        coalesceWindow: window,
      );
    });

    tearDown(() => phrasing.dispose());

    Future<void> settle() async {
      for (var i = 0; i < 50 && phrasing.isBusy; i++) {
        voice.finishCurrent();
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    test("the phraser's wording is spoken, not the draft's fallback", () async {
      phraser.answers['flight_offers'] = 'Good news, there are two options.';
      phrasing.enqueueDraft(_draft('flight_offers'));

      await settle();

      expect(voice.spoken, ['Good news, there are two options.']);
    });

    test('a draft that the phraser cannot word falls back to its own text', () async {
      phraser.throwFor.add('flight_offers');
      phrasing.enqueueDraft(_draft('flight_offers'));

      await settle();

      expect(voice.spoken, ['Fallback for flight_offers.']);
    });

    test('a slow phrasing holds its place instead of being overtaken', () async {
      phraser.manual.add('slow');
      phraser.answers['slow'] = 'The slow turn.';
      phraser.answers['fast'] = 'The fast turn.';

      phrasing.enqueueDraft(_draft('slow'));
      await Future<void>.delayed(window * 3);

      // Arrives — and would resolve — while the first is still being worded.
      phrasing.enqueueDraft(_draft('fast'));
      await Future<void>.delayed(window * 3);
      expect(voice.spoken, isEmpty, reason: 'nothing may be spoken out of order');

      phraser.release('slow');
      await settle();

      expect(voice.spoken, ['The slow turn.', 'The fast turn.']);
    });

    test('reports busy while a phrasing is still resolving', () async {
      phraser.manual.add('flight_offers');
      phrasing.enqueueDraft(_draft('flight_offers'));
      await Future<void>.delayed(window * 3);

      expect(phrasing.isBusy, isTrue);
      expect(voice.spoken, isEmpty);

      phraser.release('flight_offers');
      await settle();

      expect(phrasing.isBusy, isFalse);
    });

    test('stopAll during phrasing discards the utterance rather than speaking it late', () async {
      phraser.manual.add('flight_offers');
      phrasing.enqueueDraft(_draft('flight_offers'));
      await Future<void>.delayed(window * 3);

      await phrasing.stopAll();
      phraser.release('flight_offers');
      await Future<void>.delayed(window * 3);

      expect(voice.spoken, isEmpty);
      expect(phrasing.isBusy, isFalse);
    });

    test('the phraser is shown what the passenger has already heard', () async {
      phrasing.enqueue('Flight U A 4 8 2 is reserved.');
      await settle();
      phrasing.enqueueDraft(_draft('seat_map'));
      await settle();

      expect(phraser.lastRecentlySpoken, ['Flight U A 4 8 2 is reserved.']);
    });
  });
}

SpokenDraft _draft(String topicTag) {
  return SpokenDraft(
    // The tag rides in the clauses so the scripted phraser can tell drafts
    // apart; `SpokenTopic` itself is too coarse for that.
    topic: SpokenTopic.flightOffers,
    clauses: [topicTag],
    fallbackText: 'Fallback for $topicTag.',
  );
}

/// A phraser whose answer per draft is scripted, and which can be held open so
/// ordering and cancellation are observable rather than timing-dependent.
class _ScriptedPhraser implements SpeechPhraser {
  final Map<String, String> answers = {};
  final Set<String> manual = {};
  final Set<String> throwFor = {};
  final Map<String, Completer<void>> _held = {};

  List<String> lastRecentlySpoken = const [];

  @override
  Future<String> phrase(SpokenDraft draft, {List<String> recentlySpoken = const []}) async {
    lastRecentlySpoken = recentlySpoken;
    final tag = draft.clauses.first;

    if (manual.contains(tag)) {
      final gate = _held.putIfAbsent(tag, Completer<void>.new);
      await gate.future;
    }
    if (throwFor.contains(tag)) throw StateError('phraser broke');
    return answers[tag] ?? draft.fallbackText;
  }

  void release(String tag) {
    final gate = _held.putIfAbsent(tag, Completer<void>.new);
    if (!gate.isCompleted) gate.complete();
  }
}
