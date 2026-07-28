import 'package:flutter/material.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();

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

    await openChat();
    expect(find.byType(ChatPage), findsOneWidget);
    expect(find.textContaining('Hello Joe'), findsOneWidget);
    expect(find.text('Flight options'), findsOneWidget);
    expect(find.text("You're booked!"), findsNothing);

    // Mutate the session by booking the first suggested flight.
    await tester.ensureVisible(find.text('Select').first);
    await tester.pump();
    await tester.tap(find.text('Select').first, warnIfMissed: false);
    await settle(tester);
    expect(find.text("You're booked!"), findsOneWidget);

    // Navigate back to the host app, then re-open the assistant.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await settle(tester);
    expect(find.byType(ChatPage), findsNothing);

    await openChat();

    // Fresh session: no leftover booking, just the welcome + offers again.
    expect(find.text("You're booked!"), findsNothing);
    expect(find.textContaining('Hello Joe'), findsOneWidget);
    expect(find.text('Flight options'), findsOneWidget);
  });
}
