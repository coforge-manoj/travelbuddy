import 'package:equatable/equatable.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';

enum ChatStatus { idle, loadingHistory, sendingMessage, listening, error }

class ChatState extends Equatable {
  const ChatState({
    this.messages = const [],
    this.status = ChatStatus.idle,
    this.errorMessage,
    this.isVoiceOutputEnabled = true,
    this.pendingBooking,
    this.pendingSeatNumber,
    this.pendingBaggagePurchases = const [],
  });

  final List<ChatMessage> messages;
  final ChatStatus status;
  final String? errorMessage;
  final bool isVoiceOutputEnabled;

  /// The booking created by [ChatViewModel.selectFlightOffer] while the
  /// guided seat/baggage flow is in progress. Cleared once
  /// [ChatViewModel.finishBooking] renders the final itinerary card.
  final Booking? pendingBooking;
  final String? pendingSeatNumber;
  final List<BaggagePurchase> pendingBaggagePurchases;

  bool get isBusy => status == ChatStatus.sendingMessage || status == ChatStatus.loadingHistory;

  /// Whether the passenger is mid-way through the guided post-booking flow
  /// (seat + baggage selection), as opposed to a standalone seat/baggage
  /// intent typed outside that flow.
  bool get hasActiveBookingFlow => pendingBooking != null;

  ChatState copyWith({
    List<ChatMessage>? messages,
    ChatStatus? status,
    String? errorMessage,
    bool clearError = false,
    bool? isVoiceOutputEnabled,
    Booking? pendingBooking,
    bool clearPendingBooking = false,
    String? pendingSeatNumber,
    bool clearPendingSeatNumber = false,
    List<BaggagePurchase>? pendingBaggagePurchases,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isVoiceOutputEnabled: isVoiceOutputEnabled ?? this.isVoiceOutputEnabled,
      pendingBooking: clearPendingBooking ? null : (pendingBooking ?? this.pendingBooking),
      pendingSeatNumber:
          clearPendingSeatNumber ? null : (pendingSeatNumber ?? this.pendingSeatNumber),
      pendingBaggagePurchases: pendingBaggagePurchases ?? this.pendingBaggagePurchases,
    );
  }

  @override
  List<Object?> get props => [
        messages,
        status,
        errorMessage,
        isVoiceOutputEnabled,
        pendingBooking,
        pendingSeatNumber,
        pendingBaggagePurchases,
      ];
}
