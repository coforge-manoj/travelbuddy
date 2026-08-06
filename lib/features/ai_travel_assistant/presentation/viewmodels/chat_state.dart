import 'package:equatable/equatable.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/concierge_demo/domain/entities/proactive_scenario.dart';
import '../../data/models/conersation_route/trip_discovery_context.dart';
import '../../domain/entities/intent.dart';

enum ChatStatus {
  idle,
  loadingHistory,
  sendingMessage,
  listening,
  error,
}

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
    this.activeIntent,
    this.conversationContext = const ConversationContext(),
  });

  final List<ChatMessage> messages;
  final ChatStatus status;
  final String? errorMessage;
  final bool isVoiceOutputEnabled;

  final Booking? pendingBooking;
  final String? pendingSeatNumber;
  final List<BaggagePurchase> pendingBaggagePurchases;

  final ProactiveScenario? activeScenario;
  final int scenarioTurnIndex;

  final IntentType? activeIntent;


  /// NEW
  final ConversationContext conversationContext;

  bool get isBusy =>
      status == ChatStatus.sendingMessage ||
          status == ChatStatus.loadingHistory;

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
    IntentType? activeIntent,
    bool clearActiveIntent = false,

    /// NEW
    ConversationContext? conversationContext,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      status: status ?? this.status,
      errorMessage:
      clearError ? null : (errorMessage ?? this.errorMessage),
      isVoiceOutputEnabled:
      isVoiceOutputEnabled ?? this.isVoiceOutputEnabled,
      pendingBooking: clearPendingBooking
          ? null
          : (pendingBooking ?? this.pendingBooking),
      pendingSeatNumber: clearPendingSeatNumber
          ? null
          : (pendingSeatNumber ?? this.pendingSeatNumber),
      pendingBaggagePurchases:
      pendingBaggagePurchases ??
          this.pendingBaggagePurchases,
      activeScenario: clearActiveScenario
          ? null
          : (activeScenario ?? this.activeScenario),
      scenarioTurnIndex:
      scenarioTurnIndex ?? this.scenarioTurnIndex,
      activeIntent: clearActiveIntent
          ? null
          : (activeIntent ?? this.activeIntent),

      /// NEW
      conversationContext:
      conversationContext ?? this.conversationContext,
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
    activeIntent,

    /// NEW
    conversationContext,
  ];
}