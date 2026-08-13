import 'package:equatable/equatable.dart';

enum ChatRole { user, assistant, system }

/// Distinguishes plain text bubbles from rich, interactive cards rendered
/// inline in the chat (seat map, baggage options, flight status, etc.).
enum ChatMessageType {
  text,
  flightStatusCard,
  flightOffersCard,
  flightSelectedCard,
  bookingConfirmationCard,
  seatMapCard,
  baggageOptionsCard,
  baggageSuccessCard,
  airportInfoCard,
  agentEscalationCard,
  actionSummaryCard,

  /// TravelBuddy `/chat` card types. These carry the conversational journey
  /// — search → select → extras → book → seat → check-in → upgrade → cancel
  /// — and are mapped straight from the `cards` array on a chat response.
  basketCard,
  extrasListCard,
  bookingConfirmedCard,
  cabinSeatMapCard,
  seatConfirmedCard,
  boardingPassCard,
  upgradeQuoteCard,
  cancellationCard,
  travelHistoryCard,

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
    this.spokenText,
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

  /// What was actually said aloud for this message, when that differs from
  /// [text].
  ///
  /// A card's [text] is only a caption — the substance lives in [payload] and
  /// gets described by `CardSpeechTextBuilder`, and a spoken line is also
  /// summarized for the ear, so it is usually shorter and worded differently
  /// from what is on screen. Keeping it here means the transcript can show what
  /// the passenger heard rather than a bubble that silently disagrees with it.
  ///
  /// `null` when nothing was spoken, or when the spoken words were just [text].
  final String? spokenText;

  ChatMessage copyWith({
    String? text,
    Object? payload,
    bool? isStreaming,
    String? spokenText,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      type: type,
      timestamp: timestamp,
      text: text ?? this.text,
      payload: payload ?? this.payload,
      isStreaming: isStreaming ?? this.isStreaming,
      spokenText: spokenText ?? this.spokenText,
    );
  }

  @override
  List<Object?> get props =>
      [id, role, type, timestamp, text, payload, isStreaming, spokenText];
}
