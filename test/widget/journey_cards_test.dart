import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/basket.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/boarding_pass.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking_confirmation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/cabin_seat_map.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/cancellation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/extras_catalogue.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat_confirmation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/upgrade_quote.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/wallet_split.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/confirm_action_bar.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/flight/flight_selection_sheet.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/flight/basket_card.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/flight/boarding_pass_card.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/flight/booking_confirmed_card.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/flight/cancellation_card.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/flight/extras_list_card.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/flight/upgrade_quote_card.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/seat_map/cabin_seat_map_card.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/seat_map/seat_confirmed_card.dart';

/// Renders each journey card on its own. These cards are plain widgets —
/// the ones with controls take a callback rather than reaching for the view
/// model — so they can be pumped without the provider overrides the rest of
/// the widget tests need.
void main() {
  Future<void> pump(WidgetTester tester, Widget card) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: card)),
      ),
    );
  }

  final flight = FlightOffer(
    id: 'AA50',
    airline: 'AA',
    flightNumber: 'AA50',
    origin: 'DFW',
    destination: 'LHR',
    departureTime: DateTime(2027, 6, 10, 17, 55),
    arrivalTime: DateTime(2027, 6, 11, 7, 40),
    price: 255,
    durationLabel: '8h45',
    aircraft: 'B777-300ER',
    arrivesNextDay: true,
  );

  const wallet = WalletSplit(
    voucher: WalletVoucher(code: 'AA-150', available: 150, applied: 150),
    card: WalletCardPayment(brand: 'Visa', last4: '4242', amount: 105),
  );

  testWidgets('basket card shows the breakdown down to the total', (tester) async {
    await pump(
      tester,
      BasketCard(
        basket: Basket(
          basketId: 42,
          flight: flight,
          cabin: 'Main Cabin Extra',
          pax: 1,
          baseFare: 205,
          taxes: 30,
          extras: const [
            BasketExtra(name: 'Wi-Fi', price: 19),
            BasketExtra(name: 'Lounge access', included: true),
          ],
          extrasTotal: 19,
          discounts: const [BasketDiscount(label: 'Executive Platinum', amount: 20)],
          total: 255,
          wallet: wallet,
        ),
      ),
    );

    expect(find.text('Your basket'), findsOneWidget);
    expect(find.text('AA50 · DFW → LHR'), findsOneWidget);
    expect(find.text('Wi-Fi'), findsOneWidget);
    expect(find.text('Included'), findsOneWidget);
    expect(find.text('−\$20'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    // Once in the header, once on the Total row.
    expect(find.text('\$255'), findsNWidgets(2));
    expect(find.text('Voucher AA-150'), findsOneWidget);
  });

  testWidgets('a flight with no duration from the backend shows none',
      (tester) async {
    // DFW 17:55 → LHR 09:05 next day is a 9h05 flight, but the times are
    // each local to their own airport. Subtracting them gives 15h10m — the
    // timezone offset, not the flight — so nothing is shown at all.
    await pump(
      tester,
      BasketCard(
        basket: Basket(
          basketId: 1,
          total: 1038,
          flight: FlightOffer(
            id: 'AA50',
            airline: 'AA',
            flightNumber: 'AA50',
            origin: 'DFW',
            destination: 'LHR',
            departureTime: DateTime(2027, 6, 10, 17, 55),
            arrivalTime: DateTime(2027, 6, 11, 9, 5),
            price: 1038,
            arrivesNextDay: true,
          ),
        ),
      ),
    );

    expect(find.textContaining('15h'), findsNothing);
    expect(find.text('17:55 – 09:05 +1'), findsOneWidget);
  });

  testWidgets('extras list card reports which extra was added', (tester) async {
    String? added;
    await pump(
      tester,
      ExtrasListCard(
        catalogue: const ExtrasCatalogue(
          cabin: 'Main Cabin Extra',
          extras: [
            BasketExtra(name: 'Wi-Fi', price: 19),
            BasketExtra(name: 'Checked bag', included: true),
          ],
        ),
        onAdd: (name) => added = name,
      ),
    );

    expect(find.text('Extras for Main Cabin Extra'), findsOneWidget);
    // The included extra offers no Add button — there is nothing to buy.
    expect(find.text('Add'), findsOneWidget);

    await tester.tap(find.text('Add'));
    expect(added, 'Wi-Fi');
  });

  testWidgets('booking confirmed card leads with the PNR', (tester) async {
    await pump(
      tester,
      BookingConfirmedCard(
        booking: BookingConfirmation(
          pnr: 'V7DG2V',
          status: 'Confirmed',
          passengerName: 'Elena Vargas',
          flight: flight,
          cabin: 'Main Cabin Extra',
          seat: '12A',
          total: 255,
          wallet: wallet,
        ),
      ),
    );

    expect(find.text('Booking confirmed'), findsOneWidget);
    expect(find.text('V7DG2V'), findsOneWidget);
    expect(find.textContaining('Seat 12A'), findsOneWidget);
    expect(find.text('Total paid'), findsOneWidget);
    expect(find.text('Visa •••• 4242'), findsOneWidget);
  });

  testWidgets('seat map card only lets an available seat be tapped',
      (tester) async {
    final tapped = <String>[];
    await pump(
      tester,
      CabinSeatMapCard(
        seatMap: const CabinSeatMap(
          flightNumber: 'AA50',
          currentSeat: '14C',
          cabins: [
            SeatCabin(
              name: 'Main Cabin Extra',
              seats: [
                CabinSeat(seatNumber: '12A', row: 12, column: 'A', price: 45),
                CabinSeat(
                  seatNumber: '12B',
                  row: 12,
                  column: 'B',
                  available: false,
                ),
              ],
            ),
          ],
        ),
        onSeatSelected: tapped.add,
      ),
    );

    expect(find.text('Choose a seat · AA50'), findsOneWidget);
    expect(find.text('Main Cabin Extra'), findsOneWidget);

    await tester.tap(find.text('B'));
    expect(tapped, isEmpty, reason: 'an occupied seat is not selectable');

    await tester.tap(find.text('A'));
    expect(tapped, ['12A']);
  });

  testWidgets('seat confirmed card shows what the seat replaced',
      (tester) async {
    await pump(
      tester,
      const SeatConfirmedCard(
        confirmation: SeatConfirmation(
          seatNumber: '12A',
          previousSeatNumber: '14C',
          cabin: 'Main Cabin Extra',
          price: 45,
        ),
      ),
    );

    expect(find.text('12A'), findsOneWidget);
    expect(find.text('14C'), findsOneWidget);
    expect(find.text('Seat charge'), findsOneWidget);
  });

  testWidgets('boarding pass shows seat, gate, group and boarding time',
      (tester) async {
    await pump(
      tester,
      const BoardingPassCard(
        pass: BoardingPass(
          pnr: 'V7DG2V',
          passengerName: 'Elena Vargas',
          flightNumber: 'AA50',
          origin: 'DFW',
          destination: 'LHR',
          date: '2027-06-10',
          departureTime: '17:55',
          boardingTime: '17:15',
          gate: 'D24',
          seat: '12A',
          boardingGroup: '2',
          cabin: 'Main Cabin Extra',
        ),
      ),
    );

    expect(find.text('Boarding pass'), findsOneWidget);
    expect(find.text('DFW'), findsOneWidget);
    expect(find.text('LHR'), findsOneWidget);
    expect(find.text('D24'), findsOneWidget);
    expect(find.text('12A'), findsOneWidget);
    expect(find.text('17:15'), findsOneWidget);
    expect(find.text('V7DG2V'), findsOneWidget);
  });

  testWidgets('upgrade quote prices both ways and calls out affordability',
      (tester) async {
    await pump(
      tester,
      const UpgradeQuoteCard(
        quote: UpgradeQuote(
          fromCabin: 'Main Cabin Extra',
          toCabin: 'Flagship Business',
          cash: 1450,
          miles: 60000,
          milesBalance: 240000,
          seatsAvailable: 3,
        ),
      ),
    );

    expect(find.text('Main Cabin Extra → Flagship Business'), findsOneWidget);
    expect(find.text('\$1,450'), findsOneWidget);
    expect(find.text('60,000'), findsOneWidget);
    expect(find.text('Covered by your miles'), findsOneWidget);
    expect(find.textContaining('3 seats left'), findsOneWidget);
  });

  testWidgets('cancellation reads as a preview until it is confirmed',
      (tester) async {
    const preview = Cancellation(
      pnr: 'V7DG2V',
      refundTotal: 235,
      penalty: 20,
      refund: wallet,
    );

    await pump(tester, const CancellationCard(cancellation: preview));
    expect(find.text('Cancellation preview'), findsOneWidget);
    expect(find.text('You would get back'), findsOneWidget);
    expect(find.text('Would be refunded to'), findsOneWidget);

    await pump(
      tester,
      const CancellationCard(
        cancellation: Cancellation(
          pnr: 'V7DG2V',
          isConfirmed: true,
          refundTotal: 235,
          refund: wallet,
        ),
      ),
    );
    expect(find.text('Booking cancelled'), findsOneWidget);
    expect(find.text('Refunded'), findsOneWidget);
  });

  _selectionSheetTests();

  testWidgets('confirm bar approves or drops the pending action',
      (tester) async {
    var confirmed = false;
    var declined = false;

    await pump(
      tester,
      ConfirmActionBar(
        prompt: 'That is \$255 for 1 in Main Cabin Extra. Shall I go ahead?',
        onConfirm: () => confirmed = true,
        onDecline: () => declined = true,
      ),
    );

    expect(find.textContaining('Shall I go ahead?'), findsOneWidget);

    await tester.tap(find.text('Confirm'));
    expect(confirmed, isTrue);

    await tester.tap(find.text('Not now'));
    expect(declined, isTrue);
  });
}

/// The Select flow's sheet: cabin and party size in one place. Booking for
/// more than one passenger is otherwise impossible from the UI — every card
/// reads `pax`, but nothing sent it until this sheet existed.
///
/// Pumped directly rather than through [FlightOffersCard]: tapping "Select"
/// there now reads `chatViewModelProvider` to stop any spoken reply, which
/// would drag Hive and SharedPreferences into a test about fare arithmetic.
void _selectionSheetTests() {
  Future<void> pumpSheet(WidgetTester tester, FlightOffer offer) {
    return tester.pumpWidget(
      MaterialApp(home: Scaffold(body: FlightSelectionSheet(offer: offer))),
    );
  }

  final priced = FlightOffer(
    id: 'AA50',
    airline: 'AA',
    flightNumber: 'AA50',
    origin: 'DFW',
    destination: 'LHR',
    departureTime: DateTime(2027, 6, 10, 17, 55),
    arrivalTime: DateTime(2027, 6, 11, 9, 5),
    price: 769,
    durationLabel: '9h05',
    cabinPrices: const {'Main Cabin': 769, 'Main Cabin Extra': 1038},
  );

  testWidgets('selection sheet prices the whole party as it grows',
      (tester) async {
    await pumpSheet(tester, priced);

    expect(find.text('AA50 · DFW → LHR'), findsOneWidget);
    expect(find.text('Passenger'), findsOneWidget);
    // Cheapest cabin first, priced for one.
    expect(find.text('Main Cabin'), findsOneWidget);
    expect(find.text('\$769'), findsOneWidget);
    expect(find.text('\$1,038'), findsOneWidget);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add_circle_outline));
    await tester.pumpAndSettle();

    expect(find.text('Passengers'), findsOneWidget);
    // Each row now totals the party, with the per-person price beneath.
    expect(find.text('\$1,538'), findsOneWidget);
    expect(find.text('\$2,076'), findsOneWidget);
    expect(find.text('\$769 each'), findsOneWidget);
  });

  testWidgets('choosing a cabin returns it with the party size',
      (tester) async {
    FlightSelectionChoice? choice;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                choice = await showModalBottomSheet<FlightSelectionChoice>(
                  context: context,
                  builder: (_) => FlightSelectionSheet(offer: priced),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithIcon(IconButton, Icons.add_circle_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Main Cabin Extra'));
    await tester.pumpAndSettle();

    expect(choice, isNotNull);
    expect(choice!.cabin, 'Main Cabin Extra');
    expect(choice!.pax, 2);
  });

  testWidgets('the party cannot drop below one passenger', (tester) async {
    await pumpSheet(
      tester,
      FlightOffer(
        id: 'AA50',
        airline: 'AA',
        flightNumber: 'AA50',
        origin: 'DFW',
        destination: 'LHR',
        departureTime: DateTime(2027, 6, 10, 17, 55),
        arrivalTime: DateTime(2027, 6, 11, 9, 5),
        price: 769,
      ),
    );

    // byTooltip resolves to the Tooltip that IconButton builds, so reach
    // the button itself through its icon.
    final decrement = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.remove_circle_outline),
    );
    expect(decrement.onPressed, isNull);

    // A flight with no cabin_prices still offers its headline fare.
    expect(find.text('Selected fare'), findsOneWidget);
  });
}
