class UserIntentResult {
  final String cleanedText;
  final String intent;

  const UserIntentResult({
    required this.cleanedText,
    required this.intent,
  });

 factory UserIntentResult.fromJson(json) {
  final filters = json['filters'];

  return UserIntentResult(
    cleanedText: json['cleanedText']?.toString() ?? '',
    intent: json['action']?.toString() ?? 'unknown',
  );
}

  Map<String, dynamic> toJson() {
    return {
      'cleanedText': cleanedText,
      'intent': intent,
    };
  }
}