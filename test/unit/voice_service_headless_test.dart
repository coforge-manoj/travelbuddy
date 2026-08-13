import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/cartesia_tts_client.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_service.dart';

/// Pins what a default-constructed [VoiceService] may do in a plugin-free
/// environment.
///
/// Several unrelated tests build a real [VoiceService] rather than a fake (see
/// `chat_viewmodel_test.dart`) and depend on it staying inert under
/// `flutter test`, where no platform channel is registered. Nothing else
/// asserts that, so a plausible-looking change would break those tests somewhere
/// far from its cause.
///
/// The split this file pins:
///
/// - **Construction and preparation are channel-free.** `CartesiaSpeechSynthesizer`
///   creates its `AudioPlayer` lazily; `CartesiaTtsClient` reads dotenv inside a
///   try/catch and gives up before any HTTP; `SystemSpeechSynthesizer.prepare`
///   only trims. So a `VoiceService` can be built and asked to prepare a line
///   with no plugins present.
/// - **Playback is not.** `speak`, `stopSpeaking` and `dispose` all reach
///   `flutter_tts` and throw `MissingPluginException` headlessly. That is
///   deliberately *not* swallowed here — `ChatViewModel._speakSafely` and
///   `_stopSpeakingSafely` are the layer that catches it, because voice output
///   is a nice-to-have that must never break the chat flow. Tests that construct
///   a real `VoiceService` must therefore drive it through `ChatViewModel`, or
///   avoid calling the playback methods directly.
///
/// The default summarizer must also stay `const FallbackSpeechSummarizer()`,
/// which is entirely offline. `SpeechSummaryService` is injected from
/// `providers.dart` and must never become the default, or every test in the
/// suite would start making network calls.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('constructing a default VoiceService touches no platform channel', () {
    expect(VoiceService.new, returnsNormally);
  });

  test('empty and whitespace-only lines are dropped before any engine runs', () async {
    final service = VoiceService();

    expect(await service.prepareSpeech(''), isNull);
    expect(await service.prepareSpeech('   \n  '), isNull);
  });

  test('prepareSpeech falls back to the device engine when Cartesia has no key',
      () async {
    final service = VoiceService();

    final prepared = await service.prepareSpeech('Boarding closes at ten past.');

    // Non-null proves the fallback ran rather than the line being dropped;
    // null audio proves it came from the device engine, which renders at play
    // time, and so that Cartesia bailed on the missing key without attempting
    // any HTTP.
    expect(prepared, isNotNull);
    expect(prepared!.audioBytes, isNull);
    expect(prepared.spokenText, 'Boarding closes at ten past.');
  });

  test('CartesiaTtsClient reports no key and synthesizes nothing', () async {
    final client = CartesiaTtsClient(apiKey: '');

    expect(client.hasApiKey, isFalse);
    expect(await client.synthesize('Gate B twelve.'), isNull);
  });
}
