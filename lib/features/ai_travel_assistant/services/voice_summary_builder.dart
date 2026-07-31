import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/agent_escalation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/airport_info.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking_summary.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/spoken_draft.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/display_text_formatter.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/speech_text_formatter.dart';

/// Builds the short spoken version of a chat message.
///
/// Rich cards carry far more detail than anyone wants read to them: a seat
/// map is a grid of 50-plus seats, an offers list is four flights with times
/// and prices. Reading those verbatim is the difference between an assistant
/// and a screen reader. Each card instead gets a summary that states the
/// headline fact and hands the conversation back to the passenger.
///
/// Each card produces a [SpokenDraft] rather than a finished sentence: the
/// facts, the tone, and what to invite next, plus one deterministic phrasing
/// as [SpokenDraft.fallbackText]. `SpeechPhraser` then words the turn, so two
/// identical seat maps don't produce the identical sentence twice. The
/// fallback is what gets spoken whenever phrasing is off or unavailable, which
/// is why it stays complete copy in its own right.
///
/// Spoken copy is polite, gentle, and helpful — short, but never curt or
/// commanding. Prefer invitations ("would you like…") over instructions
/// ("say…").
///
/// Pure and side-effect free so it can be unit tested without any plugins.
class VoiceSummaryBuilder {
  const VoiceSummaryBuilder._();

  /// The facts to speak for [message], or `null` when the message carries no
  /// card worth summarising — plain text and errors are spoken as written,
  /// because the passenger is also reading them on screen.
  static SpokenDraft? draft(ChatMessage message, {DateTime? now}) {
    final payload = message.payload;

    final draft = switch (message.type) {
      ChatMessageType.flightOffersCard =>
        payload is List<FlightOffer> ? _flightOffers(payload) : null,
      ChatMessageType.flightStatusCard => payload is Flight ? _flightStatus(payload) : null,
      ChatMessageType.seatMapCard => payload is SeatMap ? _seatMap(payload) : null,
      ChatMessageType.baggageOptionsCard =>
        payload is List<BaggageOption> ? _baggageOptions(payload) : null,
      ChatMessageType.baggageSuccessCard =>
        payload is BaggagePurchase ? _baggageSuccess(payload) : null,
      ChatMessageType.bookingConfirmationCard =>
        payload is BookingSummary ? _bookingConfirmation(payload, now: now) : null,
      ChatMessageType.airportInfoCard => payload is AirportInfo ? _airportInfo(payload) : null,
      ChatMessageType.agentEscalationCard =>
        payload is EscalationResult ? _escalation(payload) : null,
      ChatMessageType.text || ChatMessageType.error => null,
    };

    return draft == null ? null : _speechReady(draft);
  }

  /// The deterministic spoken text for [message], or `null` when the caller
  /// should fall back to the message's own display text.
  ///
  /// This is the phrasing-free path: same copy this module spoke before the
  /// phrasing layer existed, and what tests assert against.
  static String? build(ChatMessage message, {DateTime? now}) {
    final drafted = draft(message, now: now);
    if (drafted != null) return drafted.fallbackText;

    return switch (message.type) {
      ChatMessageType.text => SpeechTextFormatter.truncateForSpeech(message.text),
      ChatMessageType.error => SpeechTextFormatter.clean(message.text),
      // A card whose payload didn't match its type: say nothing rather than
      // guess, and let the caller read the message's own text instead.
      _ => null,
    };
  }

  /// Runs every string in [draft] through [SpeechTextFormatter.clean] so
  /// display glyphs like em dashes become natural spoken pauses. Cleaning in
  /// one place here means neither the fallback nor a model phrasing built from
  /// these clauses can leak markdown into the engine.
  static SpokenDraft _speechReady(SpokenDraft draft) {
    return SpokenDraft(
      topic: draft.topic,
      fallbackText: SpeechTextFormatter.clean(draft.fallbackText),
      displayFallbackText: draft.displayFallbackText == null
          ? null
          : SpeechTextFormatter.clean(draft.displayFallbackText!),
      clauses: draft.clauses.map(SpeechTextFormatter.clean).toList(growable: false),
      invitation: draft.invitation,
      tone: draft.tone,
      mustInclude: draft.mustInclude.map(SpeechTextFormatter.clean).toList(growable: false),
      displayMustInclude: draft.displayMustInclude,
    );
  }

  static SpokenDraft _flightOffers(List<FlightOffer> offers) {
    if (offers.isEmpty) {
      return const SpokenDraft(
        topic: SpokenTopic.noFlightsFound,
        tone: SpokenTone.apologetic,
        clauses: ["I couldn't find any flights on that route"],
        invitation: SpokenInvitation.offerOtherDates,
        fallbackText: "I'm sorry, I couldn't find any flights on that route. "
            'Would you like to try a different date or destination?',
        displayFallbackText: "I'm sorry, I couldn't find any flights on that route. "
            'Would you like to try a different date or destination?',
      );
    }

    final route = 'from ${SpeechTextFormatter.airport(offers.first.origin)} '
        'to ${SpeechTextFormatter.airport(offers.first.destination)}';
    final displayRoute = 'from ${DisplayTextFormatter.airport(offers.first.origin)} '
        'to ${DisplayTextFormatter.airport(offers.first.destination)}';
    final cheapest = offers.reduce((a, b) => b.price < a.price ? b : a);
    final fare = SpeechTextFormatter.price(cheapest.price, cheapest.currency);
    final displayFare = DisplayTextFormatter.price(cheapest.price, cheapest.currency);
    final describedCheapest =
        '${cheapest.airline} at $fare, departing ${SpeechTextFormatter.time(cheapest.departureTime)}';
    final displayCheapest =
        '${cheapest.airline} at $displayFare, departing ${DisplayTextFormatter.time(cheapest.departureTime)}';

    if (offers.length == 1) {
      return SpokenDraft(
        topic: SpokenTopic.flightOffers,
        clauses: ['the one flight $route is $describedCheapest'],
        invitation: SpokenInvitation.confirmSingleOffer,
        mustInclude: [cheapest.airline, fare],
        displayMustInclude: [cheapest.airline, displayFare],
        fallbackText: 'I found one flight $route: $describedCheapest. '
            'Would you like me to book it for you?',
        displayFallbackText: 'I found one flight $displayRoute: $displayCheapest. '
            'Would you like me to book it for you?',
      );
    }

    return SpokenDraft(
      topic: SpokenTopic.flightOffers,
      clauses: [
        'there are ${offers.length} flights $route',
        'the lowest fare is $describedCheapest',
      ],
      invitation: SpokenInvitation.chooseOffer,
      mustInclude: [cheapest.airline, fare],
      displayMustInclude: [cheapest.airline, displayFare],
      fallbackText: 'I found ${offers.length} flights $route. '
          'The cheapest is $describedCheapest. '
          "You're welcome to name an airline, or ask for the cheapest one.",
      displayFallbackText: 'I found ${offers.length} flights $displayRoute. '
          'The cheapest is $displayCheapest. '
          'Name an airline, or ask for the cheapest one.',
    );
  }

  static SpokenDraft _flightStatus(Flight flight) {
    final number = SpeechTextFormatter.flightNumber(flight.flightNumber);
    final displayNumber = DisplayTextFormatter.flightNumber(flight.flightNumber);
    final buffer = StringBuffer(_statusLead(number, flight.status));
    final displayBuffer = StringBuffer(_statusLead(displayNumber, flight.status));
    final clauses = <String>[_statusClause(number, flight.status)];
    final mustInclude = <String>[number];
    final displayMustInclude = <String>[displayNumber];

    final departure = flight.estimatedDeparture ?? flight.scheduledDeparture;
    final departureTime = SpeechTextFormatter.time(departure);
    final displayDepartureTime = DisplayTextFormatter.time(departure);
    if (flight.isDelayed && flight.estimatedDeparture != null) {
      buffer.write(' The new departure is $departureTime.');
      displayBuffer.write(' The new departure is $displayDepartureTime.');
      clauses.add('the new departure time is $departureTime');
      mustInclude.add(departureTime);
      displayMustInclude.add(displayDepartureTime);
    } else if (flight.status != FlightStatus.cancelled) {
      buffer.write(' Departure is $departureTime.');
      displayBuffer.write(' Departure is $displayDepartureTime.');
      clauses.add('departure is at $departureTime');
      mustInclude.add(departureTime);
      displayMustInclude.add(displayDepartureTime);
    }

    if (flight.gate != null) {
      final gate = SpeechTextFormatter.code(flight.gate!);
      final displayGate = DisplayTextFormatter.code(flight.gate!);
      buffer.write(' Gate $gate.');
      displayBuffer.write(' Gate $displayGate.');
      clauses.add('the gate is $gate');
      mustInclude.add(gate);
      displayMustInclude.add(displayGate);
    }
    if (flight.terminal != null) {
      final terminal = SpeechTextFormatter.code(flight.terminal!);
      final displayTerminal = DisplayTextFormatter.code(flight.terminal!);
      buffer.write(' Terminal $terminal.');
      displayBuffer.write(' Terminal $displayTerminal.');
      clauses.add('it goes from terminal $terminal');
      mustInclude.add(terminal);
      displayMustInclude.add(displayTerminal);
    }

    final disrupted = flight.status == FlightStatus.delayed ||
        flight.status == FlightStatus.cancelled;

    return SpokenDraft(
      topic: SpokenTopic.flightStatus,
      tone: disrupted ? SpokenTone.apologetic : SpokenTone.neutral,
      clauses: clauses,
      invitation: SpokenInvitation.anythingElse,
      mustInclude: mustInclude,
      displayMustInclude: displayMustInclude,
      fallbackText: buffer.toString(),
      displayFallbackText: displayBuffer.toString(),
    );
  }

  static String _statusLead(String number, FlightStatus status) => switch (status) {
        FlightStatus.delayed => "I'm sorry — flight $number is delayed.",
        FlightStatus.cancelled => "I'm sorry — flight $number has been cancelled.",
        _ => 'Flight $number is ${_statusWording(status)}.',
      };

  static String _statusClause(String number, FlightStatus status) => switch (status) {
        FlightStatus.cancelled => 'flight $number has been cancelled',
        _ => 'flight $number is ${_statusWording(status)}',
      };

  static String _statusWording(FlightStatus status) => switch (status) {
        FlightStatus.scheduled => 'on time',
        FlightStatus.boarding => 'boarding now',
        FlightStatus.delayed => 'delayed',
        FlightStatus.departed => 'already departed',
        FlightStatus.cancelled => 'cancelled',
        FlightStatus.landed => 'landed',
        FlightStatus.unknown => 'not showing a status right now',
      };

  static SpokenDraft _seatMap(SeatMap seatMap) {
    final available = seatMap.seats.where((seat) => seat.isAvailable).toList();
    if (available.isEmpty) {
      return const SpokenDraft(
        topic: SpokenTopic.noSeatsAvailable,
        tone: SpokenTone.apologetic,
        clauses: ["there aren't any free seats to choose from on this flight right now"],
        invitation: SpokenInvitation.anythingElse,
        fallbackText: "I've put the seat map on your screen, but there aren't any free "
            "seats to choose from right now. I'm happy to help another way if you'd like.",
        displayFallbackText: "I've put the seat map on your screen, but there aren't any free "
            "seats to choose from right now. I'm happy to help another way if you'd like.",
      );
    }

    final example = available.firstWhere(
      (seat) => seat.type == SeatType.window,
      orElse: () => available.first,
    );

    return SpokenDraft(
      topic: SpokenTopic.seatMap,
      clauses: [
        'the seat map is on your screen',
        available.length == 1 ? 'there is 1 seat free' : 'there are ${available.length} seats free',
      ],
      invitation: SpokenInvitation.chooseSeat,
      fallbackText: "I've put the seat map on your screen. Would you like a window, "
          'an aisle, or a specific seat like ${SpeechTextFormatter.seat(example.seatNumber)}?',
      displayFallbackText: "I've put the seat map on your screen. Would you like a window, "
          'an aisle, or a specific seat like ${DisplayTextFormatter.seat(example.seatNumber)}?',
    );
  }

  static SpokenDraft _baggageOptions(List<BaggageOption> options) {
    if (options.isEmpty) {
      return const SpokenDraft(
        topic: SpokenTopic.baggageOptions,
        tone: SpokenTone.apologetic,
        clauses: ["there aren't any extra baggage options for this flight"],
        invitation: SpokenInvitation.anythingElse,
        fallbackText: "I'm afraid there aren't any extra baggage options for this flight.",
        displayFallbackText:
            "I'm afraid there aren't any extra baggage options for this flight.",
      );
    }

    final weights = options.map((option) => _number(option.extraWeightKg)).toList();
    return SpokenDraft(
      topic: SpokenTopic.baggageOptions,
      clauses: ['you can add ${_asList(weights)} extra kilos'],
      invitation: SpokenInvitation.chooseBaggage,
      mustInclude: weights,
      displayMustInclude: weights,
      fallbackText: "You're welcome to add ${_asList(weights)} kilos. Which would you prefer?",
      displayFallbackText:
          "You're welcome to add ${_asList(weights)} kilos. Which would you prefer?",
    );
  }

  static SpokenDraft _baggageSuccess(BaggagePurchase purchase) {
    if (purchase.status != BaggagePurchaseStatus.success) {
      return const SpokenDraft(
        topic: SpokenTopic.baggageFailed,
        tone: SpokenTone.apologetic,
        clauses: [
          "that baggage purchase didn't go through",
          'you can try again whenever you like',
        ],
        fallbackText: "I'm sorry, that baggage purchase didn't go through. "
            "Please try again whenever you're ready.",
        displayFallbackText: "I'm sorry, that baggage purchase didn't go through. "
            "Please try again whenever you're ready.",
      );
    }

    final kilos = _number(purchase.option.extraWeightKg);
    return SpokenDraft(
      topic: SpokenTopic.baggagePurchased,
      tone: SpokenTone.celebratory,
      clauses: ['$kilos extra kilos are confirmed'],
      invitation: SpokenInvitation.anythingElse,
      mustInclude: [kilos],
      displayMustInclude: [kilos],
      fallbackText: 'All set — $kilos extra kilos are confirmed.',
      displayFallbackText: 'All set — $kilos extra kilos are confirmed.',
    );
  }

  static SpokenDraft _bookingConfirmation(BookingSummary summary, {DateTime? now}) {
    final flight = summary.booking.flight;
    final pnr = SpeechTextFormatter.code(summary.booking.pnr);
    final displayPnr = DisplayTextFormatter.code(summary.booking.pnr);
    final buffer = StringBuffer("You're all set. Your confirmation is $pnr.");
    final displayBuffer = StringBuffer("You're all set. Your confirmation is $displayPnr.");
    final clauses = <String>['your confirmation code is $pnr'];
    final mustInclude = <String>[pnr];
    final displayMustInclude = <String>[displayPnr];

    if (summary.seatNumber != null) {
      final seat = SpeechTextFormatter.seat(summary.seatNumber!);
      final displaySeat = DisplayTextFormatter.seat(summary.seatNumber!);
      buffer.write(' Seat $seat.');
      displayBuffer.write(' Seat $displaySeat.');
      clauses.add('your seat is $seat');
      mustInclude.add(seat);
      displayMustInclude.add(displaySeat);
    }
    if (summary.extraBaggageKg > 0) {
      final kilos = _number(summary.extraBaggageKg);
      buffer.write(' $kilos extra kilos of baggage.');
      displayBuffer.write(' $kilos extra kilos of baggage.');
      clauses.add('$kilos extra kilos of baggage are included');
      mustInclude.add(kilos);
      displayMustInclude.add(kilos);
    }

    final departure = flight.scheduledDeparture;
    final day = SpeechTextFormatter.relativeDay(departure, now: now);
    final displayDay = DisplayTextFormatter.relativeDay(departure, now: now);
    final time = SpeechTextFormatter.time(departure);
    final displayTime = DisplayTextFormatter.time(departure);
    buffer.write(' Departing $day at $time. Have a wonderful trip.');
    displayBuffer.write(' Departing $displayDay at $displayTime. Have a wonderful trip.');
    clauses.add('you depart $day at $time');
    mustInclude.add(time);
    displayMustInclude.add(displayTime);

    return SpokenDraft(
      topic: SpokenTopic.bookingConfirmed,
      tone: SpokenTone.celebratory,
      clauses: clauses,
      invitation: SpokenInvitation.wishWell,
      mustInclude: mustInclude,
      displayMustInclude: displayMustInclude,
      fallbackText: buffer.toString(),
      displayFallbackText: displayBuffer.toString(),
    );
  }

  static SpokenDraft _airportInfo(AirportInfo info) {
    final terminal = SpeechTextFormatter.code(info.terminal);
    final gate = SpeechTextFormatter.code(info.gate);
    final counter = SpeechTextFormatter.code(info.checkInCounter);
    final displayTerminal = DisplayTextFormatter.code(info.terminal);
    final displayGate = DisplayTextFormatter.code(info.gate);
    final displayCounter = DisplayTextFormatter.code(info.checkInCounter);

    final buffer = StringBuffer(
      "Here's what you'll need: terminal $terminal, gate $gate, "
      'and check-in counter $counter.',
    );
    final displayBuffer = StringBuffer(
      "Here's what you'll need: terminal $displayTerminal, gate $displayGate, "
      'and check-in counter $displayCounter.',
    );
    buffer.write(" It's about a ${info.walkingTimeMinutes} minute walk.");
    displayBuffer.write(" It's about a ${info.walkingTimeMinutes} minute walk.");
    if (info.directions.isNotEmpty) {
      buffer.write(' ${SpeechTextFormatter.clean(info.directions.first)}');
      displayBuffer.write(' ${info.directions.first}');
    }

    return SpokenDraft(
      topic: SpokenTopic.airportInfo,
      clauses: [
        'you want terminal $terminal',
        'gate $gate',
        'check-in counter $counter',
        "it's about a ${info.walkingTimeMinutes} minute walk",
      ],
      invitation: SpokenInvitation.anythingElse,
      mustInclude: [terminal, gate, counter],
      displayMustInclude: [displayTerminal, displayGate, displayCounter],
      fallbackText: buffer.toString(),
      displayFallbackText: displayBuffer.toString(),
    );
  }

  static SpokenDraft _escalation(EscalationResult escalation) {
    final position = escalation.queuePosition.toString();
    final wait = escalation.estimatedWaitMinutes.toString();

    return SpokenDraft(
      topic: SpokenTopic.agentEscalation,
      tone: SpokenTone.reassuring,
      clauses: [
        "I'm connecting you to an agent now",
        "you're number $position in the queue",
        'the wait is about $wait minutes',
      ],
      invitation: SpokenInvitation.awaitAgent,
      mustInclude: [position, wait],
      displayMustInclude: [position, wait],
      fallbackText: "Of course — I'm connecting you to an agent now. "
          "You're number $position in the queue, "
          'with about $wait minutes to wait.',
      displayFallbackText: "Of course — I'm connecting you to an agent now. "
          "You're number $position in the queue, "
          'with about $wait minutes to wait.',
    );
  }

  /// Drops the trailing ".0" that `num` prints for whole values, so the
  /// engine says "10 kilos" rather than "ten point zero kilos".
  static String _number(num value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  static String _asList(List<String> items) {
    if (items.length == 1) return items.single;
    if (items.length == 2) return '${items.first} or ${items.last}';
    return '${items.sublist(0, items.length - 1).join(', ')}, or ${items.last}';
  }
}
