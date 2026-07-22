import 'package:flutter/material.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat.dart';

/// A single tappable seat in the [SeatMapCard] grid.
class SeatTile extends StatelessWidget {
  const SeatTile({
    super.key,
    required this.seat,
    required this.isSelected,
    required this.onTap,
  });

  final Seat seat;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final occupied = seat.availability == SeatAvailability.occupied;

    Color background;
    Color foreground;
    if (isSelected) {
      background = scheme.primary;
      foreground = scheme.onPrimary;
    } else if (occupied) {
      background = scheme.surfaceContainerHighest;
      foreground = scheme.outline;
    } else if (seat.type == SeatType.window) {
      background = scheme.tertiaryContainer;
      foreground = scheme.onTertiaryContainer;
    } else {
      background = scheme.surfaceContainerHigh;
      foreground = scheme.onSurface;
    }

    final tooltipMessage = occupied
        ? 'Seat ${seat.seatNumber} — occupied'
        : seat.priceDelta > 0
            ? 'Seat ${seat.seatNumber} — +${seat.priceDelta.toStringAsFixed(0)}'
            : 'Seat ${seat.seatNumber}';

    return Tooltip(
      message: tooltipMessage,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: occupied ? null : onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 34,
            height: 34,
            child: Center(
              child: Text(
                seat.column,
                style: TextStyle(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
