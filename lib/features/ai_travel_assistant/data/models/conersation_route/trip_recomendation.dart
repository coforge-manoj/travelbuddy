class TripRecommendation {
  final String destination;
  final String country;
  final String reason;
  final String bestTime;
  final String estimatedBudget;
  final String idealDuration;

  const TripRecommendation({
    required this.destination,
    required this.country,
    required this.reason,
    required this.bestTime,
    required this.estimatedBudget,
    required this.idealDuration,
  });

  factory TripRecommendation.fromJson(
      Map<String, dynamic> json,
      ) {
    return TripRecommendation(
      destination: json["destination"]?.toString() ?? "",
      country: json["country"]?.toString() ?? "",
      reason: json["reason"]?.toString() ?? "",
      bestTime: json["bestTime"]?.toString() ?? "",
      estimatedBudget: json["estimatedBudget"]?.toString() ?? "",
      idealDuration: json["idealDuration"]?.toString() ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "destination": destination,
      "country": country,
      "reason": reason,
      "bestTime": bestTime,
      "estimatedBudget": estimatedBudget,
      "idealDuration": idealDuration,
    };
  }
}