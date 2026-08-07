import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/basket_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/card_json.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/flight_list_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/wallet_split_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking_confirmation.dart';

/// Maps the `booking_confirmed` and `booking_detail` cards, which share a
/// shape — see [BookingConfirmation].
class BookingConfirmedCardMapper {
  const BookingConfirmedCardMapper._();

  static const bookingConfirmedCardType = 'booking_confirmed';
  static const bookingDetailCardType = 'booking_detail';

  static BookingConfirmation? fromCard(
    Map<String, dynamic> card, {
    bool isDetail = false,
  }) {
    final pnr = CardJson.asString(
      CardJson.pick(card, ['pnr', 'recordLocator', 'bookingRef']),
    );
    // The PNR is the whole point of this card — without one there is nothing
    // for the passenger to quote at the airport.
    if (pnr == null) return null;

    // A confirmed booking nests its money under `payment`; a basket-shaped
    // card puts the same numbers at the top level.
    final payment = CardJson.asMap(CardJson.pick(card, ['payment', 'paid'])) ??
        const <String, dynamic>{};

    return BookingConfirmation(
      pnr: pnr,
      isDetail: isDetail,
      status: CardJson.asString(CardJson.pick(card, ['status'])),
      passengerName: CardJson.asString(
        CardJson.pick(card, ['passenger', 'passengerName', 'name']),
      ),
      flight: FlightListCardMapper.nestedFlightFrom(card),
      // An upgrade receipt comes back as a `booking_detail` describing the
      // move rather than the booking, so `to` is the cabin now held.
      cabin: CardJson.asString(CardJson.pick(card, ['cabin', 'to'])) ?? '',
      pax: CardJson.asInt(CardJson.pick(card, ['pax', 'passengers'])) ?? 1,
      seat: CardJson.asString(CardJson.pick(card, ['seat', 'seatNumber'])),
      // `items` is what a stored booking calls its extras.
      extras: BasketCardMapper.extrasFrom(
        CardJson.pick(card, ['extras', 'items']),
        cabin: CardJson.asString(CardJson.pick(card, ['cabin'])) ?? '',
      ),
      total: CardJson.asNum(
            CardJson.pick(payment, ['total', 'amount']),
          ) ??
          CardJson.asNum(
            CardJson.pick(card, [
              'total',
              'totalPaid',
              'amountPaid',
              'grandTotal',
              'fare_usd',
            ]),
          ),
      milesEarned: CardJson.asNum(
        CardJson.pick(card, ['milesEarned', 'earnedMiles']),
      ),
      currency: CardJson.asString(
            CardJson.pick(payment, ['currency']),
          ) ??
          CardJson.asString(CardJson.pick(card, ['currency'])) ??
          'USD',
      wallet: WalletSplitMapper.fromCard(card),
    );
  }
}
