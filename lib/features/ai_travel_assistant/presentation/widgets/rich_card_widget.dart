import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/agent_escalation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/airport_info.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/audio_message_bubble.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/airport/airport_info_card.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/baggage/baggage_options_card.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/baggage/baggage_success_card.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/flight/flight_status_card.dart';
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
    // Payloads are typed-checked rather than force-unwrapped: a message
    // restored from history whose payload failed to round-trip comes back
    // null, and a hard cast there would throw and paint Flutter's maroon
    // error box over the whole bubble. On a mismatch we degrade to a small
    // "card unavailable" note instead.
    final payload = message.payload;
    switch (message.type) {
      case ChatMessageType.audioMessage:
        final audioPath = message.audioPath;
        if (audioPath != null) {
          return AudioMessageBubble(
            audioPath: audioPath,
            duration: message.audioDuration,
          );
        }
      case ChatMessageType.flightStatusCard:
        if (payload is Flight) return FlightStatusCard(flight: payload);
      case ChatMessageType.seatMapCard:
        if (payload is SeatMap) return SeatMapCard(seatMap: payload);
      case ChatMessageType.baggageOptionsCard:
        if (payload is List<BaggageOption>) {
          return BaggageOptionsCard(options: payload);
        }
      case ChatMessageType.baggageSuccessCard:
        if (payload is BaggagePurchase) {
          return BaggageSuccessCard(purchase: payload);
        }
      case ChatMessageType.airportInfoCard:
        if (payload is AirportInfo) return AirportInfoCard(info: payload);
      case ChatMessageType.agentEscalationCard:
        return _AgentEscalationCard(
          escalation: payload is EscalationResult ? payload : null,
          text: message.text,
        );
      case ChatMessageType.text:
      case ChatMessageType.error:
        return _AgentEscalationCard(escalation: null, text: message.text);
    }
    return _UnavailableCard(text: message.text);
  }
}

/// Shown when a rich card's structured payload is missing — e.g. an older
/// history record saved before payloads were persisted. Keeps the thread
/// readable instead of crashing the bubble.
class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(14),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 18, color: scheme.outline),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text.isNotEmpty ? text : 'This card is no longer available.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.outline),
              ),
            ),
          ],
        ),
      ),
    );
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
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
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
                Text('Agent escalation',
                    style: Theme.of(context).textTheme.labelLarge,),
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
