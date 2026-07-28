class UserIntentResult {
  final String cleanedText;
  final String intent;
  final Map<String, dynamic> filters;

  const UserIntentResult({
    required this.cleanedText,
    required this.intent,
    required this.filters,
  });

 factory UserIntentResult.fromJson(Map<String, dynamic> json) {
  final filters = json['filters'];

  return UserIntentResult(
    cleanedText: json['cleanedText']?.toString() ?? '',
    intent: json['intent']?.toString() ?? 'unknown',
    filters: filters is Map
        ? Map<String, dynamic>.from(filters)
        : {},
  );
}

  Map<String, dynamic> toJson() {
    return {
      'cleanedText': cleanedText,
      'intent': intent,
      'filters': filters,
    };
  }
}