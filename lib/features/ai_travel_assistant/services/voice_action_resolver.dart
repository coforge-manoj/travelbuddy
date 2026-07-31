import 'package:equatable/equatable.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/display_text_formatter.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/speech_text_formatter.dart';

/// What the passenger is currently being asked to choose from. Held on the
/// chat state so a transcript is interpreted against the card actually on
/// screen, and so a stale card can't capture an unrelated utterance.
enum VoiceContextKind { none, flightOffers, seatMap, baggageOptions }

class VoiceContext extends Equatable {
  const VoiceContext.none()
      : kind = VoiceContextKind.none,
        payload = null;

  const VoiceContext.flightOffers(List<FlightOffer> offers)
      : kind = VoiceContextKind.flightOffers,
        payload = offers;

  const VoiceContext.seatMap(SeatMap seatMap)
      : kind = VoiceContextKind.seatMap,
        payload = seatMap;

  const VoiceContext.baggageOptions(List<BaggageOption> options)
      : kind = VoiceContextKind.baggageOptions,
        payload = options;

  final VoiceContextKind kind;
  final Object? payload;

  @override
  List<Object?> get props => [kind, payload];
}

/// The result of interpreting a transcript: either something to do, a
/// question to ask back, or (via `null`) nothing recognizable, in which case
/// the caller falls back to normal intent classification.
sealed class VoiceOutcome extends Equatable {
  const VoiceOutcome();
}

sealed class VoiceAction extends VoiceOutcome {
  const VoiceAction();

  /// Whether executing this would book something or charge the passenger.
  /// Gated actions are read back and require an explicit spoken yes.
  bool get requiresConfirmation => false;

  /// The read-back question, spoken before a gated action runs. States the
  /// price so nobody agrees to a charge they didn't hear.
  String get confirmationPrompt => '';

  /// On-screen counterpart to [confirmationPrompt]. Uses readable times and
  /// codes ("5:05 AM", "B6935") rather than speech spelling ("5 oh 5").
  String get confirmationDisplayText => confirmationPrompt;
}

class SelectOfferAction extends VoiceAction {
  const SelectOfferAction(this.offer);

  final FlightOffer offer;

  @override
  bool get requiresConfirmation => true;

  @override
  String get confirmationPrompt =>
      '${offer.airline}, flight ${SpeechTextFormatter.flightNumber(offer.flightNumber)}, '
      'departing ${SpeechTextFormatter.time(offer.departureTime)}, '
      '${SpeechTextFormatter.price(offer.price, offer.currency)}. '
      'Would you like me to book it for you?';

  @override
  String get confirmationDisplayText =>
      '${offer.airline}, flight ${DisplayTextFormatter.flightNumber(offer.flightNumber)}, '
      'departing ${DisplayTextFormatter.time(offer.departureTime)}, '
      '${DisplayTextFormatter.price(offer.price, offer.currency)}. '
      'Would you like me to book it for you?';

  @override
  List<Object?> get props => [offer];
}

class SelectSeatAction extends VoiceAction {
  const SelectSeatAction(this.seat, {this.currency = 'USD'});

  final Seat seat;
  final String currency;

  /// Free seats go straight through — only a seat that costs extra needs
  /// the passenger to agree to the charge first.
  @override
  bool get requiresConfirmation => seat.priceDelta > 0;

  @override
  String get confirmationPrompt => 'Seat ${SpeechTextFormatter.seat(seat.seatNumber)} costs an '
      'extra ${SpeechTextFormatter.price(seat.priceDelta, currency)}. '
      'Would you like me to reserve it for you?';

  @override
  String get confirmationDisplayText =>
      'Seat ${DisplayTextFormatter.seat(seat.seatNumber)} costs an '
      'extra ${DisplayTextFormatter.price(seat.priceDelta, currency)}. '
      'Would you like me to reserve it for you?';

  @override
  List<Object?> get props => [seat, currency];
}

class SkipSeatAction extends VoiceAction {
  const SkipSeatAction();

  @override
  List<Object?> get props => [];
}

class SelectBaggageAction extends VoiceAction {
  const SelectBaggageAction(this.option);

  final BaggageOption option;

  @override
  bool get requiresConfirmation => true;

  @override
  String get confirmationPrompt =>
      '${_number(option.extraWeightKg)} extra kilos for '
      '${SpeechTextFormatter.price(option.price, option.currency)}. '
      'Would you like me to add that for you?';

  @override
  String get confirmationDisplayText =>
      '${_number(option.extraWeightKg)} extra kilos for '
      '${DisplayTextFormatter.price(option.price, option.currency)}. '
      'Would you like me to add that for you?';

  @override
  List<Object?> get props => [option];
}

class SkipBaggageAction extends VoiceAction {
  const SkipBaggageAction();

  @override
  List<Object?> get props => [];
}

/// Executes whatever was last read back or proposed. Never a guess — the
/// caller only acts on this when a pending target exists.
class ConfirmPendingAction extends VoiceAction {
  const ConfirmPendingAction();

  @override
  List<Object?> get props => [];
}

class CancelAction extends VoiceAction {
  const CancelAction();

  @override
  List<Object?> get props => [];
}

/// A clarifying question to ask instead of guessing. When [suggestion] is
/// set, a following "yes" should run it.
///
/// [question] is the on-screen wording; [spokenQuestion] is what TTS reads
/// when speech needs a different spelling (times, codes).
class VoiceAmbiguity extends VoiceOutcome {
  const VoiceAmbiguity(this.question, {this.suggestion, this.spokenQuestion});

  final String question;
  final String? spokenQuestion;
  final VoiceAction? suggestion;

  String get speechText => spokenQuestion ?? question;

  @override
  List<Object?> get props => [question, spokenQuestion, suggestion];
}

/// Maps spoken phrases onto the actions the chat already supports.
///
/// Closed-set matching for the phrases that matter most ("the cheapest one",
/// "window", "ten kilos", "yes") — predictable enough to trust in front of a
/// payment step. Natural language the rules miss is handled by
/// [HybridVoiceActionParser], which asks an LLM and rebinds the answer onto
/// this same [VoiceOutcome] hierarchy.
class VoiceActionResolver {
  const VoiceActionResolver._();

  static const _affirmatives = <String>{
    'yes', 'yeah', 'yep', 'yup', 'sure', 'ok', 'okay', 'confirm', 'confirmed',
    'do it', 'go ahead', 'book it', 'add it', 'take it', 'looks good',
    'sounds good', 'please do', 'absolutely', 'correct', 'that works',
  };

  static const _negatives = <String>{
    'no', 'nope', 'nah', 'cancel', 'stop', 'never mind', 'nevermind',
    'go back', 'start over', 'forget it', 'not now', 'no thanks',
  };

  static VoiceOutcome? resolve({
    required String transcript,
    required VoiceContext context,
    VoiceAction? pendingConfirmation,
  }) {
    final text = _normalize(transcript);
    if (text.isEmpty) return null;

    // A pending read-back owns the next yes/no outright, so "yes" can never
    // mean something the passenger didn't just hear.
    if (pendingConfirmation != null) {
      if (_matchesAny(text, _affirmatives)) return const ConfirmPendingAction();
      if (_matchesAny(text, _negatives)) return const CancelAction();
    }

    final contextual = switch (context.kind) {
      VoiceContextKind.flightOffers => _resolveOffers(text, context.payload as List<FlightOffer>),
      VoiceContextKind.seatMap => _resolveSeat(text, context.payload as SeatMap),
      VoiceContextKind.baggageOptions =>
        _resolveBaggage(text, context.payload as List<BaggageOption>),
      VoiceContextKind.none => null,
    };
    if (contextual != null) return contextual;

    if (_matchesAny(text, _negatives)) return const CancelAction();

    return null;
  }

  // ---------------------------------------------------------------------
  // Flight offers
  // ---------------------------------------------------------------------

  static VoiceOutcome? _resolveOffers(String text, List<FlightOffer> offers) {
    if (offers.isEmpty) return null;

    if (_containsAny(text, ['cheapest', 'least expensive', 'lowest price', 'cheapest one'])) {
      return SelectOfferAction(offers.reduce((a, b) => b.price < a.price ? b : a));
    }
    if (_containsAny(text, ['earliest', 'first flight', 'soonest'])) {
      return SelectOfferAction(
        offers.reduce((a, b) => b.departureTime.isBefore(a.departureTime) ? b : a),
      );
    }
    if (_containsAny(text, ['latest', 'last flight'])) {
      return SelectOfferAction(
        offers.reduce((a, b) => b.departureTime.isAfter(a.departureTime) ? b : a),
      );
    }

    final flightNumberMatch = _matchFlightNumber(text, offers);
    if (flightNumberMatch != null) return SelectOfferAction(flightNumberMatch);

    final airlineMatches = offers.where((offer) => _mentionsAirline(text, offer.airline)).toList();
    if (airlineMatches.length == 1) return SelectOfferAction(airlineMatches.single);
    if (airlineMatches.length > 1) {
      return VoiceAmbiguity(
        'I have ${airlineMatches.length} ${airlineMatches.first.airline} flights. '
        'The ${DisplayTextFormatter.time(airlineMatches.first.departureTime)} one, '
        'or the ${DisplayTextFormatter.time(airlineMatches.last.departureTime)} one?',
        spokenQuestion: 'I have ${airlineMatches.length} ${airlineMatches.first.airline} flights. '
            'The ${SpeechTextFormatter.time(airlineMatches.first.departureTime)} one, '
            'or the ${SpeechTextFormatter.time(airlineMatches.last.departureTime)} one?',
      );
    }

    final ordinal = _matchOrdinal(text, offers.length);
    if (ordinal != null) return SelectOfferAction(offers[ordinal]);

    return null;
  }

  static FlightOffer? _matchFlightNumber(String text, List<FlightOffer> offers) {
    final condensed = text.replaceAll(' ', '');
    for (final offer in offers) {
      if (condensed.contains(offer.flightNumber.toLowerCase())) return offer;
    }
    return null;
  }

  /// Matches on the distinctive parts of an airline name.
  ///
  /// Handles spaced STT forms of compound brands ("jet blue" for "JetBlue")
  /// via a compact compare, and CamelCase splits so both "jet" and "blue"
  /// count. Shared words like "airlines" still match nothing on their own.
  static bool _mentionsAirline(String text, String airline) {
    const generic = {'airlines', 'airline', 'air', 'lines', 'the'};

    final compactAirline = airline.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final compactText = text.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (compactAirline.length >= 4 &&
        !generic.contains(compactAirline) &&
        compactText.contains(compactAirline)) {
      return true;
    }

    final spaced = airline
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) => '${match[1]} ${match[2]}')
        .replaceAllMapped(
          RegExp(r'([A-Z]+)([A-Z][a-z])'),
          (match) => '${match[1]} ${match[2]}',
        )
        .toLowerCase();
    final tokens = spaced
        .split(RegExp(r'[\s-]+'))
        .where((token) => token.length > 2 && !generic.contains(token))
        .toList();
    if (tokens.isEmpty) return false;
    if (tokens.length >= 2) {
      return tokens.every((token) => _containsWord(text, token));
    }
    return _containsWord(text, tokens.single);
  }

  // ---------------------------------------------------------------------
  // Seats
  // ---------------------------------------------------------------------

  static VoiceOutcome? _resolveSeat(String text, SeatMap seatMap) {
    if (_containsAny(text, ['skip', 'no seat', 'later', 'assign one', 'dont care', 'do not care'])) {
      return const SkipSeatAction();
    }

    final available = seatMap.seats.where((seat) => seat.isAvailable).toList();

    final requested = _matchSeatNumber(text);
    if (requested != null) {
      final seat = seatMap.seats
          .where((candidate) => candidate.seatNumber.toUpperCase() == requested)
          .firstOrNull;

      if (seat == null) {
        return VoiceAmbiguity(
          "I don't see seat ${DisplayTextFormatter.seat(requested)} on this flight. "
          'Which seat would you like?',
          spokenQuestion: "I don't see seat ${SpeechTextFormatter.seat(requested)} on this flight. "
              'Which seat would you like?',
        );
      }
      if (!seat.isAvailable) {
        final alternative = _nearestAlternative(available, seat);
        if (alternative == null) {
          return VoiceAmbiguity(
            'Seat ${DisplayTextFormatter.seat(requested)} is taken, and I have '
            'nothing else free. Would you like me to check another flight?',
            spokenQuestion: 'Seat ${SpeechTextFormatter.seat(requested)} is taken, and I have '
                'nothing else free. Would you like me to check another flight?',
          );
        }
        return VoiceAmbiguity(
          'Seat ${DisplayTextFormatter.seat(requested)} is taken. '
          '${DisplayTextFormatter.seat(alternative.seatNumber)} is free. Want that instead?',
          spokenQuestion: 'Seat ${SpeechTextFormatter.seat(requested)} is taken. '
              '${SpeechTextFormatter.seat(alternative.seatNumber)} is free. Want that instead?',
          suggestion: SelectSeatAction(alternative, currency: seatMap.currency),
        );
      }
      return SelectSeatAction(seat, currency: seatMap.currency);
    }

    if (available.isEmpty) return null;

    final preferred = _preferredSeatType(text);
    if (preferred != null) {
      final matching = available.where((seat) => seat.type == preferred).toList();
      if (matching.isEmpty) {
        return VoiceAmbiguity(
          'I have no ${_seatTypeWord(preferred)} seats free. '
          'Would another kind of seat work?',
          suggestion: SelectSeatAction(_cheapest(available), currency: seatMap.currency),
        );
      }
      return SelectSeatAction(_cheapest(matching), currency: seatMap.currency);
    }

    if (_containsAny(text, ['any seat', 'anything', 'you pick', 'you choose', 'whatever'])) {
      return SelectSeatAction(_cheapest(available), currency: seatMap.currency);
    }

    // "I'd like to pick a seat" while the map is already up names nothing to
    // act on. Asking which one keeps the passenger on this card — falling
    // through would re-classify it as a fresh seat-selection intent and stack
    // a second, identical seat map underneath the first.
    if (_isBareSeatRequest(text)) {
      return const VoiceAmbiguity(
        'Which seat would you like? You can say a seat like 12A, or just '
        'window or aisle.',
      );
    }

    return null;
  }

  /// A seat named outright, as "12A", "12 a", "twelve a", or
  /// "row twelve seat a" — normalized to the map's own spelling ("12A").
  ///
  /// Word-form numbers are not a nicety: recognizers routinely transcribe a
  /// short spoken row as a word ("twelve a"), and a digits-only match makes
  /// the assistant deaf to the most natural way to say a seat out loud.
  static String? _matchSeatNumber(String text) {
    final digits = _digitizeRows(text);

    final adjacent = RegExp(r'\b(\d{1,2})\s*([a-f])\b').firstMatch(digits);
    if (adjacent != null) {
      return '${adjacent.group(1)}${adjacent.group(2)!.toUpperCase()}';
    }

    // "row 12, seat A" — the same choice with the labels spoken out.
    final spelled =
        RegExp(r'\brow\s+(\d{1,2})\b.{0,12}?\bseat\s+([a-f])\b').firstMatch(digits);
    if (spelled != null) {
      return '${spelled.group(1)}${spelled.group(2)!.toUpperCase()}';
    }

    return null;
  }

  /// Rewrites spelled-out row numbers as digits so one seat pattern covers
  /// both transcriptions. Only touches words immediately before a seat
  /// letter or after "row", so "one" in "the first one" stays a word.
  static String _digitizeRows(String text) {
    const units = <String, int>{
      'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6,
      'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'eleven': 11,
      'twelve': 12, 'thirteen': 13, 'fourteen': 14, 'fifteen': 15,
      'sixteen': 16, 'seventeen': 17, 'eighteen': 18, 'nineteen': 19,
      'twenty': 20, 'thirty': 30, 'forty': 40,
    };

    // Longest first so "twenty two" never resolves as a bare "twenty".
    final compound = RegExp(
      r'\b(twenty|thirty|forty)[\s-](one|two|three|four|five|six|seven|eight|nine)\b',
    );
    var result = text.replaceAllMapped(compound, (match) {
      return '${units[match.group(1)]! + units[match.group(2)]!}';
    });

    final single = RegExp('\\b(${units.keys.join('|')})\\b');
    result = result.replaceAllMapped(single, (match) {
      final value = units[match.group(1)]!;
      final rest = result.substring(match.end);
      final before = result.substring(0, match.start);
      // Only where a row could plausibly be meant: right before a seat
      // letter, or right after the word "row".
      final followedByLetter = RegExp(r'^\s*[a-f]\b').hasMatch(rest);
      final followsRow = RegExp(r'\brow\s+$').hasMatch(before);
      return followedByLetter || followsRow ? '$value' : match.group(0)!;
    });

    return result;
  }

  /// True for "let me pick a seat" and friends: a seat is asked for, but no
  /// row, letter, or preference is named.
  static bool _isBareSeatRequest(String text) {
    if (!_containsWord(text, 'seat') && !_containsWord(text, 'seats')) return false;
    return _containsAny(text, [
      'select', 'choose', 'choosing', 'pick', 'picking', 'reserve', 'book',
      'change', 'assign', 'want', 'need', 'like', 'selection',
    ]);
  }

  static SeatType? _preferredSeatType(String text) {
    if (_containsWord(text, 'window')) return SeatType.window;
    if (_containsWord(text, 'aisle')) return SeatType.aisle;
    if (_containsWord(text, 'middle')) return SeatType.middle;
    return null;
  }

  static String _seatTypeWord(SeatType type) => switch (type) {
        SeatType.window => 'window',
        SeatType.aisle => 'aisle',
        SeatType.middle => 'middle',
      };

  static Seat _cheapest(List<Seat> seats) =>
      seats.reduce((a, b) => b.priceDelta < a.priceDelta ? b : a);

  static Seat? _nearestAlternative(List<Seat> available, Seat taken) {
    if (available.isEmpty) return null;
    final sameRow = available.where((seat) => seat.row == taken.row).toList();
    if (sameRow.isNotEmpty) return _cheapest(sameRow);
    final sameType = available.where((seat) => seat.type == taken.type).toList();
    if (sameType.isNotEmpty) return _cheapest(sameType);
    return _cheapest(available);
  }

  // ---------------------------------------------------------------------
  // Baggage
  // ---------------------------------------------------------------------

  static VoiceOutcome? _resolveBaggage(String text, List<BaggageOption> options) {
    if (_containsAny(text, [
      'no baggage',
      'no bags',
      'no bag',
      'without',
      'skip',
      'none',
      'no thanks',
      'im good',
      'i am good',
      'continue',
      'finish',
      'that is all',
      'thats all',
    ])) {
      return const SkipBaggageAction();
    }

    if (options.isEmpty) return null;

    final requested = _spokenWeight(text);
    if (requested != null) {
      final option =
          options.where((candidate) => candidate.extraWeightKg == requested).firstOrNull;
      if (option != null) return SelectBaggageAction(option);
    }

    if (_containsAny(text, ['smallest', 'cheapest', 'least'])) {
      return SelectBaggageAction(
        options.reduce((a, b) => b.extraWeightKg < a.extraWeightKg ? b : a),
      );
    }
    if (_containsAny(text, ['largest', 'biggest', 'most', 'maximum'])) {
      return SelectBaggageAction(
        options.reduce((a, b) => b.extraWeightKg > a.extraWeightKg ? b : a),
      );
    }
    if (_containsWord(text, 'middle') && options.length > 2) {
      return SelectBaggageAction(options[options.length ~/ 2]);
    }

    final ordinal = _matchOrdinal(text, options.length);
    if (ordinal != null) return SelectBaggageAction(options[ordinal]);

    return null;
  }

  /// A weight spoken as digits ("20 kg") or as words ("twenty kilos").
  /// Recognizers are inconsistent about which form they return, so both have
  /// to work.
  static num? _spokenWeight(String text) {
    final digits = RegExp(r'\b(\d{1,3})\s*(kilos?|kgs?|kilograms?)?\b').firstMatch(text);
    if (digits != null) return num.parse(digits.group(1)!);

    // Longest phrases first, so "twenty five" is not read as "twenty".
    const words = <String, int>{
      'twenty five': 25,
      'thirty five': 35,
      'five': 5,
      'ten': 10,
      'fifteen': 15,
      'twenty': 20,
      'thirty': 30,
      'forty': 40,
    };
    for (final entry in words.entries) {
      if (text.contains(entry.key)) return entry.value;
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Shared matching helpers
  // ---------------------------------------------------------------------

  /// Returns a zero-based index for "the first one", "number two", "the
  /// last one", and so on, or null when [text] names no position.
  ///
  /// Ordinals are checked before bare numerals on purpose: "the second one"
  /// contains both "second" and "one", and the ordinal is what the passenger
  /// meant.
  static int? _matchOrdinal(String text, int length) {
    const ordinals = <String, int>{
      'first': 0, '1st': 0,
      'second': 1, '2nd': 1,
      'third': 2, '3rd': 2,
      'fourth': 3, '4th': 3,
    };
    const numerals = <String, int>{'one': 0, 'two': 1, 'three': 2, 'four': 3};

    if (_containsAny(text, ['last one', 'the last', 'bottom one'])) return length - 1;

    for (final table in [ordinals, numerals]) {
      for (final entry in table.entries) {
        if (_containsWord(text, entry.key) && entry.value < length) return entry.value;
      }
    }
    return null;
  }

  static String _normalize(String transcript) => transcript
      .toLowerCase()
      .replaceAll(RegExp(r"[^\w\s']"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static bool _matchesAny(String text, Set<String> phrases) {
    if (phrases.contains(text)) return true;
    return phrases.any((phrase) {
      if (phrase.contains(' ')) return text.contains(phrase);
      // "yes please" / "confirm that" still count; mid-sentence "no" in
      // "I have no preference" must not.
      return RegExp('^${RegExp.escape(phrase)}(?:\\s+\\w+){0,3}\$').hasMatch(text);
    });
  }

  static bool _containsAny(String text, List<String> phrases) => phrases.any(
        (phrase) => phrase.contains(' ') ? text.contains(phrase) : _containsWord(text, phrase),
      );

  static bool _containsWord(String text, String word) =>
      RegExp('\\b${RegExp.escape(word)}\\b').hasMatch(text);
}

/// Drops the trailing ".0" that `num` prints for whole values, so the engine
/// says "10 kilos" rather than "ten point zero kilos".
String _number(num value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString();
