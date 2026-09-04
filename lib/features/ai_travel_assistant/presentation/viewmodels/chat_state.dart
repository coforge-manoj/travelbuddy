import 'package:equatable/equatable.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/journey/journey_stage.dart';
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

/// Where the assistant's voice is up to, for a turn as a whole.
///
/// Deliberately not part of [ChatState]: this is a sequence of events, and a
/// listener that reopens the microphone on [settled] must react to each one.
/// Folded into the state it would be a value that can be missed — two turns
/// settling back to back would look like no change at all.
enum SpeechActivity {
  /// An utterance is queued or being synthesized. Nothing is audible yet.
  preparing,

  /// Audio is playing.
  playing,

  /// The line said *before* the answer — "sure, let me check that" — is
  /// playing.
  ///
  /// Separate from [playing] because it means the opposite thing to a
  /// listener: the assistant has started talking, but the turn is still in
  /// flight. Treating it as [playing] would cancel the conversation loop's
  /// timeout on a turn that has not been answered yet.
  acknowledging,

  /// Nothing is playing and nothing is queued — the turn has finished
  /// speaking. Also emitted when a turn produced no speech at all, so a
  /// listener waiting on it is never left hanging.
  settled,
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
    this.suggestions = const [],
    this.pendingConfirmationMessage,
    this.pendingConfirmationPrompt,
    this.awaitingDetailsFor,
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

  /// Follow-up chips from the latest TravelBuddy `/chat` response.
  final List<String> suggestions;

  /// The message to re-send with `confirm: true` when the passenger approves
  /// the pending action. Set whenever a `/chat` turn came back with
  /// `needsConfirmation: true` — paying, upgrading and cancelling never
  /// happen on the first ask.
  final String? pendingConfirmationMessage;

  /// The backend's own wording for what is being approved, e.g. "That is
  /// $255 for 1 in Main Cabin Extra. Shall I go ahead?".
  final String? pendingConfirmationPrompt;

  /// The backend is still collecting details for this journey stage (search
  /// origin/date, which extra, which seat, …). While set, the next message
  /// is merged via the conversation router rather than posted to `/chat`
  /// as-is. See [ChatCardMapper.outcomeOf].
  final JourneyStage? awaitingDetailsFor;

  /// Back-compat for voice/controller call sites that still ask whether a
  /// search (or any collecting stage) is mid-flight.
  bool get awaitingSearchDetails => awaitingDetailsFor != null;

  bool get needsConfirmation => pendingConfirmationMessage != null;

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
    List<String>? suggestions,
    String? pendingConfirmationMessage,
    String? pendingConfirmationPrompt,
    bool clearPendingConfirmation = false,
    JourneyStage? awaitingDetailsFor,
    bool clearAwaitingDetailsFor = false,
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
      suggestions: suggestions ?? this.suggestions,
      pendingConfirmationMessage: clearPendingConfirmation
          ? null
          : (pendingConfirmationMessage ?? this.pendingConfirmationMessage),
      pendingConfirmationPrompt: clearPendingConfirmation
          ? null
          : (pendingConfirmationPrompt ?? this.pendingConfirmationPrompt),
      awaitingDetailsFor: clearAwaitingDetailsFor
          ? null
          : (awaitingDetailsFor ?? this.awaitingDetailsFor),
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
    suggestions,
    pendingConfirmationMessage,
    pendingConfirmationPrompt,
    awaitingDetailsFor,
  ];
}
