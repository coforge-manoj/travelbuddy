import 'package:equatable/equatable.dart';

/// Icon shown on an [ActionSummary] card. Kept as a small closed set here
/// (rather than a raw `IconData`) so the domain layer stays UI-agnostic —
/// the presentation layer maps each value to a concrete `Icons.*` glyph.
enum ActionIcon {
  checkCircle,
  bookmark,
  document,
  route,
  clock,
  info,
  family,
  luggage,
  seat,
  passport,
  celebration,
}

/// A generic "here's what I just did for you" summary — the concluding
/// action shown at the end of a guided conversation (e.g. a plan saved, a
/// booking confirmed, a checklist sent, a connection changed). Distinct from
/// the existing booking/baggage/seat cards, which carry structured domain
/// payloads specific to those flows; this one is intentionally free-form so
/// any chat-driven feature can use it without adding a bespoke card type.
class ActionSummary extends Equatable {
  const ActionSummary({
    required this.icon,
    required this.headline,
    this.details = const [],
    this.footer,
  });

  final ActionIcon icon;
  final String headline;
  final List<String> details;
  final String? footer;

  @override
  List<Object?> get props => [icon, headline, details, footer];
}
