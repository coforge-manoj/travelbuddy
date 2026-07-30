import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_travel_assistant/core/services/shared_preferences_provider.dart';

const _prefsKey = 'voice_output_enabled';
const _defaultValue = false;

/// Whether a fresh chat session starts with text-to-speech read-aloud on —
/// off by default, toggled from the More tab. Applied to a session once, at
/// `ChatViewModel._startNewSession`; toggling mid-conversation still works
/// via `ChatViewModel.toggleVoiceOutput` but doesn't persist here.
class VoiceOutputSettingStore extends StateNotifier<bool> {
  VoiceOutputSettingStore(this._prefs) : super(_prefs.getBool(_prefsKey) ?? _defaultValue);

  final SharedPreferences _prefs;

  Future<void> setEnabled(bool enabled) async {
    if (enabled == state) return;
    state = enabled;
    await _prefs.setBool(_prefsKey, enabled);
  }
}

/// Deliberately not `autoDispose` — the chosen default should outlive
/// individual chat sessions.
final voiceOutputEnabledProvider = StateNotifierProvider<VoiceOutputSettingStore, bool>((ref) {
  return VoiceOutputSettingStore(ref.watch(sharedPreferencesProvider));
});
