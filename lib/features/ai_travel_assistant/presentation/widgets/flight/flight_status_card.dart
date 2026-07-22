import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight.dart';

/// Read-only summary of a flight's current status, gate, terminal, counter,
/// and boarding time.
class FlightStatusCard extends StatelessWidget {
  const FlightStatusCard({super.key, required this.flight});

  final Flight flight;

  Color _statusColor(ColorScheme scheme) {
    return switch (flight.status) {
      FlightStatus.delayed || FlightStatus.cancelled => scheme.error,
      FlightStatus.boarding => scheme.primary,
      FlightStatus.departed || FlightStatus.landed => scheme.outline,
      FlightStatus.scheduled || FlightStatus.unknown => scheme.primary,
    };
  }

  String get _statusLabel => switch (flight.status) {
        FlightStatus.scheduled => 'Scheduled',
        FlightStatus.boarding => 'Boarding',
        FlightStatus.delayed => 'Delayed',
        FlightStatus.departed => 'Departed',
        FlightStatus.cancelled => 'Cancelled',
        FlightStatus.landed => 'Landed',
        FlightStatus.unknown => 'Unknown',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = _statusColor(scheme);
    final timeFormat = DateFormat.Hm();

    Widget stat(String label, String value) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.outline),
          ),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.flight_takeoff, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(flight.flightNumber, style: Theme.of(context).textTheme.labelLarge),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: statusColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${flight.origin} → ${flight.destination}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.outline),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              runSpacing: 12,
              children: [
                stat('Gate', flight.gate ?? '—'),
                stat('Terminal', flight.terminal ?? '—'),
                stat('Counter', flight.checkInCounter ?? '—'),
                if (flight.boardingTime != null)
                  stat('Boarding', timeFormat.format(flight.boardingTime!)),
                stat(
                  'Departure',
                  timeFormat.format(flight.estimatedDeparture ?? flight.scheduledDeparture),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
