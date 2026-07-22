import 'package:flutter/material.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/pages/chat_page.dart';

/// The single integration point a host app needs: push this route (or grab
/// the builder) to present the assistant. Kept as a thin, dependency-free
/// seam so host apps don't need to know about Riverpod providers directly —
/// wrap this in the host app's own `ProviderScope`/router as needed.
class AiTravelAssistantEntryPoint {
  const AiTravelAssistantEntryPoint._();

  static const routeName = '/ai-travel-assistant';

  static Route<void> route() {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: routeName),
      builder: (_) => const ChatPage(),
    );
  }
}
