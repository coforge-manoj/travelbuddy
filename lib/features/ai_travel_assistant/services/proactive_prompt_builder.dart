import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/display_text_formatter.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/speech_text_formatter.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_action_resolver.dart';

/// One silence follow-up: what to say, plus the action a following "yes"
/// should run. A `null` [suggestedAction] makes the nudge purely
/// conversational, so answering it can never commit the passenger to
/// anything.
class ProactivePrompt {
  const ProactivePrompt(this.text, {this.spokenText, this.suggestedAction});

  /// On-screen wording (readable times and prices).
  final String text;

  /// Optional TTS wording when it should differ from [text].
  final String? spokenText;

  final VoiceAction? suggestedAction;

  String get speechText => spokenText ?? text;
}

/// Builds the nudges the assistant offers when a passenger goes quiet in
/// front of a choice.
///
/// Split out of `ChatViewModel` for the same reason as [VoiceSummaryBuilder]:
/// deciding what to say next is a pure function of the card on screen and how
/// many nudges have already been spoken, so it is worth testing without a
/// view model, timers, or a speech engine.
class ProactivePromptBuilder {
  const ProactivePromptBuilder._();

  /// Whether [kind] still has a nudge left after [step] of them have been
  /// spoken. Flight offers walk a short ladder; seat and baggage stay at a
  /// single nudge so a quiet passenger is never nagged towards a purchase.
  static bool hasMoreSteps(VoiceContextKind kind, int step) {
    return switch (kind) {
      VoiceContextKind.flightOffers => step < 3,
      VoiceContextKind.seatMap || VoiceContextKind.baggageOptions => step < 1,
      VoiceContextKind.none => false,
    };
  }

  /// The nudge for [step], or `null` when there is nothing useful left to
  /// offer. Seat nudges deliberately prefer a free seat so a nudge never
  /// proposes a charge the passenger did not ask about.
  ///
  /// Flight-offer silence ladder:
  /// 0 → offer the cheapest option
  /// 1 → ask about another date
  /// 2 → offer any other help
  static ProactivePrompt? build(VoiceContext context, int step) {
    switch (context.kind) {
      case VoiceContextKind.flightOffers:
        final offers = context.payload! as List<FlightOffer>;
        if (offers.isEmpty) return null;
        switch (step) {
          case 0:
            final cheapest = offers.reduce((a, b) => b.price < a.price ? b : a);
            return ProactivePrompt(
              'Whenever you are ready — the cheapest option is ${cheapest.airline} at '
              '${DisplayTextFormatter.price(cheapest.price, cheapest.currency)}. '
              'Would you like me to book that for you?',
              spokenText: 'Whenever you are ready — the cheapest option is ${cheapest.airline} at '
                  '${SpeechTextFormatter.price(cheapest.price, cheapest.currency)}. '
                  'Would you like me to book that for you?',
              suggestedAction: SelectOfferAction(cheapest),
            );
          case 1:
            return const ProactivePrompt(
              'If you want, I can look for flight availability on other days.',
            );
          case 2:
            return const ProactivePrompt(
              'Is there anything else I can help you with today?',
            );
          default:
            return null;
        }

      case VoiceContextKind.seatMap:
        if (step > 0) return null;
        final seatMap = context.payload! as SeatMap;
        final free = seatMap.seats
            .where((seat) => seat.isAvailable && seat.priceDelta == 0)
            .toList();
        final window = free.where((seat) => seat.type == SeatType.window).toList();
        final candidate = window.isNotEmpty ? window.first : (free.isNotEmpty ? free.first : null);
        if (candidate == null) return null;
        final descriptor = candidate.type == SeatType.window ? 'a window seat' : 'a seat';
        return ProactivePrompt(
          'Shall I pick $descriptor for you?',
          suggestedAction: SelectSeatAction(candidate, currency: seatMap.currency),
        );

      case VoiceContextKind.baggageOptions:
        if (step > 0) return null;
        final options = context.payload! as List<BaggageOption>;
        if (options.isEmpty) return null;
        return const ProactivePrompt(
          'Would you like to add bags, or continue without?',
          suggestedAction: SkipBaggageAction(),
        );

      case VoiceContextKind.none:
        return null;
    }
  }
}
