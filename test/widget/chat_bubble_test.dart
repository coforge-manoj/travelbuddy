import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/chat_bubble.dart';

void main() {
  testWidgets('renders assistant text', (tester) async {
    final message = ChatMessage(
      id: '1',
      role: ChatRole.assistant,
      type: ChatMessageType.text,
      timestamp: DateTime(2026),
      text: 'Your flight is delayed by 35 minutes.',
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ChatBubble(message: message))),
    );

    expect(find.textContaining('delayed by 35 minutes'), findsOneWidget);
  });

  testWidgets('aligns user messages to the right', (tester) async {
    final message = ChatMessage(
      id: '2',
      role: ChatRole.user,
      type: ChatMessageType.text,
      timestamp: DateTime(2026),
      text: 'Is my flight delayed?',
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ChatBubble(message: message))),
    );

    final align = tester.widget<Align>(find.byType(Align));
    expect(align.alignment, Alignment.centerRight);
  });
}
