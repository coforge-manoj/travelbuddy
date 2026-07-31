import 'package:dio/dio.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_action_resolver.dart';

/// Structured guess from the model. IDs are still validated against the live
/// card catalog before anything is executed — the model never invents a
/// bookable target that isn't on screen.
class VoiceActionGuess {
  const VoiceActionGuess({
    required this.action,
    this.offerId,
    this.seatNumber,
    this.optionId,
    this.question,
    this.suggestionAction,
    this.suggestionId,
  });

  factory VoiceActionGuess.fromJson(Map<String, dynamic> json) {
    String? asString(Object? value) => value is String && value.trim().isNotEmpty
        ? value.trim()
        : null;

    return VoiceActionGuess(
      action: (asString(json['action']) ?? 'none').toLowerCase(),
      offerId: asString(json['offer_id']),
      seatNumber: asString(json['seat_number']),
      optionId: asString(json['option_id']),
      question: asString(json['question']),
      suggestionAction: asString(json['suggestion_action'])?.toLowerCase(),
      suggestionId: asString(json['suggestion_id']),
    );
  }

  final String action;
  final String? offerId;
  final String? seatNumber;
  final String? optionId;
  final String? question;
  final String? suggestionAction;
  final String? suggestionId;
}

abstract interface class VoiceActionRemoteDataSource {
  Future<VoiceActionGuess?> detect({
    required String transcript,
    required VoiceContext context,
    VoiceAction? pendingConfirmation,
  });
}

const _voiceActionInstructions = '''
You interpret a passenger's spoken command against the travel card on screen.
Return ONLY a JSON object. Never invent ids — only use ids listed in "catalog".

Actions:
- select_offer: passenger chose a flight. Set offer_id.
- select_seat: passenger chose a seat. Set seat_number.
- skip_seat: they do not want to pick a seat.
- select_baggage: passenger chose a baggage option. Set option_id.
- skip_baggage: no extra bags / continue without baggage.
- confirm: they are affirming a pending confirmation.
- cancel: they are rejecting a pending confirmation or backing out.
- ambiguous: not sure which option. Set question, and optionally
  suggestion_action + suggestion_id for a yes/no follow-up.
- none: utterance is unrelated to this card.

Prefer a concrete selection when the passenger clearly named one option.
''';

/// Provider-agnostic voice-action call on the same `/chat` surface as phrasing.
class LlmVoiceActionRemoteDataSource implements VoiceActionRemoteDataSource {
  LlmVoiceActionRemoteDataSource(this._dio, {this.model = 'gpt-4.1-mini'});

  final Dio _dio;
  final String model;

  @override
  Future<VoiceActionGuess?> detect({
    required String transcript,
    required VoiceContext context,
    VoiceAction? pendingConfirmation,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/chat/message',
      data: {
        'model': model,
        'mode': 'voice_action',
        'instructions': _voiceActionInstructions,
        'transcript': transcript,
        'pending_confirmation': pendingConfirmation != null,
        'context_kind': context.kind.name,
        'catalog': _catalog(context),
      },
    );

    final data = response.data;
    if (data == null) return null;

    final payload = data['action'] is Map<String, dynamic>
        ? data['action'] as Map<String, dynamic>
        : data;
    return VoiceActionGuess.fromJson(payload);
  }

  static Map<String, dynamic> _catalog(VoiceContext context) {
    return switch (context.kind) {
      VoiceContextKind.flightOffers => {
          'offers': [
            for (final offer in context.payload as List<FlightOffer>)
              {
                'id': offer.id,
                'airline': offer.airline,
                'flight_number': offer.flightNumber,
                'departure': offer.departureTime.toIso8601String(),
                'price': offer.price,
                'currency': offer.currency,
              },
          ],
        },
      VoiceContextKind.seatMap => {
          'flight_number': (context.payload as SeatMap).flightNumber,
          'available_seats': [
            for (final seat in (context.payload as SeatMap).seats.where((s) => s.isAvailable))
              {
                'seat_number': seat.seatNumber,
                'type': seat.type.name,
                'price_delta': seat.priceDelta,
              },
          ],
        },
      VoiceContextKind.baggageOptions => {
          'options': [
            for (final option in context.payload as List<BaggageOption>)
              {
                'id': option.id,
                'extra_weight_kg': option.extraWeightKg,
                'price': option.price,
                'currency': option.currency,
              },
          ],
        },
      VoiceContextKind.none => const <String, dynamic>{},
    };
  }
}

/// Offline stand-in that recovers natural phrasing the rule parser misses by
/// stripping filler and re-running the closed-set matcher.
class MockVoiceActionRemoteDataSource implements VoiceActionRemoteDataSource {
  MockVoiceActionRemoteDataSource({
    this.latency = const Duration(milliseconds: 120),
  });

  final Duration latency;

  static const _fillers = <String>[
    'i think',
    'i reckon',
    'i guess',
    'i would like',
    'i would love',
    "i'd like",
    "i'd love",
    'i want',
    'i need',
    'can you',
    'could you',
    'would you',
    'please',
    'for me',
    'go ahead and',
    'just',
    'maybe',
    'perhaps',
    'actually',
    'yeah',
    'yes',
    'um',
    'uh',
  ];

  @override
  Future<VoiceActionGuess?> detect({
    required String transcript,
    required VoiceContext context,
    VoiceAction? pendingConfirmation,
  }) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);

    final cleaned = _stripFillers(transcript);
    if (cleaned.isEmpty) return null;

    if (pendingConfirmation != null) {
      final outcome = VoiceActionResolver.resolve(
        transcript: cleaned,
        context: const VoiceContext.none(),
        pendingConfirmation: pendingConfirmation,
      );
      return _fromOutcome(outcome);
    }

    final outcome = VoiceActionResolver.resolve(
      transcript: cleaned,
      context: context,
      pendingConfirmation: null,
    );
    if (outcome != null) return _fromOutcome(outcome);

    // Soft synonyms the rule set does not cover verbatim.
    final soft = _softMatch(cleaned, context);
    return soft == null ? null : _fromOutcome(soft);
  }

  static String _stripFillers(String transcript) {
    var text = transcript.toLowerCase().replaceAll(RegExp(r"[^\w\s']"), ' ');
    for (final filler in _fillers) {
      text = text.replaceAll(filler, ' ');
    }
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static VoiceOutcome? _softMatch(String text, VoiceContext context) {
    return switch (context.kind) {
      VoiceContextKind.flightOffers => _softOffer(text, context.payload as List<FlightOffer>),
      VoiceContextKind.seatMap => _softSeat(text, context.payload as SeatMap),
      VoiceContextKind.baggageOptions =>
        _softBaggage(text, context.payload as List<BaggageOption>),
      VoiceContextKind.none => null,
    };
  }

  static VoiceOutcome? _softOffer(String text, List<FlightOffer> offers) {
    if (offers.isEmpty) return null;
    if (_hasAny(text, ['morning', 'early bird', 'first thing'])) {
      return SelectOfferAction(
        offers.reduce((a, b) => b.departureTime.isBefore(a.departureTime) ? b : a),
      );
    }
    if (_hasAny(text, ['evening', 'night', 'late one'])) {
      return SelectOfferAction(
        offers.reduce((a, b) => b.departureTime.isAfter(a.departureTime) ? b : a),
      );
    }
    if (_hasAny(text, ['budget', 'inexpensive', 'affordable', 'cheap flight', 'cheap one'])) {
      return SelectOfferAction(offers.reduce((a, b) => b.price < a.price ? b : a));
    }
    return null;
  }

  static VoiceOutcome? _softSeat(String text, SeatMap seatMap) {
    if (_hasAny(text, ['dont bother', 'do not bother', 'keep my seat', 'leave it'])) {
      return const SkipSeatAction();
    }
    if (_hasAny(text, ['by the window', 'near the window', 'window side'])) {
      return VoiceActionResolver.resolve(
        transcript: 'window',
        context: VoiceContext.seatMap(seatMap),
      );
    }
    if (_hasAny(text, ['by the aisle', 'near the aisle', 'aisle side'])) {
      return VoiceActionResolver.resolve(
        transcript: 'aisle',
        context: VoiceContext.seatMap(seatMap),
      );
    }
    return null;
  }

  static VoiceOutcome? _softBaggage(String text, List<BaggageOption> options) {
    if (_hasAny(text, [
      'no luggage',
      'no extra luggage',
      'without bags',
      'without luggage',
      'dont need bags',
      'do not need bags',
    ])) {
      return const SkipBaggageAction();
    }
    if (options.isEmpty) return null;
    if (_hasAny(text, ['extra luggage', 'extra bag', 'checked bag', 'more weight'])) {
      return SelectBaggageAction(
        options.reduce((a, b) => b.extraWeightKg < a.extraWeightKg ? b : a),
      );
    }
    return null;
  }

  static bool _hasAny(String text, List<String> phrases) =>
      phrases.any((phrase) => text.contains(phrase));

  static VoiceActionGuess? _fromOutcome(VoiceOutcome? outcome) {
    if (outcome == null) return null;
    return switch (outcome) {
      SelectOfferAction(:final offer) => VoiceActionGuess(
          action: 'select_offer',
          offerId: offer.id,
        ),
      SelectSeatAction(:final seat) => VoiceActionGuess(
          action: 'select_seat',
          seatNumber: seat.seatNumber,
        ),
      SkipSeatAction() => const VoiceActionGuess(action: 'skip_seat'),
      SelectBaggageAction(:final option) => VoiceActionGuess(
          action: 'select_baggage',
          optionId: option.id,
        ),
      SkipBaggageAction() => const VoiceActionGuess(action: 'skip_baggage'),
      ConfirmPendingAction() => const VoiceActionGuess(action: 'confirm'),
      CancelAction() => const VoiceActionGuess(action: 'cancel'),
      VoiceAmbiguity(:final question, :final suggestion) => VoiceActionGuess(
          action: 'ambiguous',
          question: question,
          suggestionAction: switch (suggestion) {
            SelectSeatAction() => 'select_seat',
            SelectOfferAction() => 'select_offer',
            SelectBaggageAction() => 'select_baggage',
            _ => null,
          },
          suggestionId: switch (suggestion) {
            SelectSeatAction(:final seat) => seat.seatNumber,
            SelectOfferAction(:final offer) => offer.id,
            SelectBaggageAction(:final option) => option.id,
            _ => null,
          },
        ),
    };
  }
}
