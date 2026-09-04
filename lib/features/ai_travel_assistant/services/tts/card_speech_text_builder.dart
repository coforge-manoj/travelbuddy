import 'package:ai_travel_assistant/core/utils/app_date.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/airport_info.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/basket.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/boarding_pass.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking_confirmation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/cabin_seat_map.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/cancellation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/document_check.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/extras_catalogue.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_selection.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/member_wallet.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat_confirmation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/travel_history.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/upgrade_quote.dart';

/// A line ready to be spoken, and whether it was composed from card data.
class SpokenLine {
  /// Built from a card's payload: every fare, code, seat and count in [text]
  /// was read out of the entity and formatted here.
  const SpokenLine.fromCard(this.text) : isFactual = true;

  /// Free prose — the assistant's own words, as the backend wrote them.
  const SpokenLine.prose(this.text) : isFactual = false;

  final String text;

  /// Whether [text] carries facts this code is responsible for.
  ///
  /// The speech summarizer is an LLM, and it may not be trusted to reword a
  /// PNR, a gate or a fare — a single transposed character is a wrong answer
  /// delivered confidently. Factual lines are already written for the ear, so
  /// callers skip the summarizer for them entirely and speak them as built.
  /// This is the "facts in code, phrasing by the model" rule expressed as
  /// control flow rather than as a prompt instruction.
  final bool isFactual;
}

/// Describes a rich card in words, so it can be spoken instead of sitting
/// silently on screen.
///
/// A card's `text` is only a caption ("Here are a few options") — the useful
/// content lives in its payload. This walks the payload and produces a plain
/// sentence or two.
///
/// Two rules run through every case below:
///
/// - **Never compute a duration from departure and arrival times.** They are
///   each local to their own airport, so DFW→LHR reads as 15h10 instead of
///   9h05. Only a `durationLabel` the backend sent is ever spoken.
/// - **Speak only non-null fields.** Most of the journey payloads are largely
///   optional, and "gate null" is worse than saying nothing about the gate.
///
/// Pure and Riverpod-free by design, so the whole table is unit-testable.
class CardSpeechTextBuilder {
  const CardSpeechTextBuilder();

  /// Returns `null` when a message has nothing worth speaking (user turns,
  /// errors, or a card whose payload isn't the shape we expect).
  SpokenLine? build(ChatMessage message) {
    if (message.role != ChatRole.assistant) return null;

    final caption = message.text.trim();
    final payload = message.payload;

    switch (message.type) {
      case ChatMessageType.text:
        return caption.isEmpty ? null : SpokenLine.prose(caption);

      case ChatMessageType.flightOffersCard:
        return _card(caption, _flightOffers(payload));

      case ChatMessageType.flightStatusCard:
        return _card(caption, _flightStatus(payload));

      case ChatMessageType.seatMapCard:
        return _card(caption, _seatMap(payload));

      case ChatMessageType.baggageOptionsCard:
        return _card(caption, _baggageOptions(payload));

      case ChatMessageType.baggageSuccessCard:
        return _card(caption, _baggagePurchase(payload));

      case ChatMessageType.bookingConfirmationCard:
        return _card(caption, _booking(payload));

      case ChatMessageType.airportInfoCard:
        return _card(caption, _airportInfo(payload));

      // The live journey cards.
      case ChatMessageType.flightSelectedCard:
        return _card(caption, _flightSelected(payload));

      case ChatMessageType.basketCard:
        return _card(caption, _basket(payload));

      case ChatMessageType.extrasListCard:
        return _card(caption, _extrasCatalogue(payload));

      case ChatMessageType.bookingConfirmedCard:
        return _card(caption, _bookingConfirmation(payload));

      case ChatMessageType.cabinSeatMapCard:
        return _card(caption, _cabinSeatMap(payload));

      case ChatMessageType.seatConfirmedCard:
        return _card(caption, _seatConfirmation(payload));

      case ChatMessageType.boardingPassCard:
        return _card(caption, _boardingPass(payload));

      case ChatMessageType.upgradeQuoteCard:
        return _card(caption, _upgradeQuote(payload));

      case ChatMessageType.cancellationCard:
        return _card(caption, _cancellation(payload));

      case ChatMessageType.travelHistoryCard:
        return _card(caption, _travelHistory(payload));

      case ChatMessageType.memberWalletCard:
        return _card(caption, _memberWallet(payload));

      case ChatMessageType.documentCheckCard:
        return _card(caption, _documentCheck(payload));

      case ChatMessageType.agentEscalationCard:
      case ChatMessageType.actionSummaryCard:
        return caption.isEmpty ? null : SpokenLine.prose(caption);

      case ChatMessageType.error:
        return null;
    }
  }

  /// The caption sets up the card, the detail delivers it. Either alone is
  /// still worth speaking.
  /// A card speaks its detail, not its caption.
  ///
  /// The caption is the backend's own one-line summary, and a live turn hands
  /// the same one to every card — so joining them read the answer out twice:
  /// "105 flights. Most recent was AA993…" followed immediately by "105 flights
  /// all time… flight A A 993…". The two say the same thing in different words,
  /// so no amount of string de-duplication removes it.
  ///
  /// The detail is the better of the two aloud in any case: it is built from the
  /// payload with codes spelled for the ear, where the caption would have an
  /// engine read "AA993 DFW→LHR" as a word and an arrow.
  ///
  /// The caption is still the fallback when a payload yields nothing to say.
  SpokenLine? _card(String caption, String? detail) {
    if (detail != null && detail.isNotEmpty) return SpokenLine.fromCard(detail);
    return caption.isEmpty ? null : SpokenLine.prose(caption);
  }

  String? _flightOffers(Object? payload) {
    if (payload is! List<FlightOffer> || payload.isEmpty) return null;

    // Prefer the offer the backend flagged, falling back to computing it, so
    // screen and voice never disagree about which one is cheapest.
    final cheapest = payload.firstWhere(
      (o) => o.lowest,
      orElse: () => payload.reduce((a, b) => b.price < a.price ? b : a),
    );
    final count = payload.length;
    final route = '${_place(cheapest.origin)} to ${_place(cheapest.destination)}';

    final detail = StringBuffer(
      '${_countWord(count)} ${count == 1 ? 'option' : 'options'} from $route. ',
    )..write(
        'The lowest fare is ${cheapest.airline} '
        '${_flightNumber(cheapest.flightNumber)} at '
        '${_money(cheapest.price, cheapest.currency)}, departing '
        '${_time(cheapest.departureTime)}, ${_stops(cheapest.stops)}',
      );
    // Spoken only when the backend supplied it. Deriving it from departure and
    // arrival would be wrong on any route that crosses a timezone, since each
    // time is local to its own airport.
    if (cheapest.durationLabel != null) {
      detail.write(', ${cheapest.durationLabel}');
    }
    // Worth saying aloud precisely because the ear cannot infer it from the
    // arrival time the way an eye can from a date on screen.
    if (cheapest.arrivesNextDay) {
      detail.write(', arriving the next day');
    }
    detail.write('.');

    final recommended = payload.where((o) => o.recommended).toList();
    if (recommended.isNotEmpty && recommended.first.id != cheapest.id) {
      final pick = recommended.first;
      detail.write(
        ' The recommended one is ${pick.airline} '
        '${_flightNumber(pick.flightNumber)} at '
        '${_money(pick.price, pick.currency)}.',
      );
    }
    return detail.toString();
  }

  String? _flightStatus(Object? payload) {
    if (payload is! Flight) return null;

    final parts = <String>[
      '${_flightNumber(payload.flightNumber)} to '
          '${_place(payload.destination)} is ${_status(payload.status)}',
    ];

    final estimated = payload.estimatedDeparture;
    parts.add(
      estimated != null && estimated != payload.scheduledDeparture
          ? 'now departing ${_time(estimated)} instead of '
              '${_time(payload.scheduledDeparture)}'
          : 'departing ${_time(payload.scheduledDeparture)}',
    );

    if (payload.gate != null) parts.add('from gate ${_spellOut(payload.gate!)}');
    if (payload.terminal != null) parts.add('terminal ${_spellOut(payload.terminal!)}');

    return '${parts.join(', ')}.';
  }

  String? _seatMap(Object? payload) {
    if (payload is! SeatMap) return null;

    final available =
        payload.seats.where((s) => s.availability == SeatAvailability.available);
    if (available.isEmpty) return 'No seats are available on this flight.';

    final windows =
        available.where((s) => s.type == SeatType.window).map((s) => s.seatNumber);
    final detail = StringBuffer('${available.length} seats are open');
    if (windows.isNotEmpty) {
      detail.write(
        ', including window ${_spellOut(windows.first)}',
      );
    }
    return '$detail.';
  }

  String? _baggageOptions(Object? payload) {
    if (payload is! List<BaggageOption> || payload.isEmpty) return null;

    final cheapest = payload.reduce((a, b) => b.price < a.price ? b : a);
    return '${payload.length} add-ons, starting at '
        '${_money(cheapest.price, cheapest.currency)} for '
        '${_weight(cheapest.extraWeightKg)} extra.';
  }

  String? _baggagePurchase(Object? payload) {
    if (payload is! BaggagePurchase) return null;

    final option = payload.option;
    final confirmation = payload.confirmationCode;
    final detail = StringBuffer(
      '${_weight(option.extraWeightKg)} added for '
      '${_money(option.price, option.currency)}',
    );
    if (confirmation != null && confirmation.isNotEmpty) {
      detail.write(', confirmation ${_spellOut(confirmation)}');
    }
    return '$detail.';
  }

  String? _booking(Object? payload) {
    if (payload is! Booking) return null;

    final flight = payload.flight;
    return 'Booking confirmed. ${_flightNumber(flight.flightNumber)}, '
        '${_place(flight.origin)} to ${_place(flight.destination)}, '
        'departing ${_time(flight.scheduledDeparture)}. '
        'Your reference is ${_spellLetters(payload.pnr)}.';
  }

  String? _airportInfo(Object? payload) {
    if (payload is! AirportInfo) return null;

    return 'Terminal ${_spellOut(payload.terminal)}, '
        'check-in ${_spellOut(payload.checkInCounter)}, '
        'gate ${_spellOut(payload.gate)}. '
        'About ${payload.walkingTimeMinutes} minutes on foot.';
  }

  // -------------------------------------------------------------------
  // The live journey cards.
  // -------------------------------------------------------------------

  String? _flightSelected(Object? payload) {
    if (payload is! FlightSelection) return null;
    final f = payload.flight;

    final parts = <String>[
      '${f.airline} ${_flightNumber(f.flightNumber)}',
      'in ${payload.cabin}',
      'for ${_countWord(payload.pax)} '
          '${payload.pax == 1 ? 'passenger' : 'passengers'}',
    ];
    final line = StringBuffer('${parts.join(', ')}. ')
      ..write('Total ${_money(payload.total, payload.currency)}');
    // Only worth breaking out when there is more than one fare in the total.
    if (payload.pax > 1 && payload.perPassenger != null) {
      line.write(
        ', ${_money(payload.perPassenger!, payload.currency)} each',
      );
    }
    return '$line.';
  }

  String? _basket(Object? payload) {
    if (payload is! Basket) return null;

    final line = StringBuffer();
    if (payload.baseFare != null) {
      line.write('Fare ${_money(payload.baseFare!, payload.currency)}');
      if (payload.taxes != null) {
        line.write(', taxes ${_money(payload.taxes!, payload.currency)}');
      }
      line.write('. ');
    }

    // Included extras are already in the fare; naming them as additions would
    // imply the passenger is paying twice.
    final paid = payload.extras.where((e) => !e.included).toList();
    if (paid.isNotEmpty) {
      final named = paid.take(3).map((e) {
        final name = e.quantity > 1 ? '${_countWord(e.quantity)} ${e.name}' : e.name;
        return '$name at ${_money(e.price, payload.currency)}';
      }).join(', ');
      line.write('Extras: $named');
      final remaining = paid.length - 3;
      if (remaining > 0) {
        line.write(', and ${_countWord(remaining)} more');
      }
      line.write('. ');
    }

    for (final discount in payload.discounts) {
      line.write(
        '${discount.label}, minus '
        '${_money(discount.amount.abs(), payload.currency)}. ',
      );
    }

    line.write('Total ${_money(payload.total, payload.currency)}.');
    return line.toString();
  }

  String? _extrasCatalogue(Object? payload) {
    if (payload is! ExtrasCatalogue || payload.extras.isEmpty) return null;

    final prices = payload.extras.map((e) => e.price).toList()..sort();
    final names = payload.extras.take(3).map((e) => e.name).join(', ');

    final line = StringBuffer(
      '${_countWord(payload.extras.length)} '
      '${payload.extras.length == 1 ? 'extra' : 'extras'} for ${payload.cabin}',
    );
    if (prices.first != prices.last) {
      line.write(
        ', from ${_money(prices.first, payload.currency)} '
        'to ${_money(prices.last, payload.currency)}',
      );
    } else {
      line.write(', at ${_money(prices.first, payload.currency)}');
    }
    return '$line. $names.';
  }

  String? _bookingConfirmation(Object? payload) {
    if (payload is! BookingConfirmation) return null;

    final line = StringBuffer(
      payload.isDetail
          ? 'Booking ${_spellLetters(payload.pnr)}. '
          : 'Booked. Your reference is ${_spellLetters(payload.pnr)}. ',
    );

    final flight = payload.flight;
    if (flight != null) {
      line.write(
        '${flight.airline} ${_flightNumber(flight.flightNumber)}, '
        '${_place(flight.origin)} to ${_place(flight.destination)}, ',
      );
    }
    line.write('${payload.cabin}');
    if (payload.seat != null) line.write(', seat ${_spellOut(payload.seat!)}');
    if (payload.total != null) {
      line.write(', ${_money(payload.total!, payload.currency)}');
    }
    line.write('.');
    if (payload.milesEarned != null && payload.milesEarned! > 0) {
      line.write(' You earned ${payload.milesEarned!.round()} miles.');
    }
    return line.toString();
  }

  String? _cabinSeatMap(Object? payload) {
    if (payload is! CabinSeatMap || payload.isEmpty) return null;

    // A seat map has hundreds of seats. Reading them out is useless; what a
    // passenger choosing by voice needs is how many are free and one or two
    // they could actually ask for.
    final line = StringBuffer();
    for (final cabin in payload.cabins) {
      final free = cabin.seats.where((s) => s.available).length;
      if (free == 0) continue;
      line.write('${_countWord(free)} free in ${cabin.name}. ');
    }
    if (line.isEmpty) return null;

    final windows = payload.cabins
        .expand((c) => c.seats)
        .where((s) => s.available && (s.type ?? '').toLowerCase() == 'window')
        .toList()
      ..sort((a, b) => a.price.compareTo(b.price));

    if (windows.isNotEmpty) {
      final cheapest = windows.take(2).map((s) {
        final price = s.price == 0
            ? 'no extra charge'
            : _money(s.price, payload.currency);
        return '${_spellOut(s.seatNumber)} at $price';
      }).join(', ');
      line.write('Window seats: $cheapest. ');
    }
    if (payload.currentSeat != null) {
      line.write("You're in ${_spellOut(payload.currentSeat!)} at the moment.");
    }
    return line.toString().trim();
  }

  String? _seatConfirmation(Object? payload) {
    if (payload is! SeatConfirmation) return null;

    final line = StringBuffer('Seat ${_spellOut(payload.seatNumber)} is yours');
    if (payload.previousSeatNumber != null) {
      line.write(', moved from ${_spellOut(payload.previousSeatNumber!)}');
    }
    line.write('.');
    if (payload.type != null) line.write(' ${payload.type} seat.');
    line.write(
      payload.price == 0
          ? ' At no extra charge.'
          : ' ${_money(payload.price, payload.currency)}.',
    );
    return line.toString();
  }

  String? _boardingPass(Object? payload) {
    if (payload is! BoardingPass) return null;

    // Almost every field here is optional — the live capture has no passenger
    // name and no route at all — so this is built by collecting the parts that
    // are actually present rather than by writing a sentence and patching holes
    // in it. The times arrive as strings already formatted by the backend, and
    // are spoken as-is: parsing them to reformat would risk the same
    // local-timezone error that makes computed durations wrong.
    final opening = <String>[
      if (payload.passengerName.trim().isNotEmpty) payload.passengerName.trim(),
      _flightNumber(payload.flightNumber),
      if (payload.origin.trim().isNotEmpty &&
          payload.destination.trim().isNotEmpty)
        '${_place(payload.origin)} to ${_place(payload.destination)}',
    ];

    final line = StringBuffer(opening.join(', '));
    if (payload.date != null) {
      line.write(' on ${AppDate.formatSpokenRaw(payload.date)}');
    }
    line.write('.');

    if (payload.seat != null) line.write(' Seat ${_spellOut(payload.seat!)}.');

    final position = <String>[
      if (payload.terminal != null) 'terminal ${_spellOut(payload.terminal!)}',
      if (payload.gate != null) 'gate ${_spellOut(payload.gate!)}',
    ];
    if (position.isNotEmpty) {
      final joined = position.join(', ');
      line.write(' ${joined[0].toUpperCase()}${joined.substring(1)}.');
    }

    if (payload.boardingGroup != null) {
      // A boarding group is a phrase ("Group 2"), not a code — spelling it out
      // would produce "G r o u p 2".
      line.write(' Boarding ${payload.boardingGroup!.toLowerCase()}.');
    }
    if (payload.boardingTime != null) {
      line.write(' Boarding at ${payload.boardingTime}.');
    }
    return line.toString();
  }

  String? _upgradeQuote(Object? payload) {
    if (payload is! UpgradeQuote) return null;

    final line = StringBuffer(
      '${payload.fromCabin} to ${payload.toCabin} on '
      '${_flightNumber(payload.flightNumber)}. ',
    );

    final prices = <String>[
      if (payload.cash != null) _money(payload.cash!, payload.currency),
      if (payload.miles != null) '${payload.miles!.round()} miles',
    ];
    if (prices.isNotEmpty) line.write('${prices.join(' or ')}. ');

    // The shortfall is computed here rather than left to the model, and only
    // when the backend actually said the passenger can't afford it.
    if (payload.affordable == false &&
        payload.milesBalance != null &&
        payload.miles != null) {
      final short = payload.miles! - payload.milesBalance!;
      if (short > 0) {
        line.write("You're ${short.round()} miles short. ");
      }
    }
    if (payload.seatsAvailable != null && payload.seatsAvailable! > 0) {
      line.write(
        '${_countWord(payload.seatsAvailable!)} '
        '${payload.seatsAvailable == 1 ? 'seat' : 'seats'} left. ',
      );
    }
    // Same ask checkout and cancel use: the quote is a preview, and the
    // confirmation bar is invisible from audio mode.
    return '${line.toString().trim()} Shall I go ahead?';
  }

  String? _cancellation(Object? payload) {
    if (payload is! Cancellation) return null;

    final refund = payload.refundTotal != null
        ? _money(payload.refundTotal!, payload.currency)
        : null;

    if (!payload.isConfirmed) {
      final line = StringBuffer(
        'Cancelling ${_spellLetters(payload.pnr)}',
      );
      if (refund != null) line.write(' refunds $refund');
      if (payload.penalty != null && payload.penalty! > 0) {
        line.write(', after a ${_money(payload.penalty!, payload.currency)} fee');
      }
      return '$line. Shall I go ahead?';
    }

    final line = StringBuffer('Cancelled ${_spellLetters(payload.pnr)}.');
    if (refund != null) line.write(' $refund is on its way back.');
    final miles = payload.refund?.miles;
    if (miles != null && miles.milesUsed > 0) {
      line.write(' ${miles.milesUsed.round()} miles restored.');
    }
    return line.toString();
  }

  String? _travelHistory(Object? payload) {
    if (payload is! TravelHistory) return null;

    final line = StringBuffer(
      '${_countWord(payload.count)} '
      '${payload.count == 1 ? 'flight' : 'flights'} ${payload.scope}',
    );
    if (payload.totalSpend != null) {
      line.write(', ${_money(payload.totalSpend!, payload.currency)} in total');
    }
    line.write('. ');

    if (payload.flights.isNotEmpty) {
      final recent = payload.flights.take(2).map((f) {
        final parts = StringBuffer(
          '${_flightNumber(f.flightNumber)} on '
          '${AppDate.formatSpokenRaw(f.date)}, ${_route(f.route)}',
        );
        if (f.cabin.isNotEmpty) parts.write(' in ${f.cabin}');
        return parts.toString();
      }).join('. ');
      line.write('Most recently $recent.');
    }
    return line.toString().trim();
  }

  /// The wallet is a balance, so it leads with miles — the number the
  /// question was actually about. Loyalty points are deliberately skipped:
  /// two large numbers in one breath are indistinguishable by ear, and the
  /// spendable one is the one that answers "can we do this on miles?".
  ///
  /// The card's last four digits are spelled out; read as a number, "4417"
  /// becomes "four thousand four hundred and seventeen".
  String? _memberWallet(Object? payload) {
    if (payload is! MemberWallet) return null;

    final parts = <String>[];
    if (payload.miles != null) {
      // Matches how every other card speaks a miles figure — a plain rounded
      // number, not `_money`, since miles are not currency.
      parts.add('${payload.miles!.round()} miles');
    }
    final voucher = payload.voucher;
    if (voucher?.amount != null) {
      parts.add('a ${_money(voucher!.amount!, 'USD')} voucher');
    }
    final card = payload.card;
    if (card?.last4 != null) {
      final brand = card!.brand == null ? 'card' : '${card.brand} card';
      // [_spellLetters], not [_spellOut]: the latter keeps digit runs
      // grouped, so "4417" would be read "four thousand four hundred and
      // seventeen". Card digits are matched against a physical card, so they
      // are read one at a time — the same reason PNRs are.
      parts.add('and your $brand ending ${_spellLetters(card.last4!)}');
    }
    if (parts.isEmpty) return null;

    final line = StringBuffer('You have ${parts.join(', ')}.');
    if (payload.tier != null) {
      line.write(" You're ${payload.tier}.");
    }
    return line.toString();
  }

  /// Documents are the one card where the spoken version has to carry the
  /// remedy, not just the problem. Heard without "what to do about it", a
  /// passport warning is pure alarm — and unlike the screen, the listener
  /// cannot scan back for the fix.
  ///
  /// Only the first two issues are spoken. The seeded party has two, and a
  /// longer list read aloud stops being actionable.
  String? _documentCheck(Object? payload) {
    if (payload is! DocumentCheck) return null;

    if (payload.issues.isEmpty) {
      if (payload.clear.isEmpty) return null;
      final where =
          payload.destination == null ? '' : ' for ${payload.destination}';
      return 'Everyone\'s documents are in order$where.';
    }

    final line = StringBuffer(
      '${_countWord(payload.issues.length)} '
      '${payload.issues.length == 1 ? 'passenger needs' : 'passengers need'} '
      'attention. ',
    );
    for (final issue in payload.issues.take(2)) {
      line.write('${issue.passenger}: ');
      if (issue.detail != null) line.write('${_stripDates(issue.detail!)} ');
      if (issue.action != null) line.write('${issue.action} ');
    }
    return line.toString().trim();
  }

  /// Renders ISO dates inside a sentence as something sayable: "2027-04-09"
  /// read raw comes out as "two thousand and twenty seven dash zero four".
  String _stripDates(String text) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return text.replaceAllMapped(RegExp(r'(\d{4})-(\d{2})-(\d{2})'), (m) {
      final month = int.parse(m.group(2)!);
      final day = int.parse(m.group(3)!);
      if (month < 1 || month > 12) return m.group(0)!;
      return '${months[month - 1]} $day, ${m.group(1)}';
    });
  }

  // -------------------------------------------------------------------
  // Spoken formatting: the same facts, shaped for the ear rather than the
  // eye. "B6935" read as a word is unintelligible; "$189" read raw becomes
  // "dollar one eight nine".
  // -------------------------------------------------------------------

  /// Every character on its own, for codes that are read rather than
  /// pronounced: "ABC123" → "A B C 1 2 3". PNRs are the case that matters —
  /// [_spellOut] would render "5QW08HB" as "5 QW 08 HB", which no passenger
  /// could write down.
  String _spellLetters(String code) =>
      code.trim().split('').where((c) => c.trim().isNotEmpty).join(' ');

  /// Small counts read better as words — "three options", not "3 options".
  String _countWord(int n) => switch (n) {
        0 => 'no',
        1 => 'one',
        2 => 'two',
        3 => 'three',
        4 => 'four',
        5 => 'five',
        6 => 'six',
        7 => 'seven',
        8 => 'eight',
        9 => 'nine',
        10 => 'ten',
        _ => '$n',
      };

  /// Splits a code into individual letters and whole number groups:
  /// "AA50" → "A A 50", "B6935" → "B 6935", "14A" → "14 A".
  ///
  /// Letters go one at a time because an airline code is read, not pronounced —
  /// "AA50" left joined comes out of the engine as "aa fifty". Digits stay
  /// grouped, because a flight number's digits *are* said as a number.
  String _spellOut(String code) {
    return code
        .replaceAllMapped(
          RegExp(r'[A-Za-z]|\d+'),
          (match) => '${match.group(0)} ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Turns a backend route string into something speakable: "DFW→LHR" becomes
  /// "D F W to L H R". The arrow is invisible to a listener, and the codes are
  /// nonsense words unless spelled.
  String _route(String route) {
    final legs = route
        .split(RegExp(r'[→\-–>]+'))
        .map((leg) => leg.trim())
        .where((leg) => leg.isNotEmpty)
        .map(_place)
        .toList();
    return legs.isEmpty ? route : legs.join(' to ');
  }

  String _flightNumber(String value) => 'flight ${_spellOut(value)}';

  /// IATA codes get spelled letter by letter — "EWR" otherwise comes out as
  /// a nonsense word.
  String _place(String value) {
    final isAirportCode = value.length == 3 && RegExp(r'^[A-Z]{3}$').hasMatch(value);
    return isAirportCode ? value.split('').join(' ') : value;
  }

  /// Rounding a fare down to whole units quietly misstates the price, so the
  /// cents are spoken when there are any.
  String _money(num amount, String currency) {
    final unit = switch (currency.toUpperCase()) {
      'USD' => 'dollars',
      'EUR' => 'euros',
      'GBP' => 'pounds',
      'INR' => 'rupees',
      'AED' => 'dirhams',
      _ => currency,
    };

    final whole = amount.truncate();
    final cents = ((amount - whole) * 100).round();
    if (cents == 0) return '$whole $unit';
    // Guards against 189.999 rounding into "189 dollars and 100 cents".
    if (cents == 100) return '${whole + 1} $unit';
    return '$whole $unit and $cents cents';
  }

  String _weight(num kg) => '${kg.round()} kilos';

  String _time(DateTime time) {
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final period = time.hour < 12 ? 'A M' : 'P M';
    if (time.minute == 0) return '$hour12 $period';
    // "5:05" reads better as "5 oh 5" than "5 5".
    final minute =
        time.minute < 10 ? 'oh ${time.minute}' : time.minute.toString();
    return '$hour12 $minute $period';
  }

  String _stops(int stops) => switch (stops) {
        0 => 'non-stop',
        1 => 'one stop',
        _ => '$stops stops',
      };

  String _status(FlightStatus status) => switch (status) {
        FlightStatus.scheduled => 'on time',
        FlightStatus.boarding => 'boarding now',
        FlightStatus.delayed => 'delayed',
        FlightStatus.departed => 'already departed',
        FlightStatus.cancelled => 'cancelled',
        FlightStatus.landed => 'landed',
        FlightStatus.unknown => 'not showing a status',
      };
}
