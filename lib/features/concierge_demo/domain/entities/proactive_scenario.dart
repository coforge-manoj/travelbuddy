import 'package:equatable/equatable.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/action_summary.dart';

/// The Inspire→Arrival journey stage a [ProactiveScenario] belongs to —
/// mirrors the "Stage" column of the Journey Concierge demo playbook.
enum TripStage { inspire, book, preTrip, airport, inFlight, arrival }

extension TripStageLabel on TripStage {
  String get label => switch (this) {
        TripStage.inspire => 'Inspire',
        TripStage.book => 'Book',
        TripStage.preTrip => 'Pre-Trip',
        TripStage.airport => 'Airport',
        TripStage.inFlight => 'In-Flight',
        TripStage.arrival => 'Arrival',
      };
}

/// Whether this moment exists in the American app today — the playbook's
/// "In AA App Today?" column.
enum ScenarioAvailability { no, partial }

extension ScenarioAvailabilityLabel on ScenarioAvailability {
  String get label => switch (this) {
        ScenarioAvailability.no => 'Not in AA app today',
        ScenarioAvailability.partial => 'Partial in AA app today',
      };
}

/// One Parent↔Concierge exchange in a scripted scenario.
class ScenarioTurn extends Equatable {
  const ScenarioTurn({
    required this.parentLine,
    required this.matchKeywords,
    required this.conciergeReply,
  });

  /// The exact "PARENT:" line from the script — shown as the suggested-reply
  /// chip and used as the seed text if the passenger taps it.
  final String parentLine;

  /// Lowercase phrases that indicate a free-typed reply is reaching for this
  /// turn's resolution (e.g. different phrasing of [parentLine]). Informational
  /// for now — [ScenarioChatViewModel] doesn't gate advancement on these,
  /// since each scenario is a single linear path.
  final List<String> matchKeywords;

  /// The exact "CONCIERGE:" reply from the script.
  final String conciergeReply;

  @override
  List<Object?> get props => [parentLine, matchKeywords, conciergeReply];
}

/// One of the Journey Concierge demo playbook's 12 use cases: a proactive
/// notification that, once tapped, opens a scripted multi-turn conversation
/// ending in a concluding action.
class ProactiveScenario extends Equatable {
  const ProactiveScenario({
    required this.id,
    required this.stage,
    required this.useCaseTitle,
    required this.situation,
    required this.notificationText,
    required this.turns,
    required this.concludingAction,
    required this.availability,
  });

  final String id;
  final TripStage stage;
  final String useCaseTitle;
  final String situation;

  /// Exact push-notification copy, including its leading emoji.
  final String notificationText;

  final List<ScenarioTurn> turns;
  final ActionSummary concludingAction;
  final ScenarioAvailability availability;

  @override
  List<Object?> get props => [
        id,
        stage,
        useCaseTitle,
        situation,
        notificationText,
        turns,
        concludingAction,
        availability,
      ];
}
