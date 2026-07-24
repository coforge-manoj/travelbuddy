import 'package:ai_travel_assistant/features/ai_travel_assistant/core/travel_tool_schemas.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/services/llm/llm_service.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/intent.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/mock_backend/mock_backend_server.dart';

/// An offline [LlmService] that stands in for Gemini so the Generative-UI loop
/// works with **no API key and no network call**. Instead of asking a model to
/// route, it reuses the same keyword [MockBackendServer.classifyIntent] the
/// rest of the demo backend uses, maps the intent to the matching tool, and
/// asks [RunAssistantTurnUseCase] to run it — so a request like "I want a
/// window seat" deterministically returns the seat-map card.
///
/// Wired in place of the custom gateway adapter via `llmServiceProvider`
/// whenever `AppEnv.hasCustomLlm` is false. Behaviour intentionally mirrors the
/// real adapter's contract: tool-picking on the first pass, plain text on the
/// summary pass.
class MockLlmService implements LlmService {
  MockLlmService({MockBackendServer? backend})
      : _backend = backend ?? MockBackendServer.instance;

  final MockBackendServer _backend;
  int _callCounter = 0;

  /// Maps a classified [IntentType] to the tool the orchestrator understands,
  /// or `null` for intents that have no tool (answered as plain text).
  static const Map<IntentType, String> _intentToTool = {
    IntentType.seatSelection: TravelToolSchemas.getSeatMap,
    IntentType.addBaggage: TravelToolSchemas.getBaggageOptions,
    IntentType.flightStatus: TravelToolSchemas.getFlightStatus,
    IntentType.terminalInformation: TravelToolSchemas.getAirportInfo,
    IntentType.humanAgent: TravelToolSchemas.escalateToAgent,
  };

  @override
  Future<LlmResult> chat({
    required String apiKey,
    required List<LlmTurn> history,
    bool enableTools = true,
    Set<String>? enabledTools,
  }) async {
    // Small delay so the UI still shows its "thinking" state realistically.
    await Future<void>.delayed(const Duration(milliseconds: 250));

    // Summary pass (tools disabled): the tool card is already on screen, so we
    // only owe a short friendly sentence — keyed off whatever tool just ran.
    if (!enableTools) {
      return LlmResult(text: _summaryFor(history));
    }

    final userText = _lastUserText(history);
    final intent = _backend.classifyIntent(userText);
    final toolName = _intentToTool[intent.type];

    // No tool fits (FAQ / greeting) → reply in plain text like the real model.
    if (toolName == null || !(enabledTools ?? TravelToolSchemas.allToolNames).contains(toolName)) {
      return LlmResult(text: _backend.generateReplyText(userText));
    }

    return LlmResult(
      text: '',
      toolCalls: [
        LlmToolCall(
          id: 'mock_call_${_callCounter++}',
          name: toolName,
          // The orchestrator falls back to the active booking context for any
          // missing args, so an empty arg map is all the mock needs to supply.
          args: const {},
        ),
      ],
    );
  }

  String _lastUserText(List<LlmTurn> history) {
    for (final turn in history.reversed) {
      if (turn is UserTurn) return turn.text;
    }
    return '';
  }

  /// A short, human-sounding summary chosen by the tool that most recently ran.
  String _summaryFor(List<LlmTurn> history) {
    for (final turn in history.reversed) {
      if (turn is ToolResultTurn) {
        if (turn.response['error'] != null) {
          return turn.response['error'].toString();
        }
        return switch (turn.name) {
          TravelToolSchemas.getSeatMap =>
            'Here are the available seats — tap one to select it.',
          TravelToolSchemas.getFlightStatus =>
            "Here's your current flight status.",
          TravelToolSchemas.getBaggageOptions =>
            'Here are the extra baggage options you can add.',
          TravelToolSchemas.getBaggageAllowance =>
            'Your booking already includes '
                '${turn.response['checked_kg']}kg checked and '
                '${turn.response['cabin_kg']}kg cabin baggage.',
          TravelToolSchemas.getAirportInfo =>
            "Here's how to get to your gate.",
          TravelToolSchemas.escalateToAgent =>
            "I'm connecting you with a human agent now.",
          _ => 'Here is what I found.',
        };
      }
      // The transcript-rewrite pass sends a bare user instruction with tools
      // off; echo it back so a voice recording is never lost.
      if (turn is UserTurn) return turn.text;
    }
    return 'Here is what I found.';
  }
}
