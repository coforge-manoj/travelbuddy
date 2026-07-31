import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_viewmodel.dart';

/// Lists bookable flight search results; tapping "Select" starts booking via
/// [ChatViewModel.selectFlightOffer].
class FlightOffersCard extends ConsumerStatefulWidget {
  const FlightOffersCard({
    super.key,
    required this.offers,
    this.isInteractive = true,
    this.confirmedOfferId,
    this.hasPendingBooking = false,
  });

  final List<FlightOffer> offers;

  /// False once a flight from this (or a prior) offers card was booked.
  final bool isInteractive;

  /// Offer id already booked — shown as "Selected" on locked cards.
  final String? confirmedOfferId;

  /// True while the guided booking flow is underway.
  final bool hasPendingBooking;

  @override
  ConsumerState<FlightOffersCard> createState() => _FlightOffersCardState();
}

class _FlightOffersCardState extends ConsumerState<FlightOffersCard> {
  String? _selectingOfferId;

  Future<void> _select(String offerId) async {
    if (!widget.isInteractive || widget.hasPendingBooking || _selectingOfferId != null) {
      return;
    }
    setState(() => _selectingOfferId = offerId);
    await ref.read(chatViewModelProvider.notifier).selectFlightOffer(offerId);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final timeFormat = DateFormat.Hm();
    // Also treat as locked while a guided booking is already underway so a
    // scrollback or duplicate offers card cannot start a second booking.
    final locked = !widget.isInteractive || widget.hasPendingBooking;

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
                Text('Flight options', style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 10),
            for (final offer in widget.offers) ...[
              _FlightOfferRow(
                offer: offer,
                timeFormat: timeFormat,
                isBusy: locked || _selectingOfferId != null,
                isSelecting: _selectingOfferId == offer.id,
                isSelected: locked && widget.confirmedOfferId == offer.id,
                onSelect: () => _select(offer.id),
              ),
              if (offer != widget.offers.last)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: scheme.outlineVariant),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FlightOfferRow extends StatelessWidget {
  const _FlightOfferRow({
    required this.offer,
    required this.timeFormat,
    required this.isBusy,
    required this.isSelecting,
    required this.isSelected,
    required this.onSelect,
  });

  final FlightOffer offer;
  final DateFormat timeFormat;
  final bool isBusy;
  final bool isSelecting;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final durationLabel =
        '${offer.duration.inHours}h ${offer.duration.inMinutes.remainder(60)}m';
    final stopsLabel = offer.isNonstop ? 'Nonstop' : '${offer.stops} stop';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${offer.airline} · ${offer.flightNumber}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                '${timeFormat.format(offer.departureTime)} – ${timeFormat.format(offer.arrivalTime)}'
                ' · $durationLabel · $stopsLabel',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.outline),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '\$${offer.price.toStringAsFixed(0)}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 92,
          child: isSelected
              ? Text(
                  'Selected',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                )
              : OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  onPressed: isBusy ? null : onSelect,
                  child: isSelecting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Select'),
                ),
        ),
      ],
    );
  }
}
