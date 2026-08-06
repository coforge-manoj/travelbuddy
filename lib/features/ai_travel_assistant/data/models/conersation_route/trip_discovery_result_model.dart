class ConversationRouterResult {
  final bool continueConversation;

  final bool requiresReclassification;

  /// Final prompt to send to backend
  final String normalizedPrompt;

  /// Generic context
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
    final updatedContext =
    json['updatedContext'] as Map?;

    return ConversationRouterResult(
      continueConversation:
      json['continueConversation'] == true,
      requiresReclassification:
      json['requiresReclassification'] == true,
      normalizedPrompt:
      json['normalizedPrompt']?.toString() ?? '',
      updatedContext: updatedContext != null
          ? Map<String, dynamic>.from(updatedContext)
          : <String, dynamic>{},
    );
  }
}