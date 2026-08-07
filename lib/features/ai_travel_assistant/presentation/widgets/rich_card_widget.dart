import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/action_summary.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/agent_escalation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/airport_info.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/basket.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/boarding_pass.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking_confirmation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking_summary.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/cabin_seat_map.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/cancellation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/extras_catalogue.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_selection.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat_confirmation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/upgrade_quote.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/chat_viewmodel.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/action_summary_card.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/airport/airport_info_card.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/baggage/baggage_options_card.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/baggage/baggage_success_card.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/flight/basket_card.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/flight/boarding_pass_card.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/flight/booking_confirmation_card.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/flight/booking_confirmed_card.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/flight/cancellation_card.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/flight/extras_list_card.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/flight/flight_offers_card.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/flight/flight_selected_card.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/flight/flight_status_card.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/flight/upgrade_quote_card.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/seat_map/cabin_seat_map_card.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/seat_map/seat_confirmed_card.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/seat_map/seat_map_card.dart';

/// Dispatches a rich [ChatMessage] to its dedicated card widget based on
/// [ChatMessage.type]. This is the single seam later phases plug into —
/// adding a new card type only ever means adding a case here, never
/// touching [ChatPage]. The escalation card remains a lightweight built-in
/// summary since a dedicated live-agent hand-off UI is out of this
/// module's scope.
class RichCardWidget extends ConsumerWidget {
  const RichCardWidget({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (message.type) {
      ChatMessageType.flightStatusCard => FlightStatusCard(flight: message.payload! as Flight),
      ChatMessageType.flightOffersCard =>
        FlightOffersCard(offers: message.payload! as List<FlightOffer>),
      ChatMessageType.flightSelectedCard =>
        FlightSelectedCard(selection: message.payload! as FlightSelection),
      ChatMessageType.bookingConfirmationCard =>
        BookingConfirmationCard(summary: message.payload! as BookingSummary),
      ChatMessageType.seatMapCard => SeatMapCard(seatMap: message.payload! as SeatMap),
      ChatMessageType.baggageOptionsCard =>
        BaggageOptionsCard(options: message.payload! as List<BaggageOption>),
      ChatMessageType.baggageSuccessCard =>
        BaggageSuccessCard(purchase: message.payload! as BaggagePurchase),
      ChatMessageType.airportInfoCard => AirportInfoCard(info: message.payload! as AirportInfo),
      ChatMessageType.agentEscalationCard => _AgentEscalationCard(
          escalation: message.payload as EscalationResult?,
          text: message.text,
        ),
      ChatMessageType.actionSummaryCard =>
        ActionSummaryCard(summary: message.payload! as ActionSummary),

      // TravelBuddy journey cards. The interactive ones send their tap back
      // through `/chat` as a sentence, so a tap and a typed message reach
      // the backend the same way — see [ChatViewModel].
      ChatMessageType.basketCard => BasketCard(basket: message.payload! as Basket),
      ChatMessageType.extrasListCard => ExtrasListCard(
          catalogue: message.payload! as ExtrasCatalogue,
          onAdd: ref.read(chatViewModelProvider.notifier).addExtra,
        ),
      ChatMessageType.bookingConfirmedCard => BookingConfirmedCard(
          booking: message.payload! as BookingConfirmation,
        ),
      ChatMessageType.cabinSeatMapCard => CabinSeatMapCard(
          seatMap: message.payload! as CabinSeatMap,
          onSeatSelected: ref.read(chatViewModelProvider.notifier).selectSeat,
        ),
      ChatMessageType.seatConfirmedCard =>
        SeatConfirmedCard(confirmation: message.payload! as SeatConfirmation),
      ChatMessageType.boardingPassCard =>
        BoardingPassCard(pass: message.payload! as BoardingPass),
      ChatMessageType.upgradeQuoteCard =>
        UpgradeQuoteCard(quote: message.payload! as UpgradeQuote),
      ChatMessageType.cancellationCard =>
        CancellationCard(cancellation: message.payload! as Cancellation),

      ChatMessageType.text || ChatMessageType.error =>
        _AgentEscalationCard(escalation: null, text: message.text),
    };
  }
}

/// Small built-in summary for a human-escalation handoff — queue position
/// and estimated wait, once the backend confirms the escalation.
class _AgentEscalationCard extends StatelessWidget {
  const _AgentEscalationCard({required this.escalation, required this.text});

  final EscalationResult? escalation;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.support_agent, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text('Agent escalation', style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 8),
            Text(text, style: Theme.of(context).textTheme.bodyMedium),
            if (escalation != null) ...[
              const SizedBox(height: 4),
              Text(
                'Queue position ${escalation!.queuePosition} · '
                '~${escalation!.estimatedWaitMinutes} min wait',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
