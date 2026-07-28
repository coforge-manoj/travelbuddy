import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking.dart';

/// Confirmation card shown once [ChatViewModel.selectFlightOffer] completes
/// a booking successfully.
class BookingConfirmationCard extends StatelessWidget {
  const BookingConfirmationCard({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onColor = scheme.onPrimaryContainer;
    final flight = booking.flight;
    final dateFormat = DateFormat('EEE, MMM d · HH:mm');

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
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
          ],
        ),
      ),
    );
  }
}
