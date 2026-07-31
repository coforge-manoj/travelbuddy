import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/core/utils/safe_call.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/datasource/voice_phrasing_remote_datasource.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/spoken_draft.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/voice_phrasing_repository.dart';

class VoicePhrasingRepositoryImpl implements VoicePhrasingRepository {
  const VoicePhrasingRepositoryImpl(this._remote);
  final VoicePhrasingRemoteDataSource _remote;

  @override
  Future<Result<String>> phrase({
    required SpokenDraft draft,
    List<String> recentlySpoken = const [],
    bool forDisplay = false,
  }) {
    return safeCall(
      () => _remote.phrase(
        draft: draft,
        recentlySpoken: recentlySpoken,
        forDisplay: forDisplay,
      ),
    );
  }
}
