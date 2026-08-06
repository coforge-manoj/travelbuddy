import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_travel_assistant/core/services/shared_preferences_provider.dart';

/// The delay choices offered on the More tab's notification settings screen
/// for the post-use-case Journey Concierge reminder.
const reminderDelayOptionsSeconds = <int>[3, 5, 8, 10, 15];

const _defaultReminderDelaySeconds = 5;
const _prefsKey = 'reminder_delay_seconds';

/// Persists the passenger's chosen delay (in seconds) for the post-use-case
/// reminder notification scheduled by `ChatViewModel`, so the choice survives
/// app restarts.
class ReminderDelayStore extends StateNotifier<int> {
  ReminderDelayStore(this._prefs)
      : super(_prefs.getInt(_prefsKey) ?? _defaultReminderDelaySeconds);

  final SharedPreferences _prefs;

  Future<void> setDelaySeconds(int seconds) async {
    if (!reminderDelayOptionsSeconds.contains(seconds) || seconds == state) return;
    state = seconds;
    await _prefs.setInt(_prefsKey, seconds);
  }
}

/// Deliberately not `autoDispose` — the chosen delay should outlive
/// individual chat sessions and screens.
final reminderDelayStoreProvider = StateNotifierProvider<ReminderDelayStore, int>((ref) {
  return ReminderDelayStore(ref.watch(sharedPreferencesProvider));
});
