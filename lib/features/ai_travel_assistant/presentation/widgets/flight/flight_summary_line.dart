import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';

/// Two lines identifying a flight — `AA50 · DFW → LHR` over its times,
/// duration and aircraft. Repeated on every card that names a held or
/// booked flight.
class FlightSummaryLine extends StatelessWidget {
  const FlightSummaryLine({super.key, required this.flight, this.color});

  final FlightOffer flight;

  /// Set when the card sits on a tinted background and the default
  /// on-surface colours would not read.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat.Hm();
    final arrivalSuffix = flight.arrivesNextDay ? ' +1' : '';

    final meta = <String>[
      '${timeFormat.format(flight.departureTime)} – '
          '${timeFormat.format(flight.arrivalTime)}$arrivalSuffix',
      // Only ever the backend's own figure. Departure and arrival are each
      // local to their own airport, so subtracting them reports 15h10m for
      // a 9h05 DFW–LHR flight — the six-hour offset, not the flight.
      if (flight.durationLabel != null) flight.durationLabel!,
      if (flight.aircraft != null && flight.aircraft!.isNotEmpty)
        flight.aircraft!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${flight.flightNumber} · ${flight.origin} → ${flight.destination}',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          meta.join(' · '),
          style: theme.textTheme.bodySmall?.copyWith(
            color: color?.withOpacity(0.85) ?? theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}
