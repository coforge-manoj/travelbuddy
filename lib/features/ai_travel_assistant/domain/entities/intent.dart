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

  /// A lookup of what the member currently holds — miles, voucher, card on
  /// file, tier.
  ///
  /// Exists to keep balance questions away from [tripDiscovery], which
  /// otherwise claims anything mentioning points and answers it with an LLM
  /// that has no access to the member's record — so "can we do this on
  /// miles?" came back asking the passenger for a balance the backend
  /// already knows. Falls through to the `/chat` path like every other
  /// non-discovery intent, where `get_wallet` answers it with real figures.
  wallet,

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
    this.qnPromt='',
    this.classifierFailed = false,
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

  /// True when the classifier never answered — it timed out, errored, or
  /// returned something unparseable.
  ///
  /// Distinct from a confident `unknown` and from a low-confidence guess, and
  /// the difference is what the passenger hears. Both of those mean the
  /// classifier read the message and could not place it, which is worth saying
  /// out loud. This means it never read the message at all, so "I'm not fully
  /// sure I understood that" is a claim about the passenger's wording that
  /// nothing supports — a clear "book me a flight" was met with an offer of a
  /// human agent purely because a router call took longer than ten seconds.
  final bool classifierFailed;

  @override
  List<Object?> get props => [type, confidence, entities, classifierFailed];
}
