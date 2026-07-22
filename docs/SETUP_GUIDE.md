# Setup Guide

## 1. Install dependencies and generate code

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

The `build_runner` step generates the `*.freezed.dart` and `*.g.dart` parts
for every DTO in `lib/features/ai_travel_assistant/data/models/`. Re-run it
whenever a `@freezed` class changes shape.

## 2. Run the standalone demo

```bash
flutter run -t lib/main.dart
```

This boots `AiTravelAssistantDemoApp`, initializes Hive, and opens straight
into `ChatPage`. Everything runs against the in-memory mocks — no network
access or API keys required.

## 3. Integrating into a host app

1. Copy `lib/features/ai_travel_assistant/` and the pieces of `lib/core/`
   it needs (`di`, `errors`, `theme`, `utils`) into the host app, merging
   folder names if the host app already has a `core/`.
2. Merge this module's `pubspec.yaml` dependencies into the host app's.
3. In the host app's `main()`, before `runApp`, open the Hive box and
   override the provider:

   ```dart
   await Hive.initFlutter(); // or your existing Hive setup
   final chatHistoryBox = await Hive.openBox<Map>(HiveChatLocalDataSource.boxName);

   runApp(
     ProviderScope(
       overrides: [
         chatHistoryBoxProvider.overrideWithValue(chatHistoryBox),
         // Once a real backend exists:
         // useMockBackendProvider.overrideWithValue(false),
         // dioProvider.overrideWithValue(myConfiguredDio),
       ],
       child: const MyHostApp(),
     ),
   );
   ```

4. Push the assistant from anywhere in the host app:

   ```dart
   Navigator.push(context, AiTravelAssistantEntryPoint.route());
   ```

## 4. Switching from the mock backend to a real one

Everything routes through `useMockBackendProvider` in
`lib/core/di/providers.dart`. Flip it once real endpoints exist (matching
`docs/API_CONTRACTS.md`):

```dart
ProviderScope(
  overrides: [
    useMockBackendProvider.overrideWithValue(false),
    dioProvider.overrideWithValue(
      Dio(BaseOptions(baseUrl: 'https://your-real-api.example.com/v1')),
    ),
  ],
  child: const MyHostApp(),
)
```

No other code changes — every repository, use case, and widget is already
written against the domain interfaces, not the mock/real split.

## 5. Exercising error-handling paths

`MockBackendServer.instance` (in
`lib/features/ai_travel_assistant/services/mock_backend/mock_backend_server.dart`)
exposes toggles for every error scenario called out in the spec:

```dart
MockBackendServer.instance.simulateNetworkError = true;   // no internet
MockBackendServer.instance.simulateTimeout = true;         // API timeout
MockBackendServer.instance.simulateSeatUnavailable = true; // seat taken
MockBackendServer.instance.simulatePaymentFailure = true;  // payment failure
MockBackendServer.instance.simulateAiTimeout = true;       // AI timeout
MockBackendServer.instance.resetErrorInjection();          // back to normal
```

Flip one in a debug menu, in `main()` before `runApp`, or in a test's
`setUp` to see the corresponding `Failure` surface as an inline error
message in the chat.

## 6. Voice permissions (Phase 11)

`speech_to_text` and `flutter_tts` need platform permissions declared in
the **host app's** native projects (this module has no `android/`/`ios/`
folders of its own):

**Android** — `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
```

**iOS** — `ios/Runner/Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Used for voice input to the travel assistant.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Used to transcribe your voice input to the travel assistant.</string>
```

`VoiceService.ensureReady()` triggers the OS permission prompt on first use
via `speech_to_text`'s own `initialize()` call — no extra permission
package is required.

## 7. Running the tests

```bash
flutter test
```

Covers:
- `test/unit/` — use case delegation and `ChatViewModel` intent routing
  (seat selection, low-confidence escalation, baggage confirmation, error
  surfacing), using mocktail doubles for every repository interface.
- `test/repository/` — model→entity mapping and exception→`Failure`
  mapping for a repository implementation.
- `test/widget/` — `ChatBubble` alignment/rendering and `SeatMapCard`
  selection behavior.

`ChatViewModel` tests construct a real `VoiceService()` rather than faking
it — every voice call is wrapped in a try/catch inside the ViewModel
(`_speakSafely`), so the `MissingPluginException` that `flutter_tts`/
`speech_to_text` throw outside a running app (no platform channel in
`flutter_test`) is swallowed exactly like a real TTS-engine failure would
be in production. No special test doubles are needed for voice.

Widget tests that construct `ChatViewModel` indirectly (anything that pumps
`ChatPage` itself) need `chatHistoryBoxProvider` overridden with an
in-memory Hive box (or a fake `ChatHistoryRepository`) — `SeatMapCard`'s
own tests avoid this by not tapping the "Confirm" button, since that's the
only path that reaches the provider.
