import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/core/di/providers.dart';
import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/chat_history_repository.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/pages/chat_page.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/routes/ai_travel_assistant_routes.dart';

/// In-memory stand-in for the Hive-backed history store, so this test
/// doesn't need a real Hive box — it only needs to prove the view model
/// actually calls `clearHistory()` on every fresh session.
class _FakeChatHistoryRepository implements ChatHistoryRepository {
  final List<ChatMessage> _messages = [];

  @override
  Future<Result<void>> clearHistory() async {
    _messages.clear();
    return const Result.success(null);
  }

  @override
  Future<Result<List<ChatMessage>>> loadHistory() async => Result.success(List.of(_messages));

  @override
  Future<Result<void>> saveMessage(ChatMessage message) async {
    _messages.add(message);
    return const Result.success(null);
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  // The voice plugins have no implementation under `flutter_test`, and a call
  // on an unmocked channel never completes inside `fakeAsync` — which strands
  // every card action at the `await stopSpeaking()` it opens with, so nothing
  // below this would ever get past tapping "Select". Stubbing the platform
  // side lets the chat logic be what the test actually exercises.
  setUp(() {
    const channels = <String>[
      'flutter_tts',
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
      'dev.fluttercommunity.plus/connectivity',
      'plugin.csdcorp.com/speech_to_text',
    ];
    for (final name in channels) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel(name),
        (call) async => null,
      );
    }
  });

  // Deliberately avoids pumpAndSettle: both the typing indicator and the
  // "Select" button's inline spinner animate indefinitely, which would make
  // pumpAndSettle hang. Bounded pumps step past the mock backend's
  // artificial network delays instead.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('leaving and re-opening the chat screen starts a fresh session', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatHistoryRepositoryProvider.overrideWithValue(_FakeChatHistoryRepository()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(AiTravelAssistantEntryPoint.route()),
                  child: const Text('Open chat'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Future<void> openChat() async {
      await tester.tap(find.text('Open chat'));
      await settle(tester);
    }

    /// Offers are not shown proactively any more — they arrive when the
    /// passenger asks. Talkback is on by default, so the composer is behind
    /// the keyboard escape hatch on the voice bar.
    Future<void> askToBook() async {
      await tester.tap(find.byIcon(Icons.keyboard_alt_outlined));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'I want to book a flight');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await settle(tester);
      await settle(tester);
    }

    await openChat();
    expect(find.byType(ChatPage), findsOneWidget);
    expect(find.textContaining('Hello Joe'), findsOneWidget);
    expect(find.text('Flight options'), findsNothing);
    expect(find.text('Choose a seat'), findsNothing);

    await askToBook();
    expect(find.text('Flight options'), findsOneWidget);

    // Mutate the session by booking the first suggested flight — this now
    // starts the guided seat-selection step rather than confirming outright,
    // chaining a book-flight call into a seat-map fetch.
    await tester.ensureVisible(find.text('Select').first);
    await tester.pump();
    await tester.tap(find.text('Select').first, warnIfMissed: false);
    await settle(tester);
    await settle(tester);
    expect(find.text('Choose a seat'), findsOneWidget);

    // Navigate back to the host app, then re-open the assistant.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await settle(tester);
    expect(find.byType(ChatPage), findsNothing);

    await openChat();

    // Fresh session: no leftover booking flow, just the welcome message —
    // and asking again starts the flow over from the offers card.
    expect(find.text('Choose a seat'), findsNothing);
    expect(find.textContaining('Hello Joe'), findsOneWidget);
    expect(find.text('Flight options'), findsNothing);

    await askToBook();
    expect(find.text('Flight options'), findsOneWidget);
  });
}
