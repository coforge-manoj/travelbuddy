import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/core/services/tts_engine_setting_store.dart';

void main() {
  test('fromStorage migrates the retired Edge value onto the default', () {
    expect(TtsEngine.fromStorage('edge'), TtsEngine.system);
  });

  test('fromStorage defaults to the device voice', () {
    // Cartesia sounds better but cannot speak until a network render finishes,
    // which on a device was the dominant cost of a spoken turn. The device
    // engine renders as it plays, so speech starts immediately — which matters
    // more in a hands-free conversation than timbre does. Cartesia stays wired
    // and is one setting away in the More tab.
    expect(TtsEngine.fromStorage(null), TtsEngine.system);
    expect(TtsEngine.fromStorage('unknown'), TtsEngine.system);
  });

  test('an explicit Cartesia choice is still honoured', () {
    expect(TtsEngine.fromStorage('cartesia'), TtsEngine.cartesia);
  });

  test('Cartesia is labeled for the More tab', () {
    expect(TtsEngine.cartesia.label, contains('Cartesia'));
    expect(TtsEngine.cartesia.storageValue, 'cartesia');
  });
}
