class TripDiscoveryResult {
  final String answer;
  final List<String> suggestions;

  TripDiscoveryResult({
    required this.answer,
    required this.suggestions,
  });

  factory TripDiscoveryResult.fromJson(Map<String, dynamic> json) {
    return TripDiscoveryResult(
      answer: json['answer']?.toString() ?? '',
      suggestions: json['suggestions'] is List
          ? (json['suggestions'] as List)
          .map((e) => e.toString())
          .toList()
          : <String>[],
    );
  }

  factory TripDiscoveryResult.error({
    String message = '',
  }) {
    return TripDiscoveryResult(
      answer: message,
      suggestions: [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'answer': answer,
      'suggestions': suggestions,
    };
  }

  @override
  String toString() {
    return 'TripDiscoveryResult('
        'answer: $answer, '
        'suggestions: $suggestions'
        ')';
  }
}