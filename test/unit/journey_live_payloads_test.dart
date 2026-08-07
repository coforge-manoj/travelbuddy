import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/chat_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/basket.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/boarding_pass.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking_confirmation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/cabin_seat_map.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/cancellation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat_confirmation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/upgrade_quote.dart';

/// Every payload here was captured verbatim from `POST /api/v1/chat` while
/// running the backend's "02 - Journey" folder end to end on 2026-08-07.
///
/// They exist because the guessed shapes were wrong in ways no amount of
/// re-reading the integration guide would have caught: the same three
/// payment methods are spelled `wallet` on a basket, `payment` on a
/// booking, `paid` on an upgrade and `refund` on a cancellation, with the
/// amounts sometimes objects and sometimes bare numbers. Treat these as the
/// contract until a newer capture replaces them.
void main() {
  _followUpTests();

  group('live journey payloads', () {
    test('5. booking_confirmed — camelCase flight, payment block, miles earned',
        () {
      final cards = ChatCardMapper.fromResponse([
        {
          'type': 'booking_confirmed',
          'ok': true,
          'pnr': 'FCLD3Q',
          'bookingId': 167,
          // `flightNo` and `date`, not `flight_no` and `flight_date`.
          'flight': {
            'flightNo': 'AA50',
            'origin': 'DFW',
            'dest': 'LHR',
            'date': '2027-06-10',
            'dep': '17:55',
            'arr': '09:05',
          },
          'cabin': 'Main Cabin Extra',
          'pax': 1,
          // Bare numbers for voucher and card; miles as {used, value}.
          'payment': {
            'total': 1038,
            'voucher': 0,
            'miles': {'used': 0, 'value': 0},
            'card': 1038,
            'currency': 'USD',
          },
          'milesEarned': 11418,
          'items': <Object>[],
        },
      ]);

      expect(cards.single.type, ChatMessageType.bookingConfirmedCard);
      final booking = cards.single.payload as BookingConfirmation;

      expect(booking.pnr, 'FCLD3Q');
      expect(booking.total, 1038, reason: 'the total is nested in `payment`');
      expect(booking.milesEarned, 11418);
      expect(booking.flight?.flightNumber, 'AA50');
      expect(booking.flight?.origin, 'DFW');
      // dep 17:55 → arr 09:05 is overnight and the payload does not say so.
      expect(booking.flight!.arrivalTime.isAfter(booking.flight!.departureTime),
          isTrue);
      // A bare number still has to read as a card charge.
      expect(booking.wallet?.card?.amount, 1038);
    });

    test('a party of three prices per passenger throughout', () {
      // Captured from POST /basket/select {pax: 3} then POST /basket/extras
      // on 2026-08-07. `GET /basket` returns this same shape, so the basket
      // card mapper covers the direct endpoint as well as the chat card.
      final cards = ChatCardMapper.fromResponse([
        {
          'type': 'basket',
          'basketId': 20,
          'flight': {
            'flight_no': 'AA50',
            'origin': 'DFW',
            'dest': 'LHR',
            'dep': '17:55',
            'arr': '09:05',
            'duration': '9h05',
            'flight_date': '2027-06-10',
            'price': 769,
            'arrives_next_day': 1,
          },
          'cabin': 'Main Cabin Extra',
          'pax': 3,
          'fare': {'perPassenger': 1038, 'base': 3114},
          // Extras are charged per passenger — `qty` follows the party.
          'items': [
            {
              'code': 'bag1',
              'name': 'First checked bag',
              'unit': 40,
              'qty': 3,
              'total': 120,
              'included': false,
            },
            {
              'code': 'wifi',
              'name': 'Full-flight Wi-Fi',
              'unit': 22,
              'qty': 3,
              'total': 66,
              'included': false,
            },
          ],
          'extrasTotal': 186,
          'discounts': [
            {'reason': 'Executive Platinum bag waiver', 'amount': 120},
          ],
          'total': 3180,
          'currency': 'USD',
        },
      ]);

      final basket = cards.single.payload as Basket;
      expect(basket.pax, 3);
      expect(basket.perPassenger, 1038);
      expect(basket.baseFare, 3114);
      expect(basket.extras.first.quantity, 3);
      // The card multiplies unit × qty for the line, so the unit price is
      // what must be stored — 40, not the 120 line total.
      expect(basket.extras.first.price, 40);
      expect(basket.extrasTotal, 186);
      expect(basket.discountTotal, 120);
      expect(
        basket.baseFare! + basket.extrasTotal - basket.discountTotal,
        basket.total,
      );
    });

    test('6. seat_confirmed — attributes become the seat label', () {
      final cards = ChatCardMapper.fromResponse([
        {
          'type': 'seat_confirmed',
          'ok': true,
          'pnr': 'FCLD3Q',
          'flightNo': 'AA50',
          'date': '2027-06-10',
          'seat': '12A',
          'previousSeat': null,
          'cabin': 'Premium Economy',
          'attributes': {
            'window': true,
            'aisle': false,
            'extraLegroom': false,
          },
          'price': 0,
        },
      ]);

      final seat = cards.single.payload as SeatConfirmation;
      expect(seat.seatNumber, '12A');
      expect(seat.previousSeatNumber, isNull);
      expect(seat.flightNumber, 'AA50');
      expect(seat.type, 'window');
    });

    test('6. seat_map — cabins hold rows, seats flag themselves', () {
      final cards = ChatCardMapper.fromResponse([
        {
          'type': 'seat_map',
          'bookingId': 167,
          'pnr': 'FCLD3Q',
          'currentSeat': '12A',
          'flightNo': 'AA50',
          'date': '2027-06-10',
          'aircraft': 'B777-300ER',
          'origin': 'DFW',
          'dest': 'LHR',
          'cabins': [
            {
              'cabin': 'Main Cabin Extra',
              'pitch': '34in',
              'rows': [
                {
                  'row': 14,
                  'seats': [
                    {
                      'seat': '14A',
                      'available': true,
                      'window': true,
                      'aisle': false,
                      'extraLegroom': true,
                      'exitRow': false,
                      'price': 0,
                    },
                    {
                      'seat': '14C',
                      'available': false,
                      'window': false,
                      'aisle': true,
                      'extraLegroom': true,
                      'exitRow': false,
                      'price': 0,
                    },
                  ],
                },
              ],
            },
          ],
        },
      ]);

      expect(cards.single.type, ChatMessageType.cabinSeatMapCard);
      final map = cards.single.payload as CabinSeatMap;

      expect(map.flightNumber, 'AA50');
      expect(map.currentSeat, '12A');
      // `cabin`, not `name`.
      expect(map.cabins.single.name, 'Main Cabin Extra');
      expect(map.cabins.single.seats, hasLength(2));

      final first = map.cabins.single.seats.first;
      expect(first.seatNumber, '14A');
      expect(first.row, 14);
      expect(first.column, 'A');
      expect(first.available, isTrue);
      expect(first.type, 'window · extra legroom');
      expect(map.cabins.single.seats.last.available, isFalse);
    });

    test('7. boarding_pass — issued pass names the flight, not the route', () {
      final cards = ChatCardMapper.fromResponse([
        {
          'type': 'boarding_pass',
          'pnr': 'FCLD3Q',
          'flightNo': 'AA50',
          'date': '2027-06-10',
          'seat': '12A',
          'cabin': 'Main Cabin Extra',
          'gate': '25',
          'terminal': 'B',
          'boardingTime': '17:15',
          'boardingGroup': 'Group 2',
          'sequence': 4,
          'barcode': 'M1FCLD3Q504717',
          'issuedAt': '2026-08-07T05:53:43.388Z',
        },
      ]);

      final pass = cards.single.payload as BoardingPass;
      expect(pass.pnr, 'FCLD3Q');
      expect(pass.flightNumber, 'AA50');
      expect(pass.seat, '12A');
      expect(pass.gate, '25');
      expect(pass.terminal, 'B');
      expect(pass.boardingGroup, 'Group 2');
      expect(pass.boardingTime, '17:15');
      expect(pass.sequenceNumber, '4');
      expect(pass.barcode, 'M1FCLD3Q504717');
      // The card carries no route — the pass must cope rather than blank out.
      expect(pass.origin, isEmpty);
      expect(pass.destination, isEmpty);
    });

    test('8. upgrade_quote — `difference` is the cash price, miles nest', () {
      final cards = ChatCardMapper.fromResponse([
        {
          'type': 'upgrade_quote',
          'ok': true,
          'quote': true,
          'pnr': 'FCLD3Q',
          'from': 'Main Cabin Extra',
          'to': 'Flagship Business',
          'currentFare': 1038,
          'newFare': 3230,
          'difference': 2192,
          'payWithMiles': {
            'miles': 219200,
            'affordable': true,
            'balance': 456140,
          },
          'note': 'Confirm to apply. Nothing has changed yet.',
        },
      ]);

      final quote = cards.single.payload as UpgradeQuote;
      expect(quote.fromCabin, 'Main Cabin Extra');
      expect(quote.toCabin, 'Flagship Business');
      expect(
        quote.cash,
        2192,
        reason: 'the price is the fare gap, not `newFare`',
      );
      expect(quote.miles, 219200);
      expect(quote.milesBalance, 456140);
      expect(quote.canAffordWithMiles, isTrue);
    });

    test('9. upgrade applied — booking_detail names the cabin now held', () {
      final cards = ChatCardMapper.fromResponse([
        {
          'type': 'booking_detail',
          'ok': true,
          'pnr': 'FCLD3Q',
          'from': 'Main Cabin Extra',
          'to': 'Flagship Business',
          'paid': {'card': 2192},
          'note': 'Seat cleared — choose a new one in the upgraded cabin.',
        },
      ]);

      expect(cards.single.type, ChatMessageType.bookingConfirmedCard);
      final booking = cards.single.payload as BookingConfirmation;
      expect(booking.isDetail, isTrue);
      expect(booking.cabin, 'Flagship Business');
      expect(booking.wallet?.card?.amount, 2192);
    });

    test('10. cancel preview — needsConfirmation with no card to render', () {
      // The preview turn is reply-only; the confirmation bar carries it.
      final cards = ChatCardMapper.fromResponse(
        const <Object>[],
        needsConfirmation: true,
      );
      expect(cards, isEmpty);
    });

    test('11. cancellation — refund names its methods differently again', () {
      final cards = ChatCardMapper.fromResponse([
        {
          'type': 'cancellation',
          'ok': true,
          'pnr': 'FCLD3Q',
          'refund': {
            'card': 1038,
            'milesRestored': 0,
            'voucherReissued': null,
            'status': 'processing',
            'note': 'Card refunds settle in 5-7 business days.',
          },
        },
      ]);

      final cancellation = cards.single.payload as Cancellation;
      expect(cancellation.pnr, 'FCLD3Q');
      expect(cancellation.isConfirmed, isTrue);
      expect(cancellation.status, 'processing');
      expect(cancellation.refund?.card?.amount, 1038);
      // No explicit total — it has to come from summing the split.
      expect(cancellation.effectiveRefundTotal, 1038);
      expect(cancellation.reason, 'Card refunds settle in 5-7 business days.');
    });
  });
}

/// Which turns earn follow-up chips. The backend attaches its stock
/// suggestions to every turn regardless of outcome, so the client decides.
void _followUpTests() {
  group('follow-up suggestions', () {
    test('a clarification turn shows none, even though the backend sent some',
        () {
      // Verbatim from POST /chat "search for flight to london" on
      // 2026-08-07 — no flights found, yet it offers to book one.
      final followUps = ChatCardMapper.followUpsFrom({
        'reply': 'I need an origin, a destination and a date.',
        'tool': 'search_flights',
        'cards': <Object>[],
        'suggestions': ['Book the recommended one', 'Show me cheaper options'],
        'needsConfirmation': false,
      });

      expect(followUps, isEmpty);
    });

    test('a turn with results keeps its chips', () {
      final followUps = ChatCardMapper.followUpsFrom({
        'cards': [
          {'type': 'flight_list', 'flights': <Object>[]},
        ],
        'suggestions': ['Book the recommended one', 'Show me cheaper options'],
      });

      expect(followUps, hasLength(2));
    });

    test('a confirmation turn keeps its chips even with no card', () {
      // "cancel my booking" comes back reply-only, awaiting a yes.
      final followUps = ChatCardMapper.followUpsFrom({
        'cards': <Object>[],
        'needsConfirmation': true,
        'suggestions': ['Yes, cancel it'],
      });

      expect(followUps, ['Yes, cancel it']);
    });

    test('a card type this client cannot draw still counts as a result', () {
      final followUps = ChatCardMapper.followUpsFrom({
        'cards': [
          {'type': 'spend_summary', 'total': 12000},
        ],
        'suggestions': ['Break it down by cabin'],
      });

      expect(followUps, ['Break it down by cabin']);
    });

    test('a missing or malformed suggestions field is tolerated', () {
      expect(
        ChatCardMapper.followUpsFrom({
          'cards': [
            {'type': 'basket'},
          ],
        }),
        isEmpty,
      );
      expect(
        ChatCardMapper.followUpsFrom({
          'cards': [
            {'type': 'basket'},
          ],
          'suggestions': 'nope',
        }),
        isEmpty,
      );
    });
  });
}
