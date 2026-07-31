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

  testWidgets('a seat named by voice shows on the map before it is confirmed', (tester) async {
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
          seatNumber: '14C',
          row: 14,
          column: 'C',
          type: SeatType.aisle,
          availability: SeatAvailability.available,
        ),
      ],
    );

    Widget card({String? highlighted}) => ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SeatMapCard(seatMap: seatMap, highlightedSeatNumber: highlighted),
            ),
          ),
        );

    await tester.pumpWidget(card());
    expect(find.text('Select a seat'), findsOneWidget);

    // Saying "14A" arms the seat for confirmation — the card has to show that
    // choice landing, or the passenger sees nothing happen at all.
    await tester.pumpWidget(card(highlighted: '14A'));
    await tester.pump();
    expect(find.textContaining('Confirm 14A'), findsOneWidget);

    // Tapping a different seat afterwards is a correction and must win.
    await tester.tap(find.text('C'));
    await tester.pump();
    expect(find.textContaining('Confirm 14C'), findsOneWidget);
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
