import 'package:equatable/equatable.dart';

enum ChatRole { user, assistant, system }

/// Distinguishes plain text bubbles from rich, interactive cards rendered
/// inline in the chat (seat map, baggage options, flight status, etc.).
enum ChatMessageType {
  text,
  flightStatusCard,
  flightOffersCard,
  bookingConfirmationCard,
  seatMapCard,
  baggageOptionsCard,
  baggageSuccessCard,
  airportInfoCard,
  agentEscalationCard,
  error,
}

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.type,
    required this.timestamp,
    this.text = '',
    this.payload,
    this.isStreaming = false,
    this.isInteractive = true,
  });

  final String id;
  final ChatRole role;
  final ChatMessageType type;
  final DateTime timestamp;

  /// Markdown-formatted text content (used for [ChatMessageType.text] and
  /// as a caption for rich cards).
  final String text;

  /// Structured data backing a rich card (e.g. a Flight, SeatMap, or list of
  /// BaggageOptions). Kept as `Object?` here so the domain layer stays
  /// UI-agnostic; the presentation layer casts based on [type].
  final Object? payload;

  final bool isStreaming;

  /// Whether the passenger can still change a choice on this card. Set to
  /// false once the selection is confirmed so scrollback cannot re-pick a
  /// flight, seat, or baggage option that has already been committed.
  final bool isInteractive;

  ChatMessage copyWith({
    String? text,
    Object? payload,
    bool? isStreaming,
    bool? isInteractive,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      type: type,
      timestamp: timestamp,
      text: text ?? this.text,
      payload: payload ?? this.payload,
      isStreaming: isStreaming ?? this.isStreaming,
      isInteractive: isInteractive ?? this.isInteractive,
    );
  }

  @override
  List<Object?> get props =>
      [id, role, type, timestamp, text, payload, isStreaming, isInteractive];
}
