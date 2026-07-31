import 'package:ai_travel_assistant/features/ai_travel_assistant/data/datasource/voice_action_remote_datasource.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_action_resolver.dart';

/// Interprets a spoken transcript against the card currently on screen.
abstract interface class VoiceActionParser {
  Future<VoiceOutcome?> resolve({
    required String transcript,
    required VoiceContext context,
    VoiceAction? pendingConfirmation,
  });
}

/// Instant closed-set matching — same behaviour the chat used before the
/// model-backed parser existed.
class RuleBasedVoiceActionParser implements VoiceActionParser {
  const RuleBasedVoiceActionParser();

  @override
  Future<VoiceOutcome?> resolve({
    required String transcript,
    required VoiceContext context,
    VoiceAction? pendingConfirmation,
  }) async {
    return VoiceActionResolver.resolve(
      transcript: transcript,
      context: context,
      pendingConfirmation: pendingConfirmation,
    );
  }
}

/// Rules first for speed and payment safety; LLM only when the transcript is
/// still unrecognized and a card (or pending confirmation) is active.
///
/// The model never executes anything directly — its guess is rebound onto the
/// live catalog, so an invented offer/seat/option id is discarded.
class HybridVoiceActionParser implements VoiceActionParser {
  HybridVoiceActionParser({
    required VoiceActionRemoteDataSource remote,
    this.timeout = const Duration(milliseconds: 900),
    VoiceActionParser rules = const RuleBasedVoiceActionParser(),
  })  : _remote = remote,
        _rules = rules;

  final VoiceActionRemoteDataSource _remote;
  final VoiceActionParser _rules;
  final Duration timeout;

  @override
  Future<VoiceOutcome?> resolve({
    required String transcript,
    required VoiceContext context,
    VoiceAction? pendingConfirmation,
  }) async {
    final ruled = await _rules.resolve(
      transcript: transcript,
      context: context,
      pendingConfirmation: pendingConfirmation,
    );
    if (ruled != null) return ruled;

    final needsModel =
        pendingConfirmation != null || context.kind != VoiceContextKind.none;
    if (!needsModel) return null;

    try {
      final guess = await _remote
          .detect(
            transcript: transcript,
            context: context,
            pendingConfirmation: pendingConfirmation,
          )
          .timeout(timeout);
      if (guess == null) return null;
      return VoiceActionBinder.bind(
        guess: guess,
        context: context,
        pendingConfirmation: pendingConfirmation,
      );
    } catch (_) {
      // A slow or broken model costs variety of phrasing coverage, not the
      // turn — fall through to normal intent classification.
      return null;
    }
  }
}

/// Maps a model guess onto real catalog entities. Anything that does not
/// resolve to an on-screen option becomes `null` (or a clarifying question).
class VoiceActionBinder {
  const VoiceActionBinder._();

  static VoiceOutcome? bind({
    required VoiceActionGuess guess,
    required VoiceContext context,
    VoiceAction? pendingConfirmation,
  }) {
    switch (guess.action) {
      case 'confirm':
        return pendingConfirmation == null ? null : const ConfirmPendingAction();
      case 'cancel':
        return const CancelAction();
      case 'none':
        return null;
      case 'ambiguous':
        return _ambiguous(guess, context);
      case 'select_offer':
        return _selectOffer(guess.offerId, context);
      case 'select_seat':
        return _selectSeat(guess.seatNumber, context);
      case 'skip_seat':
        return context.kind == VoiceContextKind.seatMap ? const SkipSeatAction() : null;
      case 'select_baggage':
        return _selectBaggage(guess.optionId, context);
      case 'skip_baggage':
        return context.kind == VoiceContextKind.baggageOptions
            ? const SkipBaggageAction()
            : null;
      default:
        return null;
    }
  }

  static VoiceOutcome? _selectOffer(String? offerId, VoiceContext context) {
    if (context.kind != VoiceContextKind.flightOffers || offerId == null) return null;
    final offers = context.payload as List<FlightOffer>;
    final offer = offers.where((candidate) => candidate.id == offerId).firstOrNull;
    return offer == null ? null : SelectOfferAction(offer);
  }

  static VoiceOutcome? _selectSeat(String? seatNumber, VoiceContext context) {
    if (context.kind != VoiceContextKind.seatMap || seatNumber == null) return null;
    final seatMap = context.payload as SeatMap;
    final requested = seatNumber.toUpperCase().replaceAll(' ', '');
    final seat = seatMap.seats
        .where((candidate) => candidate.seatNumber.toUpperCase() == requested)
        .firstOrNull;
    if (seat == null) {
      return VoiceAmbiguity(
        "I don't see seat $requested on this flight. Which seat would you like?",
      );
    }
    if (!seat.isAvailable) {
      return VoiceAmbiguity(
        'Seat $requested is taken. Which other seat would you like?',
      );
    }
    return SelectSeatAction(seat, currency: seatMap.currency);
  }

  static VoiceOutcome? _selectBaggage(String? optionId, VoiceContext context) {
    if (context.kind != VoiceContextKind.baggageOptions || optionId == null) return null;
    final options = context.payload as List<BaggageOption>;
    final option = options.where((candidate) => candidate.id == optionId).firstOrNull;
    return option == null ? null : SelectBaggageAction(option);
  }

  static VoiceOutcome? _ambiguous(VoiceActionGuess guess, VoiceContext context) {
    final question = guess.question?.trim();
    if (question == null || question.isEmpty) return null;

    VoiceAction? suggestion;
    final suggestionAction = guess.suggestionAction;
    final suggestionId = guess.suggestionId;
    if (suggestionAction != null && suggestionId != null) {
      final bound = switch (suggestionAction) {
        'select_offer' => _selectOffer(suggestionId, context),
        'select_seat' => _selectSeat(suggestionId, context),
        'select_baggage' => _selectBaggage(suggestionId, context),
        _ => null,
      };
      // Helpers may return VoiceAmbiguity — only concrete actions are proposable.
      if (bound is VoiceAction) suggestion = bound;
    }

    return VoiceAmbiguity(question, suggestion: suggestion);
  }
}
