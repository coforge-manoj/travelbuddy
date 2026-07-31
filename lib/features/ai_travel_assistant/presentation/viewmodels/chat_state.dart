import 'package:equatable/equatable.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_action_resolver.dart';

enum ChatStatus {
  idle,
  loadingHistory,
  sendingMessage,
  listening,

  /// The reply is written and committed, but its audio is still being worded
  /// and synthesized. Held apart from [speaking] so the UI keeps showing a
  /// loader until there is genuinely something to hear — announcing "speaking"
  /// over silence reads as a broken app.
  preparingSpeech,
  speaking,
  error,
}

/// How [ChatViewModel.startVoiceInput] should treat the transcript.
enum VoiceInputMode {
  /// Hands the final transcript to the assistant immediately (talkback orb).
  conversational,

  /// Fills the typing composer so the passenger can edit before sending.
  dictate,
}

class ChatState extends Equatable {
  const ChatState({
    this.messages = const [],
    this.status = ChatStatus.idle,
    this.errorMessage,
    this.isVoiceOutputEnabled = true,
    this.isSoundEnabled = true,
    this.pendingBooking,
    this.pendingSeatNumber,
    this.pendingBaggagePurchases = const [],
    this.confirmedOfferId,
    this.confirmedSeatNumber,
    this.confirmedBaggageOptionIds = const [],
    this.voiceContext = const VoiceContext.none(),
    this.pendingConfirmation,
    this.pendingConfirmationExpiresAt,
    this.highlightedOfferId,
    this.highlightedSeatNumber,
    this.highlightedBaggageOptionId,
    this.proactivePromptStep = 0,
    this.dictationDraft = '',
    this.dictationRevision = 0,
  });

  final List<ChatMessage> messages;
  final ChatStatus status;
  final String? errorMessage;

  /// Whether assistant replies are read aloud. On by default; the choice
  /// is persisted across sessions.
  final bool isVoiceOutputEnabled;

  /// Whether the short interface cues play. Kept separate from
  /// [isVoiceOutputEnabled] so muting the voice still leaves the feedback
  /// sounds that tell you the mic opened or results arrived.
  final bool isSoundEnabled;

  /// The booking created by [ChatViewModel.selectFlightOffer] while the
  /// guided seat/baggage flow is in progress. Cleared once
  /// [ChatViewModel.finishBooking] renders the final itinerary card.
  final Booking? pendingBooking;
  final String? pendingSeatNumber;
  final List<BaggagePurchase> pendingBaggagePurchases;

  /// Offer the passenger already booked — used so locked flight cards can
  /// show which row was chosen after ListView recycles the widget.
  final String? confirmedOfferId;

  /// Seat confirmed on the map (null when the passenger skipped).
  final String? confirmedSeatNumber;

  /// Baggage option ids already purchased in this session's flow.
  final List<String> confirmedBaggageOptionIds;

  /// What the passenger is currently being asked to choose from, so a spoken
  /// "the cheapest one" is interpreted against the card actually on screen.
  final VoiceContext voiceContext;

  /// An action that has been read back and is waiting for an explicit spoken
  /// yes. Anything that books or charges lands here first rather than
  /// executing straight off a transcript.
  final VoiceAction? pendingConfirmation;

  /// When [pendingConfirmation] stops being valid. Without an expiry, a
  /// stray "yes" minutes later could trigger a purchase the passenger has
  /// long since forgotten about.
  final DateTime? pendingConfirmationExpiresAt;

  /// Offer highlighted on the flight-offers card while a spoken/typed
  /// confirmation is armed (or while booking that offer).
  final String? highlightedOfferId;

  /// Seat highlighted on the seat-map card while confirmation is armed.
  final String? highlightedSeatNumber;

  /// Baggage option highlighted while confirmation is armed.
  final String? highlightedBaggageOptionId;

  /// How many silence follow-ups have already been spoken for the current
  /// interactive step. Flight offers use a short ladder (cheapest → other
  /// date → anything else); seat and baggage stay at a single nudge.
  final int proactivePromptStep;

  /// Live text from composer-mic dictation. The composer mirrors this into
  /// its text field.
  final String dictationDraft;

  /// Bumped whenever [dictationDraft] is written so the composer can apply
  /// the same words again after the passenger clears the field.
  final int dictationRevision;

  bool get isBusy => status == ChatStatus.sendingMessage || status == ChatStatus.loadingHistory;

  bool get isSpeaking => status == ChatStatus.speaking;

  /// True while a turn is on its way to the speaker, whether or not it has
  /// started making a sound yet.
  bool get isNarrating =>
      status == ChatStatus.speaking || status == ChatStatus.preparingSpeech;

  /// Whether the passenger is mid-way through the guided post-booking flow
  /// (seat + baggage selection), as opposed to a standalone seat/baggage
  /// intent typed outside that flow.
  bool get hasActiveBookingFlow => pendingBooking != null;

  /// The pending confirmation, but only while it is still live.
  VoiceAction? confirmationValidAt(DateTime now) {
    final expiry = pendingConfirmationExpiresAt;
    if (pendingConfirmation == null || expiry == null) return null;
    return now.isBefore(expiry) ? pendingConfirmation : null;
  }

  ChatState copyWith({
    List<ChatMessage>? messages,
    ChatStatus? status,
    String? errorMessage,
    bool clearError = false,
    bool? isVoiceOutputEnabled,
    bool? isSoundEnabled,
    Booking? pendingBooking,
    bool clearPendingBooking = false,
    String? pendingSeatNumber,
    bool clearPendingSeatNumber = false,
    List<BaggagePurchase>? pendingBaggagePurchases,
    String? confirmedOfferId,
    bool clearConfirmedOfferId = false,
    String? confirmedSeatNumber,
    bool clearConfirmedSeatNumber = false,
    List<String>? confirmedBaggageOptionIds,
    VoiceContext? voiceContext,
    VoiceAction? pendingConfirmation,
    DateTime? pendingConfirmationExpiresAt,
    bool clearPendingConfirmation = false,
    String? highlightedOfferId,
    bool clearHighlightedOfferId = false,
    String? highlightedSeatNumber,
    bool clearHighlightedSeatNumber = false,
    String? highlightedBaggageOptionId,
    bool clearHighlightedBaggageOptionId = false,
    bool clearCardHighlights = false,
    int? proactivePromptStep,
    String? dictationDraft,
    int? dictationRevision,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isVoiceOutputEnabled: isVoiceOutputEnabled ?? this.isVoiceOutputEnabled,
      isSoundEnabled: isSoundEnabled ?? this.isSoundEnabled,
      pendingBooking: clearPendingBooking ? null : (pendingBooking ?? this.pendingBooking),
      pendingSeatNumber:
          clearPendingSeatNumber ? null : (pendingSeatNumber ?? this.pendingSeatNumber),
      pendingBaggagePurchases: pendingBaggagePurchases ?? this.pendingBaggagePurchases,
      confirmedOfferId:
          clearConfirmedOfferId ? null : (confirmedOfferId ?? this.confirmedOfferId),
      confirmedSeatNumber:
          clearConfirmedSeatNumber ? null : (confirmedSeatNumber ?? this.confirmedSeatNumber),
      confirmedBaggageOptionIds: confirmedBaggageOptionIds ?? this.confirmedBaggageOptionIds,
      voiceContext: voiceContext ?? this.voiceContext,
      pendingConfirmation:
          clearPendingConfirmation ? null : (pendingConfirmation ?? this.pendingConfirmation),
      pendingConfirmationExpiresAt: clearPendingConfirmation
          ? null
          : (pendingConfirmationExpiresAt ?? this.pendingConfirmationExpiresAt),
      highlightedOfferId: clearCardHighlights || clearHighlightedOfferId
          ? null
          : (highlightedOfferId ?? this.highlightedOfferId),
      highlightedSeatNumber: clearCardHighlights || clearHighlightedSeatNumber
          ? null
          : (highlightedSeatNumber ?? this.highlightedSeatNumber),
      highlightedBaggageOptionId: clearCardHighlights || clearHighlightedBaggageOptionId
          ? null
          : (highlightedBaggageOptionId ?? this.highlightedBaggageOptionId),
      proactivePromptStep: proactivePromptStep ?? this.proactivePromptStep,
      dictationDraft: dictationDraft ?? this.dictationDraft,
      dictationRevision: dictationRevision ?? this.dictationRevision,
    );
  }

  @override
  List<Object?> get props => [
        messages,
        status,
        errorMessage,
        isVoiceOutputEnabled,
        isSoundEnabled,
        pendingBooking,
        pendingSeatNumber,
        pendingBaggagePurchases,
        confirmedOfferId,
        confirmedSeatNumber,
        confirmedBaggageOptionIds,
        voiceContext,
        pendingConfirmation,
        pendingConfirmationExpiresAt,
        highlightedOfferId,
        highlightedSeatNumber,
        highlightedBaggageOptionId,
        proactivePromptStep,
        dictationDraft,
        dictationRevision,
      ];
}
