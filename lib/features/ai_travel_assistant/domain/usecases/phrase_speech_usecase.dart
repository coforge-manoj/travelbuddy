import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/spoken_draft.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/voice_phrasing_repository.dart';

/// Asks the phrasing model for the wording of one spoken turn.
///
/// Deliberately returns the raw [Result]: deciding what to do with a failure
/// belongs to the caller, and for speech that decision is always the same —
/// fall back to the draft's deterministic text rather than say nothing.
class PhraseSpeechUseCase {
  const PhraseSpeechUseCase(this._repository);
  final VoicePhrasingRepository _repository;

  Future<Result<String>> call({
    required SpokenDraft draft,
    List<String> recentlySpoken = const [],
    bool forDisplay = false,
  }) {
    return _repository.phrase(
      draft: draft,
      recentlySpoken: recentlySpoken,
      forDisplay: forDisplay,
    );
  }
}
