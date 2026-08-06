enum ConversationRoute {
  continueConversation,
  reclassifyIntent,
}

class ConversationRouterResult {
  final ConversationRoute route;

  final String normalizedPrompt;
  final Map<String, dynamic> updatedContext;

  const ConversationRouterResult({
    required this.route,
    this.normalizedPrompt = '',
    this.updatedContext = const {},
  });

  bool get continueConversation =>
      route == ConversationRoute.continueConversation;

  bool get requiresReclassification =>
      route == ConversationRoute.reclassifyIntent;
}