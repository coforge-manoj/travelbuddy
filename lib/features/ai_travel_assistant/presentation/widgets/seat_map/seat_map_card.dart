import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_viewmodel.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/seat_map/seat_tile.dart';

/// Interactive seat map rendered inline in the chat. Grouped by row, with a
/// legend and a confirm button that calls [ChatViewModel.confirmSeatChange]
/// once the passenger taps an available seat.
class SeatMapCard extends ConsumerStatefulWidget {
  const SeatMapCard({
    super.key,
    required this.seatMap,
    this.isInteractive = true,
    this.confirmedSeatNumber,
    this.highlightedSeatNumber,
    this.showSkip = false,
  });

  final SeatMap seatMap;

  /// False once a seat was confirmed or skipped on this (or a prior) map.
  final bool isInteractive;

  /// Seat confirmed in chat state — kept after ListView recycles this card.
  final String? confirmedSeatNumber;

  /// Seat named by voice or typing and waiting on a spoken confirmation.
  /// Mirrored onto the map so a passenger who said "12A" can see the choice
  /// land before they are asked to agree to it.
  final String? highlightedSeatNumber;

  /// Whether to show Skip (guided booking flow only).
  final bool showSkip;

  @override
  ConsumerState<SeatMapCard> createState() => _SeatMapCardState();
}

class _SeatMapCardState extends ConsumerState<SeatMapCard> {
  String? _selectedSeatNumber;
  bool _confirmed = false;
  bool _skipping = false;

  @override
  void didUpdateWidget(SeatMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A newly spoken seat replaces whatever was tapped earlier — that older
    // choice is not what the assistant is asking about any more. Dropping it
    // here (rather than ranking the two at paint time) keeps a tap *after*
    // the highlight winning, which is what a passenger correcting the
    // assistant expects.
    final highlighted = widget.highlightedSeatNumber;
    if (highlighted != null && highlighted != oldWidget.highlightedSeatNumber) {
      _selectedSeatNumber = null;
    }
  }

  Map<int, List<Seat>> get _seatsByRow {
    final grouped = <int, List<Seat>>{};
    for (final seat in widget.seatMap.seats) {
      grouped.putIfAbsent(seat.row, () => []).add(seat);
    }
    for (final row in grouped.values) {
      row.sort((a, b) => a.column.compareTo(b.column));
    }
    return grouped;
  }

  Seat? _seatByNumber(String? seatNumber) {
    if (seatNumber == null) return null;
    for (final seat in widget.seatMap.seats) {
      if (seat.seatNumber == seatNumber) return seat;
    }
    return null;
  }

  /// What the card is currently offering to confirm: the seat the passenger
  /// tapped, or the one they named out loud and have not answered for yet.
  String? get _pendingSeatNumber => _selectedSeatNumber ?? widget.highlightedSeatNumber;

  Future<void> _confirm() async {
    final seatNumber = _pendingSeatNumber;
    if (!widget.isInteractive || seatNumber == null || _confirmed || _skipping) return;
    setState(() => _confirmed = true);
    await ref.read(chatViewModelProvider.notifier).confirmSeatChange(seatNumber);
  }

  Future<void> _skip() async {
    if (!widget.isInteractive || _confirmed || _skipping) return;
    setState(() => _skipping = true);
    await ref.read(chatViewModelProvider.notifier).skipSeatSelection();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _seatsByRow.keys.toList()..sort();
    final scheme = Theme.of(context).colorScheme;
    final locked = !widget.isInteractive;
    final displaySeatNumber =
        locked ? (widget.confirmedSeatNumber ?? _pendingSeatNumber) : _pendingSeatNumber;
    final selectedSeat = _seatByNumber(displaySeatNumber);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
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
                Icon(Icons.event_seat, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  locked ? 'Seat selection' : 'Choose a seat',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text('$row', style: Theme.of(context).textTheme.labelSmall),
                    ),
                    const SizedBox(width: 4),
                    for (final seat in _seatsByRow[row]!) ...[
                      SeatTile(
                        seat: seat,
                        isSelected: seat.seatNumber == displaySeatNumber,
                        onTap: locked || _confirmed
                            ? null
                            : () => setState(() => _selectedSeatNumber = seat.seatNumber),
                      ),
                      if (seat.column == 'C') const SizedBox(width: 14), // aisle gap
                      const SizedBox(width: 4),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 10),
            const _Legend(),
            const SizedBox(height: 12),
            if (locked)
              Text(
                widget.confirmedSeatNumber != null
                    ? 'Seat ${widget.confirmedSeatNumber} confirmed'
                    : 'Seat selection skipped',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              )
            else if (_confirmed)
              Text(
                'Confirming seat $displaySeatNumber…',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else if (_skipping)
              Text(
                'Skipping seat selection…',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.showSkip)
                    TextButton(
                      onPressed: _skip,
                      child: const Text('Skip'),
                    ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: selectedSeat != null && selectedSeat.isAvailable ? _confirm : null,
                    child: Text(
                      selectedSeat == null
                          ? 'Select a seat'
                          : 'Confirm ${selectedSeat.seatNumber}'
                              '${selectedSeat.priceDelta > 0 ? ' (+${selectedSeat.priceDelta.toStringAsFixed(0)} ${widget.seatMap.currency})' : ''}',
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget swatch(Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        swatch(scheme.tertiaryContainer, 'Window'),
        swatch(scheme.surfaceContainerHigh, 'Standard'),
        swatch(scheme.surfaceContainerHighest, 'Occupied'),
        swatch(scheme.primary, 'Selected'),
      ],
    );
  }
}
