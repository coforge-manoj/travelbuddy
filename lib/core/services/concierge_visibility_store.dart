import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_travel_assistant/core/services/shared_preferences_provider.dart';

const _prefsKey = 'show_concierge_moments_on_home';
const _defaultValue = false;

/// Whether the home screen's feed shows the Concierge moments pill list
/// (see `ConciergeMomentsList`) — off by default, toggled from the More tab.
class ConciergeVisibilityStore extends StateNotifier<bool> {
  ConciergeVisibilityStore(this._prefs) : super(_prefs.getBool(_prefsKey) ?? _defaultValue);

  final SharedPreferences _prefs;

  Future<void> setVisible(bool visible) async {
    if (visible == state) return;
    state = visible;
    await _prefs.setBool(_prefsKey, visible);
  }
}

/// Deliberately not `autoDispose` — the chosen visibility should outlive the
/// individual home-screen widget instance.
final conciergeVisibilityStoreProvider = StateNotifierProvider<ConciergeVisibilityStore, bool>((ref) {
  return ConciergeVisibilityStore(ref.watch(sharedPreferencesProvider));
});
