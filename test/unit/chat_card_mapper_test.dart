import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/basket_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/chat_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/flight_list_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/basket.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/boarding_pass.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking_confirmation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/cabin_seat_map.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/cancellation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/extras_catalogue.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_selection.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat_confirmation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/upgrade_quote.dart';

/// Covers the `cards` array of every turn in the backend's "02 - Journey"
/// run: search → select → extras → book → confirm → seat → check-in →
/// upgrade → cancel.
///
/// The card payloads here follow the shapes in the Mobile Integration Guide
/// (`flight_list` is quoted verbatim there) and the conventions the live
/// `flight_list` / `flight_selected` responses established — snake_case
/// inside flight objects, camelCase on card fields. Where the guide only
/// names a card's contents rather than showing it, the fixture encodes what
/// the client assumes; if a turn ever renders as bare text against the real
/// API, the mismatch will be between one of these fixtures and the wire.
void main() {
  group('ChatCardMapper', () {
    test('1. search — flight_list becomes flight offers', () {
      final cards = ChatCardMapper.fromResponse([
        {
          'type': 'flight_list',
          'origin': 'DFW',
          'dest': 'LHR',
          'date': '2027-06-10',
          'flights': [
            {
              'flight_no': 'AA856',
              'dep': '07:00',
              'arr': '16:05',
              'duration': '9h05',
              'aircraft': 'B777-300ER',
              'price': 913,
              'seats_left': 7,
              'cabin_prices': {
                'Main Cabin': 913,
                'Flagship Business': 3835,
              },
              'recommended': 0,
              'lowest': 1,
            },
            // The API pads truncated arrays with a note; it must not break
            // the rest of the card.
            '... 6 more flights',
          ],
        },
      ]);

      expect(cards, hasLength(1));
      expect(cards.single.type, ChatMessageType.flightOffersCard);

      final offers = cards.single.payload as List<FlightOffer>;
      expect(offers, hasLength(1));
      expect(offers.single.flightNumber, 'AA856');
      expect(offers.single.origin, 'DFW');
      expect(offers.single.destination, 'LHR');
      expect(offers.single.price, 913);
      expect(offers.single.lowest, isTrue);
      expect(offers.single.recommended, isFalse);
      expect(offers.single.cabinPrices['Flagship Business'], 3835);
      expect(offers.single.departureTime, DateTime.parse('2027-06-10T07:00:00'));
    });

    test('2. select — flight_selected becomes a held basket', () {
      final cards = ChatCardMapper.fromResponse([
        {
          'type': 'flight_selected',
          'basketId': 42,
          'cabin': 'Main Cabin Extra',
          'pax': 1,
          'total': 255,
          'currency': 'USD',
          'fare': {'base': 205, 'perPassenger': 205},
          'flight': {
            'flight_no': 'AA50',
            'flight_date': '2027-06-10',
            'origin': 'DFW',
            'dest': 'LHR',
            'dep': '17:55',
            'arr': '07:40',
            'arrives_next_day': true,
            'price': 255,
          },
          'wallet': {
            'voucher': {'code': 'AA-150', 'available': 150, 'applied': 150},
            'card': {'brand': 'Visa', 'last4': '4242', 'amount': 105},
          },
        },
      ]);

      expect(cards.single.type, ChatMessageType.flightSelectedCard);

      final selection = cards.single.payload as FlightSelection;
      expect(selection.basketId, 42);
      expect(selection.cabin, 'Main Cabin Extra');
      expect(selection.total, 255);
      expect(selection.flight.flightNumber, 'AA50');
      expect(selection.flight.arrivesNextDay, isTrue);
      expect(selection.wallet?.voucher?.applied, 150);
      expect(selection.wallet?.card?.last4, '4242');
    });

    test('3. extras — basket totals the extras and discounts', () {
      final cards = ChatCardMapper.fromResponse([
        {
          'type': 'basket',
          'basketId': 42,
          'cabin': 'Main Cabin Extra',
          'pax': 2,
          'fare': {'base': 410, 'perPassenger': 205, 'taxes': 60},
          'extras': [
            {'code': 'wifi', 'name': 'Wi-Fi', 'price': 19, 'qty': 1},
            {'code': 'bag1', 'name': 'Checked bag', 'price': 35, 'qty': 1},
            {'code': 'lounge', 'name': 'Lounge access', 'included': true},
          ],
          'extrasTotal': 54,
          'discounts': [
            {'label': 'Executive Platinum', 'amount': 20},
          ],
          'total': 504,
          'currency': 'USD',
        },
      ]);

      expect(cards.single.type, ChatMessageType.basketCard);

      final basket = cards.single.payload as Basket;
      expect(basket.pax, 2);
      expect(basket.baseFare, 410);
      expect(basket.taxes, 60);
      expect(basket.extras, hasLength(3));
      expect(basket.extras.where((e) => e.included), hasLength(1));
      expect(basket.extrasTotal, 54);
      expect(basket.discountTotal, 20);
      expect(basket.total, 504);
    });

    test('extras_list marks what the cabin already includes', () {
      final cards = ChatCardMapper.fromResponse([
        {
          'type': 'extras_list',
          'cabin': 'Flagship Business',
          'extras': [
            {'code': 'wifi', 'name': 'Wi-Fi', 'price': 19},
            {'code': 'bag1', 'name': 'Checked bag', 'included': true},
          ],
        },
      ]);

      expect(cards.single.type, ChatMessageType.extrasListCard);

      final catalogue = cards.single.payload as ExtrasCatalogue;
      expect(catalogue.cabin, 'Flagship Business');
      expect(catalogue.extras.first.price, 19);
      expect(catalogue.extras.last.included, isTrue);
    });

    test('4. book — the basket preview arrives with needsConfirmation', () {
      // The confirmation itself is turn-level state, not part of the card;
      // the basket maps the same either way.
      final cards = ChatCardMapper.fromResponse(
        [
          {
            'type': 'basket',
            'basketId': 42,
            'total': 255,
            'cabin': 'Main Cabin Extra',
          },
        ],
        needsConfirmation: true,
      );

      expect(cards.single.type, ChatMessageType.basketCard);
      expect((cards.single.payload as Basket).total, 255);
    });

    test('5. confirm — booking_confirmed carries the PNR and payment split', () {
      final cards = ChatCardMapper.fromResponse([
        {
          'type': 'booking_confirmed',
          'pnr': 'V7DG2V',
          'status': 'Confirmed',
          'passenger': 'Elena Vargas',
          'cabin': 'Main Cabin Extra',
          'pax': 1,
          'total': 255,
          'currency': 'USD',
          'flight': {
            'flight_no': 'AA50',
            'flight_date': '2027-06-10',
            'origin': 'DFW',
            'dest': 'LHR',
            'dep': '17:55',
            'arr': '07:40',
            'price': 255,
          },
          'wallet': {
            'voucher': {'code': 'AA-150', 'available': 150, 'applied': 150},
            'miles': {'balance': 240000, 'applied': 0, 'milesUsed': 0},
            'card': {'brand': 'Visa', 'last4': '4242', 'amount': 105},
          },
        },
      ]);

      expect(cards.single.type, ChatMessageType.bookingConfirmedCard);

      final booking = cards.single.payload as BookingConfirmation;
      expect(booking.pnr, 'V7DG2V');
      expect(booking.isDetail, isFalse);
      expect(booking.passengerName, 'Elena Vargas');
      expect(booking.flight?.flightNumber, 'AA50');
      expect(booking.wallet?.total, 255);
    });

    test('booking_detail renders through the same card, flagged as a detail', () {
      final cards = ChatCardMapper.fromResponse([
        {'type': 'booking_detail', 'pnr': 'V7DG2V'},
      ]);

      expect(cards.single.type, ChatMessageType.bookingConfirmedCard);
      expect((cards.single.payload as BookingConfirmation).isDetail, isTrue);
    });

    test('6. seat — seat_map groups by cabin and row', () {
      final cards = ChatCardMapper.fromResponse([
        {
          'type': 'seat_map',
          'flight_no': 'AA50',
          'currency': 'USD',
          'currentSeat': '14C',
          'cabins': [
            {
              'name': 'Main Cabin Extra',
              'seats': [
                {'seat': '12A', 'available': true, 'price': 45, 'type': 'window'},
                {'seat': '12B', 'available': false},
                {'seat': '14C', 'available': true, 'price': 0},
              ],
            },
          ],
        },
      ]);

      expect(cards.single.type, ChatMessageType.cabinSeatMapCard);

      final seatMap = cards.single.payload as CabinSeatMap;
      expect(seatMap.flightNumber, 'AA50');
      expect(seatMap.currentSeat, '14C');
      expect(seatMap.cabins, hasLength(1));
      expect(seatMap.cabins.single.seats, hasLength(3));

      final seat12a = seatMap.cabins.single.seats.first;
      // Row and column are derived from `12A` when not sent separately.
      expect(seat12a.row, 12);
      expect(seat12a.column, 'A');
      expect(seat12a.price, 45);
      expect(seatMap.cabins.single.seats[1].available, isFalse);
      expect(seatMap.cabins.single.seatsByRow.keys, containsAll([12, 14]));
    });

    test('seat_map also reads a flat rows → seats shape', () {
      final cards = ChatCardMapper.fromResponse([
        {
          'type': 'seat_map',
          'cabin': 'Main Cabin',
          'rows': [
            {
              'row': 20,
              'seats': [
                {'seatNumber': '20A', 'availability': 'available'},
                {'seatNumber': '20B', 'availability': 'occupied'},
              ],
            },
          ],
        },
      ]);

      final seatMap = cards.single.payload as CabinSeatMap;
      expect(seatMap.cabins.single.name, 'Main Cabin');
      expect(seatMap.cabins.single.seats.first.row, 20);
      expect(seatMap.cabins.single.seats.first.available, isTrue);
      expect(seatMap.cabins.single.seats.last.available, isFalse);
    });

    test('seat_confirmed reports the move', () {
      final cards = ChatCardMapper.fromResponse([
        {
          'type': 'seat_confirmed',
          'seat': '12A',
          'previous': '14C',
          'cabin': 'Main Cabin Extra',
          'flight_no': 'AA50',
          'price': 45,
        },
      ]);

      expect(cards.single.type, ChatMessageType.seatConfirmedCard);

      final confirmation = cards.single.payload as SeatConfirmation;
      expect(confirmation.seatNumber, '12A');
      expect(confirmation.previousSeatNumber, '14C');
      expect(confirmation.price, 45);
    });

    test('7. check in — boarding_pass keeps the backend times verbatim', () {
      final cards = ChatCardMapper.fromResponse([
        {
          'type': 'boarding_pass',
          'pnr': 'V7DG2V',
          'passenger': 'Elena Vargas',
          'flight_no': 'AA50',
          'origin': 'DFW',
          'dest': 'LHR',
          'date': '2027-06-10',
          'dep': '17:55',
          'boardingTime': '17:15',
          'gate': 'D24',
          'terminal': 'D',
          'seat': '12A',
          'group': '2',
          'cabin': 'Main Cabin Extra',
          'barcode': 'M1VARGAS/ELENA',
        },
      ]);

      expect(cards.single.type, ChatMessageType.boardingPassCard);

      final pass = cards.single.payload as BoardingPass;
      expect(pass.pnr, 'V7DG2V');
      expect(pass.gate, 'D24');
      expect(pass.boardingGroup, '2');
      expect(pass.boardingTime, '17:15');
      expect(pass.seat, '12A');
      expect(pass.barcode, 'M1VARGAS/ELENA');
    });

    test('8. upgrade — upgrade_quote prices cash and miles', () {
      final cards = ChatCardMapper.fromResponse(
        [
          {
            'type': 'upgrade_quote',
            'from': 'Main Cabin Extra',
            'to': 'Flagship Business',
            'cash': 1450,
            'miles': 60000,
            'milesBalance': 240000,
            'currency': 'USD',
            'seatsAvailable': 3,
          },
        ],
        needsConfirmation: true,
      );

      expect(cards.single.type, ChatMessageType.upgradeQuoteCard);

      final quote = cards.single.payload as UpgradeQuote;
      expect(quote.fromCabin, 'Main Cabin Extra');
      expect(quote.toCabin, 'Flagship Business');
      expect(quote.cash, 1450);
      expect(quote.miles, 60000);
      expect(quote.canAffordWithMiles, isTrue);
    });

    test('upgrade_quote reads a nested miles block, and its own verdict wins', () {
      final cards = ChatCardMapper.fromResponse([
        {
          'type': 'upgrade_quote',
          'to': 'Flagship Business',
          'miles': {'required': 60000, 'balance': 10000},
          'affordable': false,
        },
      ]);

      final quote = cards.single.payload as UpgradeQuote;
      expect(quote.miles, 60000);
      expect(quote.milesBalance, 10000);
      expect(quote.canAffordWithMiles, isFalse);
    });

    test('10/11. cancel — the preview and the receipt differ by the turn flag',
        () {
      const card = {
        'type': 'cancellation',
        'pnr': 'V7DG2V',
        'refundTotal': 235,
        'penalty': 20,
        'currency': 'USD',
        'refund': {
          'voucher': {'code': 'AA-150', 'applied': 150},
          'card': {'brand': 'Visa', 'last4': '4242', 'amount': 85},
        },
      };

      final preview = ChatCardMapper.fromResponse(
        [card],
        needsConfirmation: true,
      ).single.payload as Cancellation;
      expect(preview.isConfirmed, isFalse);
      expect(preview.effectiveRefundTotal, 235);
      expect(preview.penalty, 20);

      final receipt =
          ChatCardMapper.fromResponse([card]).single.payload as Cancellation;
      expect(receipt.isConfirmed, isTrue);
      expect(receipt.refund?.card?.amount, 85);
    });

    test('a turn carrying several cards renders all of them, in order', () {
      final cards = ChatCardMapper.fromResponse([
        {'type': 'seat_confirmed', 'seat': '12A'},
        {'type': 'basket', 'basketId': 1, 'total': 300},
      ]);

      expect(
        cards.map((c) => c.type),
        [ChatMessageType.seatConfirmedCard, ChatMessageType.basketCard],
      );
    });

    test('card types with no widget yet are skipped, not guessed at', () {
      // Every card comes with a `reply` sentence that stands on its own, so
      // the turn still reads correctly as text.
      final cards = ChatCardMapper.fromResponse([
        {'type': 'spend_summary', 'total': 12000},
        {'type': 'text'},
        {'type': 'seat_confirmed', 'seat': '12A'},
      ]);

      expect(cards, hasLength(1));
      expect(cards.single.type, ChatMessageType.seatConfirmedCard);
    });

    test('a card missing the field that identifies it is dropped, not faked',
        () {
      final cards = ChatCardMapper.fromResponse([
        {'type': 'booking_confirmed'}, // no PNR
        {'type': 'basket', 'basketId': 1}, // no total
        {'type': 'upgrade_quote', 'cash': 100}, // no target cabin
      ]);

      expect(cards, isEmpty);
    });

    test('a non-list cards field is tolerated', () {
      expect(ChatCardMapper.fromResponse(null), isEmpty);
      expect(ChatCardMapper.fromResponse('cards'), isEmpty);
    });
  });

  /// Payloads below are copied verbatim from the live read-only endpoints
  /// (`GET /flights/search`, `GET /extras`, `GET /bookings/current`) on
  /// 2026-08-07, so these pin real field spellings rather than assumed ones.
  group('live payload shapes', () {
    test('GET /flights/search flight rows map cleanly', () {
      final offers = FlightListCardMapper.fromCard({
        'origin': 'DFW',
        'dest': 'LHR',
        'date': '2027-06-10',
        'flights': [
          {
            'flight_no': 'AA856',
            'origin': 'DFW',
            'dest': 'LHR',
            'dep': '07:00',
            'arr': '16:05',
            'duration': '9h05',
            'duration_min': 545,
            'aircraft': 'B777-300ER',
            'price': 913,
            'seats_left': 7,
            'flight_date': '2027-06-10',
            'cabin_prices': {
              'Main Cabin': 913,
              'Main Cabin Extra': 1233,
              'Flagship First': 5569,
            },
            'recommended': 0,
            'lowest': 0,
            'status': 'scheduled',
            'arrives_next_day': 0,
          },
        ],
      });

      expect(offers.single.flightNumber, 'AA856');
      expect(offers.single.aircraft, 'B777-300ER');
      expect(offers.single.seatsLeft, 7);
      expect(offers.single.durationLabel, '9h05');
      // 0/1 integers, not booleans.
      expect(offers.single.recommended, isFalse);
      expect(offers.single.arrivesNextDay, isFalse);
      expect(offers.single.cabinPrices, hasLength(3));
    });

    test('GET /extras rows use `descr`, and `includedIn` decides inclusion', () {
      const catalogue = [
        {
          'code': 'lounge',
          'name': 'Admirals Club day pass',
          'descr': 'Departure and connecting airports',
          'category': 'airport',
          'per': 'passenger',
          'price': 79,
          'listPrice': 79,
          'was': 99,
          'included': false,
          'includedIn': ['Flagship Business', 'Flagship First'],
        },
        {
          'code': 'fasttrack',
          'name': 'Airport fast track',
          'descr': 'Expedited security where available',
          'price': 25,
          'included': false,
          'includedIn': <String>[],
        },
      ];

      // In a cabin that covers it, the lounge pass is not something to sell.
      final business = BasketCardMapper.extrasFrom(
        catalogue,
        cabin: 'Flagship Business',
      );
      expect(business.first.included, isTrue);
      expect(business.last.included, isFalse);

      final main = BasketCardMapper.extrasFrom(catalogue, cabin: 'Main Cabin');
      expect(main.first.included, isFalse);
      expect(main.first.price, 79);
      expect(
        main.first.description,
        'Departure and connecting airports',
        reason: '`descr` is the catalogue spelling, not `description`',
      );
    });

    test('the real basket card prices its items and keeps the discount', () {
      // Captured from POST /chat "Add wifi and a bag" on 2026-08-07. The
      // arithmetic only closes if all three parts map: fare 1038 + extras 62
      // − waiver 40 = 1060.
      final cards = ChatCardMapper.fromResponse([
        {
          'type': 'basket',
          'basketId': 7,
          'flight': {
            'flight_no': 'AA50',
            'origin': 'DFW',
            'dest': 'LHR',
            'dep': '17:55',
            'arr': '09:05',
            'duration': '9h05',
            'aircraft': 'B777-300ER',
            'price': 769,
            'seats_left': 18,
            'flight_date': '2027-06-10',
            'recommended': 1,
            'lowest': 0,
            'arrives_next_day': 1,
          },
          'cabin': 'Main Cabin Extra',
          'pax': 1,
          'fare': {'perPassenger': 1038, 'base': 1038},
          // Basket lines price themselves as `unit`/`total`, not `price`.
          'items': [
            {
              'code': 'bag1',
              'name': 'First checked bag',
              'unit': 40,
              'qty': 1,
              'total': 40,
              'included': false,
            },
            {
              'code': 'wifi',
              'name': 'Full-flight Wi-Fi',
              'unit': 22,
              'qty': 1,
              'total': 22,
              'included': false,
            },
          ],
          'extrasTotal': 62,
          // The label lives on `reason` here.
          'discounts': [
            {'reason': 'Executive Platinum bag waiver', 'amount': 40},
          ],
          'total': 1060,
          'currency': 'USD',
          'wallet': {
            'voucher': null,
            'miles': {
              'balance': 433062,
              'rate': 100,
              'valueUSD': 4330,
              'applied': 1060,
              'milesUsed': 106000,
            },
            'card': {'brand': 'Citi', 'last4': '9004', 'amount': 0},
          },
          'awaitingConfirmation': true,
        },
      ]);

      final basket = cards.single.payload as Basket;
      expect(basket.baseFare, 1038);
      expect(basket.extras.map((e) => e.price), [40, 22]);
      expect(basket.extrasTotal, 62);
      expect(basket.discounts.single.label, 'Executive Platinum bag waiver');
      expect(basket.discountTotal, 40);
      expect(basket.total, 1060);
      expect(
        basket.baseFare! + basket.extrasTotal - basket.discountTotal,
        basket.total,
        reason: 'the card must add up to the total the backend quoted',
      );

      // A null voucher and a zero card charge are both normal here.
      expect(basket.wallet?.voucher, isNull);
      expect(basket.wallet?.miles?.milesUsed, 106000);
      expect(basket.wallet?.card?.amount, 0);
      expect(basket.flight?.arrivesNextDay, isTrue);
    });

    test('a flat booking payload maps without a nested flight object', () {
      final cards = ChatCardMapper.fromResponse([
        {
          'type': 'booking_detail',
          'id': 56,
          'pnr': 'GMB7PN',
          'flight_no': 'AA289',
          'origin': 'DFW',
          'dest': 'LHR',
          'flight_date': '2026-08-12',
          'dep_time': '16:21',
          'arr_time': '01:26',
          'cabin': 'Flagship Business',
          'seat': '14F',
          'fare_usd': 2834,
          'status': 'confirmed',
          'checked_in': 0,
          'items': <Object>[],
          'payment': null,
        },
      ]);

      final booking = cards.single.payload as BookingConfirmation;
      expect(booking.pnr, 'GMB7PN');
      expect(booking.seat, '14F');
      expect(booking.total, 2834);
      expect(booking.flight?.flightNumber, 'AA289');
      expect(booking.flight?.origin, 'DFW');

      // dep 16:21 → arr 01:26 is an overnight leg. The payload does not say
      // so; without inferring it the arrival lands before the departure.
      expect(booking.flight!.arrivalTime.isAfter(booking.flight!.departureTime),
          isTrue);
      expect(booking.flight!.duration, const Duration(hours: 9, minutes: 5));
    });
  });
}
