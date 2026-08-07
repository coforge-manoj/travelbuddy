import 'package:flutter/material.dart';

import 'package:ai_travel_assistant/core/utils/money_format.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/cabin_seat_map.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/card_shell.dart';

/// The `seat_map` card: the live map, grouped by cabin and row. Tapping an
/// available seat takes it by sending the sentence the passenger would have
/// typed — the backend validates against this same map, so a seat that goes
/// while the card is on screen still comes back as a clean refusal.
class CabinSeatMapCard extends StatefulWidget {
  const CabinSeatMapCard({
    super.key,
    required this.seatMap,
    required this.onSeatSelected,
  });

  final CabinSeatMap seatMap;

  /// Called with the seat number, e.g. `12A`.
  final ValueChanged<String> onSeatSelected;

  @override
  State<CabinSeatMapCard> createState() => _CabinSeatMapCardState();
}

class _CabinSeatMapCardState extends State<CabinSeatMapCard> {
  /// A full cabin can run to forty rows; showing them all would bury the
  /// rest of the conversation, so the card opens on the first few.
  static const _collapsedRowCount = 6;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final seatMap = widget.seatMap;
    final allRows = _flattenRows(seatMap);
    final canExpand = allRows.length > _collapsedRowCount;
    final visibleRows =
        _expanded ? allRows : allRows.take(_collapsedRowCount).toList();

    return CardShell(
      icon: Icons.airline_seat_recline_normal_outlined,
      title: seatMap.flightNumber.isEmpty
          ? 'Choose a seat'
          : 'Choose a seat · ${seatMap.flightNumber}',
      children: [
        for (var i = 0; i < visibleRows.length; i++) ...[
          // Head each run of rows with its cabin name, so a collapsed card
          // that starts mid-cabin still says which cabin it is showing.
          if (visibleRows[i].cabinName.isNotEmpty &&
              (i == 0 ||
                  visibleRows[i].cabinName != visibleRows[i - 1].cabinName))
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 8, bottom: 6),
              child: CardBadge(label: visibleRows[i].cabinName),
            ),
          _seatRow(visibleRows[i]),
        ],
        const SizedBox(height: 6),
        if (canExpand)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(_expanded ? 'Show fewer rows' : 'Show all rows'),
            ),
          ),
        const SizedBox(height: 4),
        _Legend(currency: seatMap.currency),
      ],
    );
  }

  /// Every cabin's rows in one ordered list, so collapsing is a simple
  /// `take` rather than a budget threaded through each cabin.
  List<_SeatRow> _flattenRows(CabinSeatMap seatMap) {
    final rows = <_SeatRow>[];
    for (final cabin in seatMap.cabins) {
      final byRow = cabin.seatsByRow.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      for (final entry in byRow) {
        rows.add(
          _SeatRow(
            cabinName: cabin.name,
            rowNumber: entry.key,
            seats: entry.value,
          ),
        );
      }
    }
    return rows;
  }

  Widget _seatRow(_SeatRow row) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${row.rowNumber}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final seat in row.seats)
                  _SeatChip(
                    seat: seat,
                    currency: widget.seatMap.currency,
                    isCurrent: seat.seatNumber == widget.seatMap.currentSeat,
                    onTap: seat.available
                        ? () => widget.onSeatSelected(seat.seatNumber)
                        : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatRow {
  const _SeatRow({
    required this.cabinName,
    required this.rowNumber,
    required this.seats,
  });

  final String cabinName;
  final int rowNumber;
  final List<CabinSeat> seats;
}

class _SeatChip extends StatelessWidget {
  const _SeatChip({
    required this.seat,
    required this.currency,
    required this.isCurrent,
    required this.onTap,
  });

  final CabinSeat seat;
  final String currency;
  final bool isCurrent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = isCurrent
        ? scheme.primary
        : seat.available
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest;
    final foreground = isCurrent
        ? scheme.onPrimary
        : seat.available
            ? scheme.onPrimaryContainer
            : scheme.outline;

    return Tooltip(
      message: seat.available
          ? [
              seat.seatNumber,
              if (seat.type != null) seat.type!,
              if (seat.isExitRow) 'exit row',
              if (seat.price > 0) formatMoney(seat.price, currency),
            ].join(' · ')
          : '${seat.seatNumber} · taken',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: seat.isExitRow
                    ? scheme.tertiary.withOpacity(0.6)
                    : Colors.transparent,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  seat.column.isEmpty ? seat.seatNumber : seat.column,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                        decoration: seat.available
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                ),
                if (seat.available && seat.price > 0)
                  Text(
                    formatMoney(seat.price, currency),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: foreground,
                          fontSize: 9,
                        ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.currency});

  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: scheme.outline);

    Widget swatch(Color color) => Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        );

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          swatch(scheme.primaryContainer),
          const SizedBox(width: 4),
          Text('Available', style: style),
        ]),
        Row(mainAxisSize: MainAxisSize.min, children: [
          swatch(scheme.surfaceContainerHighest),
          const SizedBox(width: 4),
          Text('Taken', style: style),
        ]),
        Row(mainAxisSize: MainAxisSize.min, children: [
          swatch(scheme.primary),
          const SizedBox(width: 4),
          Text('Yours', style: style),
        ]),
      ],
    );
  }
}
