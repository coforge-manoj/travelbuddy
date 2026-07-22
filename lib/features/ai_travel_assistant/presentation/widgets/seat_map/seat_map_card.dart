import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_viewmodel.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/seat_map/seat_tile.dart';

/// Interactive seat map rendered inline in the chat. Grouped by row, with a
/// legend and a confirm button that calls [ChatViewModel.confirmSeatChange]
/// once the passenger taps an available seat.
class SeatMapCard extends ConsumerStatefulWidget {
  const SeatMapCard({super.key, required this.seatMap});

  final SeatMap seatMap;

  @override
  ConsumerState<SeatMapCard> createState() => _SeatMapCardState();
}

class _SeatMapCardState extends ConsumerState<SeatMapCard> {
  String? _selectedSeatNumber;
  bool _confirmed = false;

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

  Seat? get _selectedSeat {
    final seatNumber = _selectedSeatNumber;
    if (seatNumber == null) return null;
    for (final seat in widget.seatMap.seats) {
      if (seat.seatNumber == seatNumber) return seat;
    }
    return null;
  }

  Future<void> _confirm() async {
    final seatNumber = _selectedSeatNumber;
    if (seatNumber == null || _confirmed) return;
    setState(() => _confirmed = true);
    await ref.read(chatViewModelProvider.notifier).confirmSeatChange(seatNumber);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _seatsByRow.keys.toList()..sort();
    final scheme = Theme.of(context).colorScheme;
    final selectedSeat = _selectedSeat;

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
                Text('Choose a seat', style: Theme.of(context).textTheme.labelLarge),
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
                        isSelected: seat.seatNumber == _selectedSeatNumber,
                        onTap: _confirmed
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
            _Legend(),
            const SizedBox(height: 12),
            if (_confirmed)
              Text(
                'Confirming seat $_selectedSeatNumber…',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: selectedSeat != null && selectedSeat.isAvailable ? _confirm : null,
                  child: Text(
                    selectedSeat == null
                        ? 'Select a seat'
                        : 'Confirm ${selectedSeat.seatNumber}'
                            '${selectedSeat.priceDelta > 0 ? ' (+${selectedSeat.priceDelta.toStringAsFixed(0)} ${widget.seatMap.currency})' : ''}',
                  ),
                ),
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
