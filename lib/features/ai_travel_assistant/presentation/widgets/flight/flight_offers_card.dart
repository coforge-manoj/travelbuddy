import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:ai_travel_assistant/core/utils/money_format.dart';
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

  /// "Select" opens a sheet rather than committing straight away: the search
  /// prices every flight in all six cabins, and a booking can be for more
  /// than one passenger. Both are decisions the passenger would otherwise
  /// have to make by typing a follow-up turn.
  Future<void> _select(FlightOffer offer) async {
    if (_selectingOfferId != null) return;

    // The tap is the interaction, not the sheet's outcome — stop the reply
    // being read out now rather than only if a cabin is actually picked.
    ref.read(chatViewModelProvider.notifier).stopSpeaking();

    final choice = await showModalBottomSheet<_SelectionChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _FlightSelectionSheet(offer: offer),
    );
    if (choice == null) return; // Dismissed — nothing selected.

    setState(() => _selectingOfferId = offer.id);
    await ref.read(chatViewModelProvider.notifier).selectFlightOffer(
          offer.flightNumber,
          cabin: choice.cabin,
          pax: choice.pax,
        );
    if (mounted) setState(() => _selectingOfferId = null);
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
                onSelect: () => _select(offer),
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
    // The search always sends `duration`; it is never computed from the
    // local departure/arrival times — see [FlightSummaryLine].
    final durationLabel = offer.durationLabel;
    final stopsLabel = offer.isNonstop ? 'Nonstop' : '${offer.stops} stop';
    final arrivalSuffix = offer.arrivesNextDay ? ' +1' : '';

    final metaParts = <String>[
      durationLabel == null ? stopsLabel : '$durationLabel · $stopsLabel',
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

/// What the passenger settled on in [_FlightSelectionSheet].
class _SelectionChoice {
  const _SelectionChoice({required this.cabin, required this.pax});

  /// `null` when the search priced only one cabin — there was nothing to
  /// choose, so the message should not name one.
  final String? cabin;
  final int pax;
}

/// Cabin and passenger count in one sheet. Prices update as the party grows
/// so the number shown is the one the basket will come back with —
/// per-passenger × pax is exactly how the backend fares it.
class _FlightSelectionSheet extends StatefulWidget {
  const _FlightSelectionSheet({required this.offer});

  final FlightOffer offer;

  @override
  State<_FlightSelectionSheet> createState() => _FlightSelectionSheetState();
}

class _FlightSelectionSheetState extends State<_FlightSelectionSheet> {
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
                      _SelectionChoice(
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
