import 'package:equatable/equatable.dart';

/// The `travel_history` card — the member's flown record, answering "my trip
/// details" and "have I ever flown to Tokyo".
///
/// [count] is the total number of flights in [scope], which is not the same
/// as `flights.length`: the backend sends a headline count over the whole
/// period but only the most recent dozen rows to render.
class TravelHistory extends Equatable {
  const TravelHistory({
    required this.count,
    this.scope = '',
    this.totalSpend,
    this.currency = 'USD',
    this.flights = const [],
  });

  final int count;

  /// What the count covers, e.g. `all time` or `2025`. Empty when the
  /// backend did not qualify it.
  final String scope;

  final num? totalSpend;
  final String currency;

  /// The rows to show — most recent first, as the backend orders them.
  final List<TravelHistoryFlight> flights;

  num get totalMilesEarned =>
      flights.fold<num>(0, (sum, f) => sum + (f.milesEarned ?? 0));

  @override
  List<Object?> get props => [count, scope, totalSpend, currency, flights];
}

class TravelHistoryFlight extends Equatable {
  const TravelHistoryFlight({
    required this.flightNumber,
    this.date = '',
    this.route = '',
    this.cabin = '',
    this.fare,
    this.milesEarned,
    this.seat,
  });

  final String flightNumber;

  /// `YYYY-MM-DD` as sent. Kept as the backend's own string so a row with an
  /// unexpected format still renders instead of vanishing.
  final String date;

  /// `DFW→LHR` as sent.
  final String route;

  final String cabin;
  final num? fare;
  final num? milesEarned;
  final String? seat;

  /// The route split into its two airports, when it is in the shape the
  /// backend uses. Empty when it is not, so the caller can fall back to
  /// showing [route] verbatim.
  List<String> get airports {
    final parts = route.split(RegExp(r'\s*(?:→|->|-)\s*'));
    if (parts.length != 2) return const [];
    return parts.map((p) => p.trim()).toList(growable: false);
  }

  @override
  List<Object?> get props =>
      [flightNumber, date, route, cabin, fare, milesEarned, seat];
}
