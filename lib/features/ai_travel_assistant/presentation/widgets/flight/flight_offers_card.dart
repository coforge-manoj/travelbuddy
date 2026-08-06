import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_viewmodel.dart';

/// Lists bookable flight search results; tapping "Select" starts booking via
/// [ChatViewModel.selectFlightOffer].
class FlightOffersCard extends ConsumerStatefulWidget {
  const FlightOffersCard({super.key, required this.offers});

  final List<FlightOffer> offers;

  @override
  ConsumerState<FlightOffersCard> createState() => _FlightOffersCardState();
}

class _FlightOffersCardState extends ConsumerState<FlightOffersCard> {
  String? _selectingOfferId;

  Future<void> _select(String offerId) async {
    if (_selectingOfferId != null) return;
    setState(() => _selectingOfferId = offerId);
    await ref.read(chatViewModelProvider.notifier).selectFlightOffer(offerId);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final timeFormat = DateFormat.Hm();
    final routeLabel = widget.offers.isEmpty
        ? 'Flight options'
        : '${widget.offers.first.origin} → ${widget.offers.first.destination}';

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(14),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
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
                Expanded(
                  child: Text(
                    routeLabel,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final offer in widget.offers) ...[
              _FlightOfferRow(
                offer: offer,
                timeFormat: timeFormat,
                isBusy: _selectingOfferId != null,
                isSelecting: _selectingOfferId == offer.id,
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
    required this.onSelect,
  });

  final FlightOffer offer;
  final DateFormat timeFormat;
  final bool isBusy;
  final bool isSelecting;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final durationLabel = offer.durationLabel ??
        '${offer.duration.inHours}h ${offer.duration.inMinutes.remainder(60).toString().padLeft(2, '0')}m';
    final stopsLabel = offer.isNonstop ? 'Nonstop' : '${offer.stops} stop';
    final arrivalSuffix = offer.arrivesNextDay ? ' +1' : '';

    final metaParts = <String>[
      '$durationLabel · $stopsLabel',
      if (offer.aircraft != null && offer.aircraft!.isNotEmpty) offer.aircraft!,
      if (offer.seatsLeft != null) '${offer.seatsLeft} seats left',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (offer.recommended || offer.lowest) ...[
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (offer.recommended)
                _OfferBadge(
                  label: 'Recommended',
                  color: scheme.primary,
                ),
              if (offer.lowest)
                _OfferBadge(
                  label: 'Lowest fare',
                  color: scheme.tertiary,
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${offer.airline} · ${offer.flightNumber}',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${timeFormat.format(offer.departureTime)} – '
                    '${timeFormat.format(offer.arrivalTime)}$arrivalSuffix',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.outline),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    metaParts.join(' · '),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.outline),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '\$${offer.price.toStringAsFixed(0)}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 92,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
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
        ),
      ],
    );
  }
}

class _OfferBadge extends StatelessWidget {
  const _OfferBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
