import 'package:shared_preferences/shared_preferences.dart';

/// Remembers whether the passenger wants replies read aloud.
///
/// `chatViewModelProvider` is `autoDispose`, so without persistence the
/// talk-back setting would quietly switch itself back on every time the
/// assistant is re-opened.
class TalkBackPreferenceStore {
  const TalkBackPreferenceStore();

  static const _key = 'ai_travel_assistant.talk_back_enabled';

  /// Returns the stored preference, or `null` when nothing has been stored
  /// yet or the platform has no preferences available — the caller keeps its
  /// default in that case.
  Future<bool?> read() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getBool(_key);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(bool enabled) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_key, enabled);
    } catch (_) {
      // Losing the preference is not worth interrupting the conversation.
    }
  }
}
