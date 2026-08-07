import 'package:flutter/material.dart';

import 'package:ai_travel_assistant/core/utils/money_format.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';

/// What the passenger settled on in [FlightSelectionSheet].
class FlightSelectionChoice {
  const FlightSelectionChoice({required this.cabin, required this.pax});

  /// `null` when the search priced only one cabin — there was nothing to
  /// choose, so the message should not name one.
  final String? cabin;
  final int pax;
}

/// Cabin and passenger count in one sheet. Prices update as the party grows
/// so the number shown is the one the basket will come back with —
/// per-passenger × pax is exactly how the backend fares it.
class FlightSelectionSheet extends StatefulWidget {
  const FlightSelectionSheet({required this.offer});

  final FlightOffer offer;

  @override
  State<FlightSelectionSheet> createState() => FlightSelectionSheetState();
}

class FlightSelectionSheetState extends State<FlightSelectionSheet> {
  /// Nine is the usual limit on a single booking before it becomes a group
  /// reservation, which this flow does not cover.
  static const _maxPax = 9;

  int _pax = 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final offer = widget.offer;
    final entries = offer.cabinPrices.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    // Fall back to the headline fare when the search priced a single cabin.
    final rows = entries.isEmpty
        ? [MapEntry<String, num>('', offer.price)]
        : entries;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              '${offer.flightNumber} · ${offer.origin} → ${offer.destination}',
              style: theme.textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _pax == 1 ? 'Passenger' : 'Passengers',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                IconButton(
                  onPressed:
                      _pax > 1 ? () => setState(() => _pax--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'One fewer passenger',
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    '$_pax',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed:
                      _pax < _maxPax ? () => setState(() => _pax++) : null,
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'One more passenger',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              rows.length == 1 ? 'Fare' : 'Choose a cabin',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final entry in rows)
                  ListTile(
                    title: Text(entry.key.isEmpty ? 'Selected fare' : entry.key),
                    subtitle: _pax > 1
                        ? Text(
                            '${formatMoney(entry.value, offer.currency)} each',
                          )
                        : null,
                    trailing: Text(
                      formatMoney(entry.value * _pax, offer.currency),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    onTap: () => Navigator.of(context).pop(
                      FlightSelectionChoice(
                        cabin: entry.key.isEmpty ? null : entry.key,
                        pax: _pax,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
