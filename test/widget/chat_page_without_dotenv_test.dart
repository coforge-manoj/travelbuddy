import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_travel_assistant/core/di/providers.dart';
import 'package:ai_travel_assistant/core/services/shared_preferences_provider.dart';
import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/chat_history_repository.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/pages/chat_page.dart';

class _FakeChatHistoryRepository implements ChatHistoryRepository {
  @override
  Future<Result<void>> clearHistory() async => const Result.success(null);

  @override
  Future<Result<List<ChatMessage>>> loadHistory() async =>
      const Result.success(<ChatMessage>[]);

  @override
  Future<Result<void>> saveMessage(ChatMessage message) async =>
      const Result.success(null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Note there is deliberately no `dotenv.load()` anywhere in this file: `.env`
  // belongs to the standalone runner, and a host app embedding this module is
  // under no obligation to have one.
  testWidgets('the chat screen opens without a loaded .env', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatHistoryRepositoryProvider
              .overrideWithValue(_FakeChatHistoryRepository()),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const MaterialApp(home: ChatPage()),
      ),
    );

    // Reading `dotenv.env` at provider-construction time used to throw
    // `NotInitializedError` here, taking the whole screen down before its
    // first frame. The LLM speech summarizer must degrade to the offline one
    // instead.
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(ChatPage), findsOneWidget);
    expect(find.textContaining('Elena'), findsOneWidget);
  });
}
