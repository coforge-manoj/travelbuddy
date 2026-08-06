class ConversationRouterResult {
  final bool continueConversation;

  final bool requiresReclassification;

  /// Final prompt to be sent to backend
  final String normalizedPrompt;

  /// Generic conversation context
  final Map<String, dynamic> updatedContext;

  const ConversationRouterResult({
    required this.continueConversation,
    this.requiresReclassification = false,
    this.normalizedPrompt = '',
    this.updatedContext = const {},
  });

  factory ConversationRouterResult.fromJson(
      Map<String, dynamic> json,
      ) {
    return ConversationRouterResult(
      continueConversation:
      json['continueConversation'] == true,

      requiresReclassification:
      json['requiresReclassification'] == true,

      normalizedPrompt:
      json['normalizedPrompt']?.toString() ?? '',

      updatedContext: Map<String, dynamic>.from(
        (json['updatedContext'] as Map?) ?? {},
      ),
    );
  }
}