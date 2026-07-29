import 'package:equatable/equatable.dart';

enum IntentType {
  searchFlights,
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
  });

  final IntentType type;

  /// 0.0–1.0.
  final double confidence;

  /// Free-form slots extracted from the utterance, e.g. {'weightKg': '10'}.
  final Map<String, String> entities;

  static const double lowConfidenceThreshold = 0.45;

  bool get isLowConfidence => confidence < lowConfidenceThreshold;

  @override
  List<Object?> get props => [type, confidence, entities];

  factory IntentResult.fromJson(Map<String, dynamic> json) {
    return IntentResult(
      type: _parseIntent(
        json['action']?.toString(),
      ),
      confidence:
      (json['confidence'] as num?)?.toDouble() ?? 0.0,
      entities:
      (json['entities'] as Map?)
          ?.map(
            (key, value) => MapEntry(
          key.toString(),
          value.toString(),
        ),
      ) ??
          const {},
    );
  }

  static IntentType _parseIntent(String? value) {
    switch (value) {
      case 'flightStatus':
        return IntentType.flightStatus;

      case 'seatSelection':
        return IntentType.seatSelection;

      case 'addBaggage':
        return IntentType.addBaggage;

      case 'terminalInformation':
        return IntentType.terminalInformation;

      case 'counterInformation':
        return IntentType.counterInformation;

      case 'boardingTime':
        return IntentType.boardingTime;

      case 'airportNavigation':
        return IntentType.airportNavigation;

      case 'baggageAllowance':
        return IntentType.baggageAllowance;

      case 'humanAgent':
        return IntentType.humanAgent;

      case 'faq':
        return IntentType.faq;

      default:
        return IntentType.unknown;
    }
  }
}
