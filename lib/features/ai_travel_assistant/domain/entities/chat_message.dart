import 'package:equatable/equatable.dart';

enum ChatRole { user, assistant, system }

/// Distinguishes plain text bubbles from rich, interactive cards rendered
/// inline in the chat (seat map, baggage options, flight status, etc.).
enum ChatMessageType {
  text,
  audioMessage,
  flightStatusCard,
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
    this.audioPath,
    this.audioDuration,
  });

  final String id;
  final ChatRole role;
  final ChatMessageType type;
  final DateTime timestamp;

  /// For [ChatMessageType.audioMessage]: local file path of the recorded voice
  /// message (voice mode 2), and its length. Null for every other type.
  final String? audioPath;
  final Duration? audioDuration;

  /// Markdown-formatted text content (used for [ChatMessageType.text] and
  /// as a caption for rich cards).
  final String text;

  /// Structured data backing a rich card (e.g. a Flight, SeatMap, or list of
  /// BaggageOptions). Kept as `Object?` here so the domain layer stays
  /// UI-agnostic; the presentation layer casts based on [type].
  final Object? payload;

  final bool isStreaming;

  ChatMessage copyWith({
    String? text,
    Object? payload,
    bool? isStreaming,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      type: type,
      timestamp: timestamp,
      text: text ?? this.text,
      payload: payload ?? this.payload,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  @override
  List<Object?> get props => [
        id,
        role,
        type,
        timestamp,
        text,
        payload,
        isStreaming,
        audioPath,
        audioDuration,
      ];
}
