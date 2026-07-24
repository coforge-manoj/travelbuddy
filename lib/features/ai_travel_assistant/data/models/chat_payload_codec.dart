import 'dart:convert';

import 'package:ai_travel_assistant/features/ai_travel_assistant/data/models/airport_info_model.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/models/baggage_model.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/models/flight_model.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/models/seat_model.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/agent_escalation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/airport_info.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat.dart';

/// Serializes a rich card's [ChatMessage.payload] (a domain object like a
/// [Flight] or [SeatMap]) to a JSON map for persistence, and rebuilds it on
/// load. Without this, non-Map payloads were dropped on save and came back
/// `null`, so a card restored from history crashed on its `payload!` cast
/// (Flutter's maroon error box). Kept in the data layer so the domain entities
/// stay serialization-agnostic.
class ChatPayloadCodec {
  const ChatPayloadCodec._();

  /// Domain payload → JSON map for storage. Returns `null` when there is
  /// nothing to persist (plain text/error/audio bubbles), or when the payload
  /// isn't the type the card expects.
  static Map<String, dynamic>? encode(ChatMessageType type, Object? payload) {
    if (payload == null) return null;
    switch (type) {
      case ChatMessageType.flightStatusCard:
        return payload is Flight
            ? _flatten(FlightModel.fromEntity(payload).toJson())
            : null;
      case ChatMessageType.seatMapCard:
        return payload is SeatMap
            ? _flatten(SeatMapModel.fromEntity(payload).toJson())
            : null;
      case ChatMessageType.baggageOptionsCard:
        return payload is List<BaggageOption>
            ? {
                'options': payload
                    .map((o) => _flatten(BaggageOptionModel.fromEntity(o).toJson()))
                    .toList(),
              }
            : null;
      case ChatMessageType.baggageSuccessCard:
        return payload is BaggagePurchase
            ? _flatten(BaggagePurchaseModel.fromEntity(payload).toJson())
            : null;
      case ChatMessageType.airportInfoCard:
        return payload is AirportInfo
            ? _flatten(AirportInfoModel.fromEntity(payload).toJson())
            : null;
      case ChatMessageType.agentEscalationCard:
        return payload is EscalationResult
            ? {
                'queuePosition': payload.queuePosition,
                'estimatedWaitMinutes': payload.estimatedWaitMinutes,
              }
            : null;
      case ChatMessageType.text:
      case ChatMessageType.audioMessage:
      case ChatMessageType.error:
        // These carry no structured payload.
        return payload is Map<String, dynamic> ? payload : null;
    }
  }

  /// Stored JSON map → domain payload. Returns `null` (rather than throwing) if
  /// the stored shape is missing or malformed, letting the UI fall back
  /// gracefully instead of crashing.
  static Object? decode(ChatMessageType type, Map<String, dynamic>? json) {
    if (json == null) return null;
    try {
      switch (type) {
        case ChatMessageType.flightStatusCard:
          return FlightModel.fromJson(json).toEntity();
        case ChatMessageType.seatMapCard:
          return SeatMapModel.fromJson(json).toEntity();
        case ChatMessageType.baggageOptionsCard:
          final raw = json['options'];
          if (raw is! List) return null;
          return raw.map((o) {
            final map = Map<String, dynamic>.from(o as Map);
            return BaggageOptionModel.fromJson(map).toEntity();
          }).toList();
        case ChatMessageType.baggageSuccessCard:
          return BaggagePurchaseModel.fromJson(json).toEntity();
        case ChatMessageType.airportInfoCard:
          return AirportInfoModel.fromJson(json).toEntity();
        case ChatMessageType.agentEscalationCard:
          return EscalationResult(
            queuePosition: (json['queuePosition'] as num?)?.toInt() ?? 0,
            estimatedWaitMinutes:
                (json['estimatedWaitMinutes'] as num?)?.toInt() ?? 0,
          );
        case ChatMessageType.text:
        case ChatMessageType.audioMessage:
        case ChatMessageType.error:
          return null;
      }
    } catch (_) {
      // Legacy or malformed record — degrade to a null payload; the card
      // widget renders an "unavailable" fallback instead of the error box.
      return null;
    }
  }

  /// These models use json_serializable's default `explicitToJson: false`, so
  /// `toJson()` leaves nested models as objects rather than maps (it relies on
  /// a later `jsonEncode`). A JSON round-trip forces the whole tree down to
  /// primitive maps/lists — the shape both Hive and the round-tripping
  /// `fromJson` require.
  static Map<String, dynamic> _flatten(Map<String, dynamic> json) =>
      jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
}
