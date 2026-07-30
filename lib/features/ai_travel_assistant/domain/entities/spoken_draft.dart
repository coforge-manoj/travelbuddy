import 'package:equatable/equatable.dart';

/// What the assistant is talking about. Sent to the phrasing model so it can
/// pick an appropriate register — announcing a delay and confirming a booking
/// should not sound the same.
enum SpokenTopic {
  flightOffers,
  noFlightsFound,
  flightStatus,
  seatMap,
  noSeatsAvailable,
  baggageOptions,
  baggagePurchased,
  baggageFailed,
  bookingConfirmed,
  airportInfo,
  agentEscalation,
}

/// The emotional colour of the utterance. Kept separate from [SpokenTopic]
/// because the same topic swings both ways — a flight status is neutral when
/// on time and apologetic when cancelled.
enum SpokenTone { neutral, apologetic, reassuring, celebratory }

/// What the utterance should invite the passenger to do next, described by
/// purpose rather than by wording. The phrasing layer owns the wording; that
/// is the whole point of this class.
enum SpokenInvitation {
  none,
  chooseOffer,
  confirmSingleOffer,
  chooseSeat,
  chooseBaggage,
  offerOtherDates,
  anythingElse,
  awaitAgent,

  /// Close warmly without asking anything — the turn that ends a booking.
  wishWell,
}

/// The facts of one spoken turn, separated from any particular wording.
///
/// Card summaries used to be fixed sentences, so every booking session in the
/// demo sounded word-for-word identical. A draft instead carries *what* has to
/// be conveyed and leaves *how* to say it to the phrasing layer (see
/// `SpeechPhraser`), which asks an LLM for a fresh, polite rendering and keeps
/// the deterministic [fallbackText] for when that is unavailable.
///
/// Numbers are never left to the model. [clauses] arrive already formatted for
/// speech by `SpeechTextFormatter`, and [mustInclude] lists the fragments that
/// have to survive verbatim — prices, confirmation codes, gates. `SpokenFactGuard`
/// enforces both before a single word reaches the engine.
class SpokenDraft extends Equatable {
  const SpokenDraft({
    required this.topic,
    required this.fallbackText,
    required this.clauses,
    this.invitation = SpokenInvitation.none,
    this.tone = SpokenTone.neutral,
    this.mustInclude = const [],
  });

  final SpokenTopic topic;

  /// The deterministic rendering. Spoken as-is whenever phrasing is disabled,
  /// times out, fails, or comes back with the facts altered — so voice output
  /// degrades to the previous behaviour rather than to silence.
  final String fallbackText;

  /// The facts to convey, each a lower-case clause with no trailing period
  /// ("there are 3 flights from Newark to Chicago") so a phrasing can reorder
  /// and join them freely.
  final List<String> clauses;

  final SpokenInvitation invitation;
  final SpokenTone tone;

  /// Fragments that must appear unchanged in the spoken result. Reserve this
  /// for facts that would be wrong or unsafe to drop — a fare, a confirmation
  /// code, a gate — not for anything the model should be free to leave out.
  final List<String> mustInclude;

  @override
  List<Object?> get props => [topic, fallbackText, clauses, invitation, tone, mustInclude];
}
