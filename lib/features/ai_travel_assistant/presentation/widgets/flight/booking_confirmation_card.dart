import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking_summary.dart';

/// Final itinerary card shown once [ChatViewModel.finishBooking] completes
/// the guided seat/baggage flow — the booking, chosen seat, extra baggage,
/// and the terminal options (gate, terminal, check-in counter, boarding
/// time) needed at the airport.
class BookingConfirmationCard extends StatelessWidget {
  const BookingConfirmationCard({super.key, required this.summary});

  final BookingSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onColor = scheme.onPrimaryContainer;
    final booking = summary.booking;
    final flight = booking.flight;
    final dateFormat = DateFormat('EEE, MMM d · HH:mm');
    final timeFormat = DateFormat.Hm();

    Widget stat(String label, String value) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: onColor),
          ),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: onColor, fontWeight: FontWeight.w600),
          ),
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
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, size: 18, color: onColor),
                const SizedBox(width: 8),
                Text(
                  "You're booked!",
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: onColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${flight.flightNumber} · ${flight.origin} → ${flight.destination}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: onColor, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              dateFormat.format(flight.scheduledDeparture),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: onColor),
            ),
            const SizedBox(height: 6),
            Text(
              'Passenger: ${booking.passengerName}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: onColor),
            ),
            Text(
              'Confirmation: ${booking.pnr}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: onColor),
            ),
            if (summary.seatNumber != null)
              Text(
                'Seat: ${summary.seatNumber}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: onColor),
              ),
            if (summary.extraBaggageKg > 0)
              Text(
                'Extra baggage: +${summary.extraBaggageKg.toStringAsFixed(0)} kg',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: onColor),
              ),
            const SizedBox(height: 12),
            Divider(height: 1, color: onColor.withOpacity(0.25)),
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}
