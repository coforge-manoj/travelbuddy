import 'package:uuid/uuid.dart';

import 'package:ai_travel_assistant/core/config/app_env.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/core/travel_tool_schemas.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/services/llm/llm_service.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/agent_escalation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/escalate_to_agent_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/get_airport_details_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/get_baggage_options_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/get_flight_status_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/get_seat_map_usecase.dart';

/// The passenger's active booking. In this standalone demo these are the hard
/// -coded values the mock backend understands; a host app would supply the
/// real booking at integration time.
class AssistantBookingContext {
  const AssistantBookingContext({
    this.flightNumber = 'FZ123',
    this.pnr = 'ABC123',
    this.airportCode = 'DXB',
  });

  final String flightNumber;
  final String pnr;
  final String airportCode;
}

/// Orchestrates one assistant turn using the Generative-UI loop:
///
/// user text → Gemini picks a tool (or replies directly) → run the matching
/// use case against the mock backend → feed the JSON result back for a short
/// summary → return the summary bubble plus any rich card message(s).
///
/// This replaces the old keyword `ClassifyIntent → _handleIntent` path: Gemini
/// now does the routing and argument extraction. Interactive follow-ups (seat
/// change, baggage purchase) stay as card callbacks in the ViewModel and are
/// intentionally NOT exposed as tools.
class RunAssistantTurnUseCase {
  RunAssistantTurnUseCase({
    required LlmService llmService,
    required GetFlightStatusUseCase getFlightStatus,
    required GetSeatMapUseCase getSeatMap,
    required GetBaggageOptionsUseCase getBaggageOptions,
    required GetBaggageAllowanceUseCase getBaggageAllowance,
    required GetAirportDetailsUseCase getAirportDetails,
    required EscalateToAgentUseCase escalateToAgent,
    String Function()? apiKey,
    this.booking = const AssistantBookingContext(),
    Uuid uuid = const Uuid(),
  })  : _llm = llmService,
        _getFlightStatus = getFlightStatus,
        _getSeatMap = getSeatMap,
        _getBaggageOptions = getBaggageOptions,
        _getBaggageAllowance = getBaggageAllowance,
        _getAirportDetails = getAirportDetails,
        _escalateToAgent = escalateToAgent,
        _apiKey = apiKey ?? (() => AppEnv.customLlmApiKey),
        _uuid = uuid;

  final LlmService _llm;
  final GetFlightStatusUseCase _getFlightStatus;
  final GetSeatMapUseCase _getSeatMap;
  final GetBaggageOptionsUseCase _getBaggageOptions;
  final GetBaggageAllowanceUseCase _getBaggageAllowance;
  final GetAirportDetailsUseCase _getAirportDetails;
  final EscalateToAgentUseCase _escalateToAgent;
  final String Function() _apiKey;
  final Uuid _uuid;

  AssistantBookingContext booking;

  /// Provider-neutral conversation history for this chat session.
  final List<LlmTurn> _history = [];

  /// Clears the LLM history (e.g. when the chat is reset).
  void reset() => _history.clear();

  /// Voice mode 2: rewrites a raw speech transcript into a single concise,
  /// first-person request before it enters the tool loop. Tools are disabled —
  /// we only want text back. Falls back to the raw transcript if the call fails
  /// or returns nothing, so a recording is never lost. Does not touch history.
  Future<String> summarizeTranscript(String transcript) async {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) return trimmed;
    final instruction =
        'The following is a transcript of a voice message from a passenger '
        'talking to an airline travel assistant. Rewrite it as a single concise '
        'request in the first person, preserving every specific (flight numbers, '
        'seats, baggage weights, terminals, dates). Reply with ONLY the '
        'rewritten request — no quotes, no preamble.\n\n'
        'Transcript: "$trimmed"';
    try {
      final result = await _llm.chat(
        apiKey: _apiKey(),
        history: [UserTurn(instruction)],
        enableTools: false,
      );
      final text = result.text.trim();
      return text.isNotEmpty ? text : trimmed;
    } on LlmException {
      return trimmed;
    } catch (_) {
      return trimmed;
    }
  }

  /// Runs one turn for [userText], returning the assistant [ChatMessage]s to
  /// append (a text summary bubble and/or rich card messages). Throws
  /// [LlmException] on a hard LLM failure so the caller can surface it.
  Future<List<ChatMessage>> call(String userText) async {
    _history.add(UserTurn(userText));
    final apiKey = _apiKey();

    // 1) Ask the model — it may reply directly or request tool calls.
    final first = await _llm.chat(
      apiKey: apiKey,
      history: _history,
      enabledTools: TravelToolSchemas.allToolNames,
    );

    if (!first.hasToolCalls) {
      _history.add(AssistantTurn(first.text));
      final text = first.text.isNotEmpty
          ? first.text
          : "I'm not sure how to help with that yet — try asking about your "
              'flight, seat, baggage, or terminal.';
      return [_textMessage(text)];
    }

    // 2) Record the tool request, then run each tool.
    _history.add(AssistantTurn(first.text, toolCalls: first.toolCalls));
    final cards = <ChatMessage>[];
    final toolErrors = <String>[];
    for (final callItem in first.toolCalls) {
      final (response, card) = await _runTool(callItem);
      _history.add(
        ToolResultTurn(
          toolCallId: callItem.id,
          name: callItem.name,
          response: response,
        ),
      );
      if (card != null) cards.add(card);
      if (response['error'] != null) {
        toolErrors.add(response['error'].toString());
      }
    }

    // Every tool failed → surface a friendly message and skip the summary call.
    if (toolErrors.length == first.toolCalls.length) {
      final message = toolErrors.isNotEmpty
          ? toolErrors.first
          : "I couldn't complete that just now. Please try again.";
      _history.add(AssistantTurn(message));
      return [_textMessage(message)];
    }

    // 3) Feed tool results back so the model writes a short summary.
    final summary = await _llm.chat(
      apiKey: apiKey,
      history: _history,
      enableTools: false,
    );
    _history.add(AssistantTurn(summary.text));

    final messages = <ChatMessage>[];
    if (summary.text.trim().isNotEmpty) {
      messages.add(_textMessage(summary.text.trim()));
    } else if (cards.isEmpty) {
      messages.add(_textMessage('Here is what I found.'));
    }
    messages.addAll(cards);
    return messages;
  }

  /// Executes one tool call, returning (JSON response for the model, optional
  /// rich card message for the UI). Tool failures are returned as
  /// `{'error': ...}` so the model can explain them rather than throwing.
  Future<(Map<String, dynamic>, ChatMessage?)> _runTool(
    LlmToolCall call,
  ) async {
    try {
      switch (call.name) {
        case TravelToolSchemas.getFlightStatus:
          final flightNumber =
              _argString(call, 'flightNumber') ?? booking.flightNumber;
          final result = await _getFlightStatus(flightNumber);
          return result.fold(
            (f) => ({'error': f.message}, null),
            (flight) => (
              _flightResponse(flight),
              _card(ChatMessageType.flightStatusCard, flight),
            ),
          );

        case TravelToolSchemas.getSeatMap:
          final flightNumber =
              _argString(call, 'flightNumber') ?? booking.flightNumber;
          final result = await _getSeatMap(flightNumber);
          return result.fold(
            (f) => ({'error': f.message}, null),
            (seatMap) => (
              _seatMapResponse(seatMap),
              _card(ChatMessageType.seatMapCard, seatMap),
            ),
          );

        case TravelToolSchemas.getBaggageOptions:
          final flightNumber =
              _argString(call, 'flightNumber') ?? booking.flightNumber;
          final result = await _getBaggageOptions(flightNumber);
          return result.fold(
            (f) => ({'error': f.message}, null),
            (options) => (
              {
                'options': options
                    .map(
                      (o) => {
                        'id': o.id,
                        'extra_weight_kg': o.extraWeightKg,
                        'price': o.price,
                        'currency': o.currency,
                      },
                    )
                    .toList(),
              },
              _card(ChatMessageType.baggageOptionsCard, options),
            ),
          );

        case TravelToolSchemas.getBaggageAllowance:
          final pnr = _argString(call, 'pnr') ?? booking.pnr;
          final result = await _getBaggageAllowance(pnr);
          // No dedicated card yet — the model summarizes this as text.
          return result.fold(
            (f) => ({'error': f.message}, null),
            (allowance) => (
              {
                'checked_kg': allowance.checkedKg,
                'cabin_kg': allowance.cabinKg,
              },
              null,
            ),
          );

        case TravelToolSchemas.getAirportInfo:
          final flightNumber =
              _argString(call, 'flightNumber') ?? booking.flightNumber;
          final airportCode =
              _argString(call, 'airportCode') ?? booking.airportCode;
          final result = await _getAirportDetails(
            flightNumber: flightNumber,
            airportCode: airportCode,
          );
          return result.fold(
            (f) => ({'error': f.message}, null),
            (info) => (
              {
                'terminal': info.terminal,
                'check_in_counter': info.checkInCounter,
                'gate': info.gate,
                'walking_time_minutes': info.walkingTimeMinutes,
                'directions': info.directions,
              },
              _card(ChatMessageType.airportInfoCard, info),
            ),
          );

        case TravelToolSchemas.escalateToAgent:
          final reason =
              _argString(call, 'reason') ?? 'Passenger requested a human agent';
          final result = await _escalateToAgent(
            EscalationRequest(reason: reason, conversationSummary: reason),
          );
          return result.fold(
            (f) => ({'error': f.message}, null),
            (escalation) => (
              {
                'queue_position': escalation.queuePosition,
                'estimated_wait_minutes': escalation.estimatedWaitMinutes,
              },
              _card(ChatMessageType.agentEscalationCard, escalation),
            ),
          );

        default:
          return ({'error': 'Unknown tool ${call.name}'}, null);
      }
    } catch (e) {
      return ({'error': e.toString()}, null);
    }
  }

  String? _argString(LlmToolCall call, String key) {
    final value = call.args[key]?.toString().trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  Map<String, dynamic> _flightResponse(Flight flight) {
    return {
      'flight_number': flight.flightNumber,
      'status': flight.status.name,
      'is_delayed': flight.isDelayed,
      'origin': flight.origin,
      'destination': flight.destination,
      'gate': flight.gate,
      'terminal': flight.terminal,
      'scheduled_departure': flight.scheduledDeparture.toIso8601String(),
      'estimated_departure': flight.estimatedDeparture?.toIso8601String(),
      'boarding_time': flight.boardingTime?.toIso8601String(),
    };
  }

  Map<String, dynamic> _seatMapResponse(SeatMap seatMap) {
    final available = seatMap.seats.where((s) => s.isAvailable).toList();
    final windowAvailable =
        available.where((s) => s.type == SeatType.window).length;
    return {
      'flight_number': seatMap.flightNumber,
      'available_count': available.length,
      'window_available': windowAvailable,
      'currency': seatMap.currency,
      'sample_available_seats':
          available.take(6).map((s) => s.seatNumber).toList(),
    };
  }

  ChatMessage _textMessage(String text) => ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.assistant,
        type: ChatMessageType.text,
        timestamp: DateTime.now(),
        text: text,
      );

  ChatMessage _card(ChatMessageType type, Object payload) => ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.assistant,
        type: type,
        timestamp: DateTime.now(),
        payload: payload,
      );
}
