import 'package:equatable/equatable.dart';

enum IntentType {
  searchFlights,
  bookFlight,
  flightStatus,
  seatSelection,
  addBaggage,
  terminalInformation,
  counterInformation,
  boardingTime,
  airportNavigation,
  baggageAllowance,
  humanAgent,
  faq,

  tripDiscovery,
  tripRecommendation,
  travelDocuments,
  itineraryOptimization,
  travelPlanning,
  destinationGuidance,
  airportAmenities,
  inflightAssistance,
  arrivalAssistance,
  baggageTracking,
  tripManagement,

  unknown,
}


/// Result of classifying a passenger's free-text message into an actionable
/// intent, along with a confidence score used to decide whether to offer
/// human escalation instead of guessing.
class IntentResult extends Equatable {
  const IntentResult({
    required this.type,
    required this.confidence,
    this.entities = const {},
    this.originalMessage='',
    this.qnPromt=''

  });

  final IntentType type;

  /// 0.0–1.0.
  final double confidence;

  /// Free-form slots extracted from the utterance, e.g. {'weightKg': '10'}.
  final Map<String, String> entities;

  static const double lowConfidenceThreshold = 0.45;

  bool get isLowConfidence => confidence < lowConfidenceThreshold;
  final String originalMessage;
  final String qnPromt;

  @override
  List<Object?> get props => [type, confidence, entities];
}
