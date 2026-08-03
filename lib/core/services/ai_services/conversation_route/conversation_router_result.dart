class ConversationRouterResult {
  final bool continueConversation;

  const ConversationRouterResult({
    required this.continueConversation,
  });

  factory ConversationRouterResult.fromJson(
      Map<String, dynamic> json,
      ) {
    return ConversationRouterResult(
      continueConversation:
      json["continueConversation"] == true,
    );
  }
}