class ConversationContext {
  final Map<String, dynamic> data;

  const ConversationContext({
    this.data = const {},
  });

  factory ConversationContext.fromJson(
      Map<String, dynamic> json,
      ) {
    return ConversationContext(
      data: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toJson() {
    return data;
  }

  ConversationContext copyWith({
    Map<String, dynamic>? data,
  }) {
    return ConversationContext(
      data: data ?? this.data,
    );
  }
}