import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_travel_assistant/core/services/shared_preferences_provider.dart';

const _enginePrefsKey = 'tts_engine';
const _summaryPrefsKey = 'tts_summarize_for_speech';

/// Which backend reads chat replies aloud.
enum TtsEngine {
  /// On-device `flutter_tts`. Works offline, no network latency.
  system,

  /// Cartesia Sonic neural voices. Natural prosody, but needs a network
  /// round-trip per reply and falls back to [system] on failure.
  cartesia;

  String get storageValue => name;

  String get label => switch (this) {
        TtsEngine.system => 'Device voice',
        TtsEngine.cartesia => 'Cartesia neural voice',
      };

  String get description => switch (this) {
        TtsEngine.system =>
          'Uses the voice built into this phone. Works offline, speaks instantly.',
        TtsEngine.cartesia =>
          'Natural Cartesia Sonic voice with proper intonation. Needs a '
              'connection and CARTESIA_API_KEY — falls back to the device '
              'voice automatically.',
      };

  static TtsEngine fromStorage(String? value) {
    // Migrate the previous Edge default onto the current default rather than
    // leaving it unmatched.
    if (value == 'edge') return _defaultEngine;
    return TtsEngine.values.firstWhere(
      (engine) => engine.storageValue == value,
      orElse: () => _defaultEngine,
    );
  }
}

/// The device voice is the default.
///
/// Cartesia sounds far better, but every line costs a network round trip before
/// any audio exists, and on a real device that was the dominant cost of a spoken
/// turn — measured at roughly 0.015s per character, so a card narration took
/// seconds to start. The device engine renders as it plays, so speech begins
/// immediately, which matters more in a hands-free conversation than timbre
/// does.
///
/// Cartesia remains fully wired and is one setting away in the More tab; the
/// intent is to return to it behind a streaming transport that does not have to
/// finish rendering before it can speak.
const _defaultEngine = TtsEngine.system;

/// The chosen TTS backend.
class TtsEngineSettingStore extends StateNotifier<TtsEngine> {
  TtsEngineSettingStore(this._prefs)
      : super(TtsEngine.fromStorage(_prefs.getString(_enginePrefsKey)));

  final SharedPreferences _prefs;

  Future<void> setEngine(TtsEngine engine) async {
    if (engine == state) return;
    state = engine;
    await _prefs.setString(_enginePrefsKey, engine.storageValue);
  }
}

/// Whether replies are condensed for the ear before being spoken. Off means
/// the full on-screen text is read verbatim.
class SpeechSummaryEnabledStore extends StateNotifier<bool> {
  SpeechSummaryEnabledStore(this._prefs)
      : super(_prefs.getBool(_summaryPrefsKey) ?? true);

  final SharedPreferences _prefs;

  Future<void> setEnabled(bool enabled) async {
    if (enabled == state) return;
    state = enabled;
    await _prefs.setBool(_summaryPrefsKey, enabled);
  }
}

/// Not `autoDispose` — the chosen engine outlives individual chat sessions.
final ttsEngineProvider =
    StateNotifierProvider<TtsEngineSettingStore, TtsEngine>((ref) {
  return TtsEngineSettingStore(ref.watch(sharedPreferencesProvider));
});

final speechSummaryEnabledProvider =
    StateNotifierProvider<SpeechSummaryEnabledStore, bool>((ref) {
  return SpeechSummaryEnabledStore(ref.watch(sharedPreferencesProvider));
});
