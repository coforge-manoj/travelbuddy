import 'package:ai_travel_assistant/core/errors/failures.dart';
import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/spoken_draft.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/phrase_speech_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/spoken_fact_guard.dart';

/// Chooses the words for one spoken turn.
abstract interface class SpeechPhraser {
  /// Always resolves to something speakable. Implementations must never throw
  /// and never return an empty string — voice output degrading to silence is
  /// worse than voice output sounding plain.
  Future<String> phrase(SpokenDraft draft, {List<String> recentlySpoken});
}

/// Speaks the draft's deterministic text. Used when LLM phrasing is switched
/// off, and by tests that assert on exact spoken copy.
class FallbackSpeechPhraser implements SpeechPhraser {
  const FallbackSpeechPhraser();

  @override
  Future<String> phrase(SpokenDraft draft, {List<String> recentlySpoken = const []}) async {
    return draft.fallbackText;
  }
}

/// Asks the phrasing model to word the turn, and takes the answer only if it
/// arrives in time and still states the draft's facts.
///
/// Three things make this safe to put on the path to the speaker:
///  * [timeout] — the passenger waits for the model, so the wait is bounded
///    and a slow provider costs variety, not responsiveness;
///  * [SpokenFactGuard] — a phrasing that alters a price or drops a
///    confirmation code is discarded rather than spoken;
///  * the fallback — every rejection path ends at
///    [SpokenDraft.fallbackText], which is the copy this app spoke before
///    phrasing existed.
class LlmSpeechPhraser implements SpeechPhraser {
  LlmSpeechPhraser({
    required PhraseSpeechUseCase phraseSpeech,
    this.timeout = const Duration(milliseconds: 1200),
  }) : _phraseSpeech = phraseSpeech;

  final PhraseSpeechUseCase _phraseSpeech;

  /// Budget for the whole call. Roughly the longest pause that still reads as
  /// the assistant thinking rather than as the app having stalled.
  final Duration timeout;

  /// Set when a phrasing was returned but refused by the guard. Surfaced for
  /// debugging a misbehaving prompt — nothing in the UI depends on it.
  String? lastRejectedPhrasing;

  @override
  Future<String> phrase(SpokenDraft draft, {List<String> recentlySpoken = const []}) async {
    final result = await _phraseSpeech(draft: draft, recentlySpoken: recentlySpoken)
        .timeout(timeout, onTimeout: () => const Result<String>.failure(TimeoutFailure()));

    return result.fold(
      (_) => draft.fallbackText,
      (phrasing) {
        final verified = SpokenFactGuard.verify(phrasing, draft);
        if (verified == null) {
          lastRejectedPhrasing = phrasing;
          return draft.fallbackText;
        }
        return verified;
      },
    );
  }
}
