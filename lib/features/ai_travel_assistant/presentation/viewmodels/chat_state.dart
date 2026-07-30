import 'package:equatable/equatable.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/concierge_demo/domain/entities/proactive_scenario.dart';

enum ChatStatus { idle, loadingHistory, sendingMessage, listening, error }

class ChatState extends Equatable {
  const ChatState({
    this.messages = const [],
    this.status = ChatStatus.idle,
    this.errorMessage,
    this.isVoiceOutputEnabled = false,
    this.pendingBooking,
    this.pendingSeatNumber,
    this.pendingBaggagePurchases = const [],
    this.activeScenario,
    this.scenarioTurnIndex = 0,
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

  /// The Journey Concierge scenario currently being walked through inline in
  /// this chat, if any — set once a passenger's message matches a
  /// [ProactiveScenario]'s opening line, cleared once its final turn's
  /// concluding action card is shown. See [ChatViewModel.sendMessage].
  final ProactiveScenario? activeScenario;

  /// Index into [activeScenario]'s turns of the exchange the passenger is
  /// currently expected to reply to.
  final int scenarioTurnIndex;

  bool get isBusy => status == ChatStatus.sendingMessage || status == ChatStatus.loadingHistory;

  /// Whether the passenger is mid-way through the guided post-booking flow
  /// (seat + baggage selection), as opposed to a standalone seat/baggage
  /// intent typed outside that flow.
  bool get hasActiveBookingFlow => pendingBooking != null;

  bool get hasActiveScenario => activeScenario != null;

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
    ProactiveScenario? activeScenario,
    bool clearActiveScenario = false,
    int? scenarioTurnIndex,
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
      activeScenario: clearActiveScenario ? null : (activeScenario ?? this.activeScenario),
      scenarioTurnIndex: scenarioTurnIndex ?? this.scenarioTurnIndex,
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
        activeScenario,
        scenarioTurnIndex,
      ];
}
