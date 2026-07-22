import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/seat_map/seat_map_card.dart';

void main() {
  testWidgets('tapping an available seat highlights it and enables confirm', (tester) async {
    const seatMap = SeatMap(
      flightNumber: 'FZ123',
      rows: 1,
      seats: [
        Seat(
          seatNumber: '14A',
          row: 14,
          column: 'A',
          type: SeatType.window,
          availability: SeatAvailability.available,
          priceDelta: 15,
        ),
        Seat(
          seatNumber: '14B',
          row: 14,
          column: 'B',
          type: SeatType.middle,
          availability: SeatAvailability.occupied,
        ),
      ],
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: SeatMapCard(seatMap: seatMap))),
      ),
    );

    // No seat selected yet — the confirm button is disabled and unlabeled.
    expect(find.text('Select a seat'), findsOneWidget);

    await tester.tap(find.text('A'));
    await tester.pump();

    expect(find.textContaining('Confirm 14A'), findsOneWidget);
  });

  testWidgets('occupied seats are not tappable', (tester) async {
    const seatMap = SeatMap(
      flightNumber: 'FZ123',
      rows: 1,
      seats: [
        Seat(
          seatNumber: '14B',
          row: 14,
          column: 'B',
          type: SeatType.middle,
          availability: SeatAvailability.occupied,
        ),
      ],
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: SeatMapCard(seatMap: seatMap))),
      ),
    );

    await tester.tap(find.text('B'));
    await tester.pump();

    // Tapping an occupied seat should never select it.
    expect(find.text('Select a seat'), findsOneWidget);
  });
}
