import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/core/errors/failures.dart';
import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/spoken_draft.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/voice_phrasing_repository.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/phrase_speech_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/speech_phraser.dart';

const _draft = SpokenDraft(
  topic: SpokenTopic.flightOffers,
  clauses: [
    'there are 2 flights from Newark to Chicago',
    'the lowest fare is Delta Air Lines at 176 dollars',
  ],
  invitation: SpokenInvitation.chooseOffer,
  mustInclude: ['Delta Air Lines', '176 dollars'],
  fallbackText: 'I found 2 flights from Newark to Chicago. The cheapest is Delta Air Lines '
      "at 176 dollars. You're welcome to name an airline.",
);

/// Answers phrasing calls with whatever the test scripted.
class _FakePhrasingRepository implements VoicePhrasingRepository {
  _FakePhrasingRepository(this._respond);

  final Future<Result<String>> Function() _respond;
  List<String>? lastRecentlySpoken;

  @override
  Future<Result<String>> phrase({
    required SpokenDraft draft,
    List<String> recentlySpoken = const [],
    bool forDisplay = false,
  }) {
    lastRecentlySpoken = recentlySpoken;
    return _respond();
  }
}

LlmSpeechPhraser _phraser(
  _FakePhrasingRepository repository, {
  Duration timeout = const Duration(milliseconds: 50),
}) {
  return LlmSpeechPhraser(phraseSpeech: PhraseSpeechUseCase(repository), timeout: timeout);
}

void main() {
  test('speaks the model phrasing when it keeps the facts', () async {
    final phraser = _phraser(
      _FakePhrasingRepository(
        () async => const Result.success(
          'Good news — there are 2 flights to Chicago, and the lowest fare is '
          'Delta Air Lines at 176 dollars. Shall I book that one?',
        ),
      ),
    );

    expect(
      await phraser.phrase(_draft),
      'Good news, there are 2 flights to Chicago, and the lowest fare is '
      'Delta Air Lines at 176 dollars. Shall I book that one?',
    );
  });

  test('falls back when the phrasing alters the facts', () async {
    final phraser = _phraser(
      _FakePhrasingRepository(
        () async => const Result.success(
          'There are 2 flights to Chicago, from about 170 dollars with Delta Air Lines '
          'at 176 dollars. Shall I book it?',
        ),
      ),
    );

    expect(await phraser.phrase(_draft), _draft.fallbackText);
    expect(phraser.lastRejectedPhrasing, contains('170 dollars'));
  });

  test('falls back when the provider fails', () async {
    final phraser = _phraser(
      _FakePhrasingRepository(() async => const Result.failure(NetworkFailure())),
    );

    expect(await phraser.phrase(_draft), _draft.fallbackText);
  });

  test('falls back rather than making the passenger wait on a slow provider', () async {
    final stalled = Completer<Result<String>>();
    final phraser = _phraser(_FakePhrasingRepository(() => stalled.future));

    final stopwatch = Stopwatch()..start();
    final spoken = await phraser.phrase(_draft);
    stopwatch.stop();

    expect(spoken, _draft.fallbackText);
    expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 500)));
    stalled.complete(const Result.success('too late'));
  });

  test('passes what was already heard through to the provider', () async {
    final repository = _FakePhrasingRepository(
      () async => const Result.success('Anything at all.'),
    );

    await _phraser(repository)
        .phrase(_draft, recentlySpoken: const ['Flight U A 4 8 2 is reserved.']);

    expect(repository.lastRecentlySpoken, ['Flight U A 4 8 2 is reserved.']);
  });

  test('the fallback phraser never calls a provider at all', () async {
    expect(await const FallbackSpeechPhraser().phrase(_draft), _draft.fallbackText);
  });
}
