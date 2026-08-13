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
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/pages/voice_conversation_page.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_viewmodel.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/message_composer.dart';

class _FakeChatHistoryRepository implements ChatHistoryRepository {
  final List<ChatMessage> _messages = [];

  @override
  Future<Result<void>> clearHistory() async {
    _messages.clear();
    return const Result.success(null);
  }

  @override
  Future<Result<List<ChatMessage>>> loadHistory() async =>
      Result.success(List.of(_messages));

  @override
  Future<Result<void>> saveMessage(ChatMessage message) async {
    _messages.add(message);
    return const Result.success(null);
  }
}

/// Closing audio mode must leave the whole conversation behind as text.
///
/// The risk this guards is specific and silent: `chatViewModelProvider` is
/// `autoDispose`, and `ChatViewModel._startNewSession` clears history and
/// reseeds a welcome message on construction. If the voice page were ever
/// pushed as a *replacement* rather than over a mounted `ChatPage`, the
/// notifier would be torn down and rebuilt, and the passenger would come back
/// to an empty chat with no error anywhere. Counting welcome messages is what
/// detects that: a second one means the view model was rebuilt.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Both the typing indicator and inline spinners animate forever, so
  // pumpAndSettle would hang. Bounded pumps step past them instead.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 700));
  }

  Future<void> pumpChat(WidgetTester tester) async {
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
    await settle(tester);
  }

  testWidgets('the composer offers audio mode without changing the mic',
      (tester) async {
    await pumpChat(tester);

    final composer = tester.widget<MessageComposer>(find.byType(MessageComposer));

    // The new leading control.
    expect(composer.onAudioModePressed, isNotNull);
    expect(find.byIcon(Icons.graphic_eq), findsOneWidget);

    // The existing speech-to-text input is untouched: same trailing mic, same
    // one-shot behaviour.
    expect(composer.onMicPressed, isNotNull);
    expect(find.byIcon(Icons.mic_none), findsWidgets);
  });

  testWidgets('opening audio mode keeps the conversation underneath alive',
      (tester) async {
    await pumpChat(tester);

    final before = tester
        .state<ConsumerState<ChatPage>>(find.byType(ChatPage))
        .ref
        .read(chatViewModelProvider)
        .messages
        .length;
    expect(before, greaterThan(0));

    await tester.tap(find.byIcon(Icons.graphic_eq));
    await settle(tester);
    expect(find.byType(VoiceConversationPage), findsOneWidget);

    // ChatPage is covered but still mounted, so its `ref.watch` keeps the
    // autoDispose notifier alive.
    expect(find.byType(ChatPage, skipOffstage: false), findsOneWidget);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await settle(tester);

    expect(find.byType(VoiceConversationPage), findsNothing);
    expect(find.byType(ChatPage), findsOneWidget);
  });

  testWidgets('the transcript survives a round trip through audio mode',
      (tester) async {
    await pumpChat(tester);

    final chatState = tester.state<ConsumerState<ChatPage>>(
      find.byType(ChatPage),
    );
    final messagesBefore =
        chatState.ref.read(chatViewModelProvider).messages.toList();
    final welcomeCountBefore = messagesBefore
        .where((m) => m.text.contains('Hello'))
        .length;

    await tester.tap(find.byIcon(Icons.graphic_eq));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await settle(tester);

    final messagesAfter =
        chatState.ref.read(chatViewModelProvider).messages.toList();

    // Nothing lost.
    expect(messagesAfter.length, greaterThanOrEqualTo(messagesBefore.length));
    for (final message in messagesBefore) {
      expect(messagesAfter.map((m) => m.id), contains(message.id));
    }

    // And nothing restarted: a second welcome message would mean the view model
    // was rebuilt and the conversation silently reset.
    final welcomeCountAfter =
        messagesAfter.where((m) => m.text.contains('Hello')).length;
    expect(welcomeCountAfter, welcomeCountBefore);
  });

  testWidgets('re-entering audio mode continues the same conversation',
      (tester) async {
    await pumpChat(tester);

    final chatState = tester.state<ConsumerState<ChatPage>>(
      find.byType(ChatPage),
    );
    final viewModel = chatState.ref.read(chatViewModelProvider.notifier);

    // In and out once.
    await tester.tap(find.byIcon(Icons.graphic_eq));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await settle(tester);

    // A typed turn in between, the way a passenger would switch surfaces.
    viewModel.debugAppendMessages([
      ChatMessage(
        id: 'typed-answer',
        role: ChatRole.assistant,
        type: ChatMessageType.text,
        timestamp: DateTime(2026),
        text: 'Your gate is B twelve.',
      ),
    ]);
    await settle(tester);

    // Back in.
    await tester.tap(find.byIcon(Icons.graphic_eq));
    await settle(tester);

    final messages = chatState.ref.read(chatViewModelProvider).messages;
    expect(messages.map((m) => m.id), contains('typed-answer'));
    expect(messages.where((m) => m.text.contains('Hello')).length, 1);
  });
}
