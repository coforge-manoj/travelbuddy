import 'package:equatable/equatable.dart';

/// The `document_check` card: every traveller's passport measured against the
/// destination's entry rule.
///
/// The backend splits the party across two lists — `ok` and `issues` — rather
/// than one list with a status field. That split is preserved here because it
/// is what the card renders: the passengers who are fine are a reassuring
/// footnote, and the ones who are not are the point.
class DocumentCheck extends Equatable {
  const DocumentCheck({
    this.destination,
    this.ruleDetail,
    this.depart,
    this.returnDate,
    this.ready = false,
    this.clear = const [],
    this.issues = const [],
  });

  final String? destination;

  /// The rule in words, e.g. "Passport must be valid for the entire period of
  /// stay." The machine-readable `rule` key is deliberately not carried — the
  /// card shows the sentence, not the slug.
  final String? ruleDetail;

  final String? depart;
  final String? returnDate;

  /// The overall verdict. False whenever [issues] is non-empty.
  final bool ready;

  /// Passengers whose documents pass, with their expiry dates.
  final List<DocumentClearance> clear;

  /// Passengers who need action before travel.
  final List<DocumentIssue> issues;

  /// Nothing to draw — no passengers on either list.
  bool get isEmpty => clear.isEmpty && issues.isEmpty;

  @override
  List<Object?> get props =>
      [destination, ruleDetail, depart, returnDate, ready, clear, issues];
}

class DocumentClearance extends Equatable {
  const DocumentClearance({required this.passenger, this.expiry});

  final String passenger;
  final String? expiry;

  @override
  List<Object?> get props => [passenger, expiry];
}

class DocumentIssue extends Equatable {
  const DocumentIssue({
    required this.passenger,
    this.issue,
    this.severity,
    this.detail,
    this.action,
  });

  final String passenger;

  /// Machine-readable kind, e.g. `no_passport`, `expires_before_return`.
  final String? issue;

  /// `blocking` is the only value seen so far; anything else is treated as a
  /// warning rather than a hard stop.
  final String? severity;

  /// What is wrong, in words.
  final String? detail;

  /// What to do about it — the half that turns a warning into help.
  final String? action;

  bool get isBlocking => severity?.toLowerCase() == 'blocking';

  @override
  List<Object?> get props => [passenger, issue, severity, detail, action];
}
