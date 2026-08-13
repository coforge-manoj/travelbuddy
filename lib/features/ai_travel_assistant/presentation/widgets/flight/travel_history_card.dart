import 'package:flutter/material.dart';

import 'package:ai_travel_assistant/core/utils/app_date.dart';
import 'package:ai_travel_assistant/core/utils/money_format.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/travel_history.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/card_shell.dart';

/// The `travel_history` card: how much the member has flown, and the most
/// recent trips.
///
/// The headline count covers the whole period while the backend only sends
/// the last dozen or so rows, so the two are presented as separate facts —
/// "105 flights, all time" above, recent trips below — rather than implying
/// the list is everything.
class TravelHistoryCard extends StatefulWidget {
  const TravelHistoryCard({super.key, required this.history});

  final TravelHistory history;

  @override
  State<TravelHistoryCard> createState() => _TravelHistoryCardState();
}

class _TravelHistoryCardState extends State<TravelHistoryCard> {
  /// A dozen rows would bury the rest of the conversation.
  static const _collapsedRows = 4;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = widget.history;
    final flights = history.flights;
    final canExpand = flights.length > _collapsedRows;
    final visible =
        _expanded ? flights : flights.take(_collapsedRows).toList();

    return CardShell(
      icon: Icons.history,
      title: 'Your travel history',
      trailing: Text(
        '${history.count}',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        ),
      ),
      children: [
        Text(
          [
            '${history.count} flight${history.count == 1 ? '' : 's'}',
            if (history.scope.isNotEmpty) history.scope,
          ].join(' · '),
          style: theme.textTheme.bodySmall,
        ),
        // Lifetime spend is deliberately not shown. It is in the payload
        // (`TravelHistory.totalSpend`) if it is ever wanted, but a loyalty
        // screen leading with what someone has spent reads like a bill —
        // miles earned is the number they care about.
        if (_lastFlown(history) != null) ...[
          const SizedBox(height: 2),
          Text(
            'Last flown ${_lastFlown(history)}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
        if (visible.isNotEmpty) ...[
          const CardDivider(),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Recent trips',
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          for (final flight in visible) _HistoryRow(flight: flight),
        ],
        if (canExpand)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                _expanded
                    ? 'Show fewer'
                    : 'Show ${flights.length - _collapsedRows} more',
              ),
            ),
          ),
      ],
    );
  }
}

/// The date of the most recent trip, formatted, or `null` when the rows
/// carry no usable date. Taken from the first row because the backend sends
/// them most-recent-first.
String? _lastFlown(TravelHistory history) {
  if (history.flights.isEmpty) return null;
  final raw = history.flights.first.date;
  if (raw.isEmpty) return null;
  return AppDate.formatRaw(raw);
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.flight});

  final TravelHistoryFlight flight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final airports = flight.airports;

    // Only reformat a date we can actually parse; anything else is shown
    // exactly as the backend sent it.
    final dateLabel = AppDate.formatRaw(flight.date) ?? flight.date;

    final meta = <String>[
      if (flight.cabin.isNotEmpty) flight.cabin,
      if (flight.seat != null) 'Seat ${flight.seat}',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    flight.flightNumber,
                    if (airports.isNotEmpty)
                      '${airports.first} → ${airports.last}'
                    else if (flight.route.isNotEmpty)
                      flight.route,
                  ].join(' · '),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (dateLabel.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      dateLabel,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.outline),
                    ),
                  ),
                if (meta.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      meta.join(' · '),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.outline),
                    ),
                  ),
              ],
            ),
          ),
          // Miles earned takes the place the fare would normally occupy.
          if (flight.milesEarned != null && flight.milesEarned! > 0) ...[
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+${formatCount(flight.milesEarned)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E8E3E),
                  ),
                ),
                Text(
                  'miles',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.outline),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
