import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/spoken_draft.dart';

/// Turns a [SpokenDraft] into one natural, polite utterance.
///
/// Implementations do not decide *what* is said — the draft already fixes the
/// facts. They only choose the words, which is why the whole port is a single
/// method with no other state.
abstract interface class VoicePhrasingRepository {
  /// [recentlySpoken] is the tail of what the passenger has already heard this
  /// session, so the phrasing can vary its openers and refer back naturally
  /// instead of restarting the conversation on every turn.
  Future<Result<String>> phrase({
    required SpokenDraft draft,
    List<String> recentlySpoken = const [],
    bool forDisplay = false,
  });
}
