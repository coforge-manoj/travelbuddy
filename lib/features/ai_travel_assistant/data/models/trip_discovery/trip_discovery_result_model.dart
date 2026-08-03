import 'package:ai_travel_assistant/features/ai_travel_assistant/data/models/trip_discovery/trip_discovery_context.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/models/trip_discovery/trip_recomendation.dart';

class TripDiscoveryResult {
  final String status;
  final String summary;
  final TripDiscoveryContext tripContext;
  final List<TripRecommendation> recommendations;
  final String followUpQuestion;

  const TripDiscoveryResult({
    required this.status,
    required this.summary,
    required this.tripContext,
    required this.recommendations,
    required this.followUpQuestion,
  });

  factory TripDiscoveryResult.fromJson(
      Map<String, dynamic> json,
      ) {
    return TripDiscoveryResult(
      status: json["status"]?.toString() ?? "success",

      summary: json["summary"]?.toString() ?? "",

      tripContext: TripDiscoveryContext.fromJson(
        json["tripContext"] is Map
            ? Map<String, dynamic>.from(
          json["tripContext"] as Map,
        )
            : <String, dynamic>{},
      ),

      recommendations: (json["recommendations"] is List)
          ? (json["recommendations"] as List)
          .whereType<Map>()
          .map(
            (e) => TripRecommendation.fromJson(
          Map<String, dynamic>.from(e),
        ),
      )
          .toList()
          : const [],

      followUpQuestion:
      json["followUpQuestion"]?.toString() ?? "",
    );
  }

  factory TripDiscoveryResult.empty() {
    return const TripDiscoveryResult(
      status: "success",
      summary: "",
      tripContext: TripDiscoveryContext(),
      recommendations: [],
      followUpQuestion: "",
    );
  }

  factory TripDiscoveryResult.error({
    required String message,
  }) {
    return TripDiscoveryResult(
      status: "error",
      summary: message,
      tripContext: const TripDiscoveryContext(),
      recommendations: const [],
      followUpQuestion: "",
    );
  }
}