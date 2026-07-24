// Provider-neutral LLM abstraction. Chat history is stored in these neutral
// turn types; each adapter (currently only Gemini) serializes them to its own
// wire format. Keeping the boundary here means the orchestrator never depends
// on a specific provider's request/response shape.

/// A tool/function call the model requested.
class LlmToolCall {
  /// Provider call id. Gemini has none, so adapters synthesize a stable one.
  final String id;
  final String name;
  final Map<String, dynamic> args;

  /// Gemini "thinking" models attach an opaque thought signature to each
  /// function call that must be echoed back verbatim in later history turns.
  /// Null when the provider doesn't use it.
  final String? thoughtSignature;

  const LlmToolCall({
    required this.id,
    required this.name,
    required this.args,
    this.thoughtSignature,
  });
}

/// One turn of the neutral conversation history.
sealed class LlmTurn {
  const LlmTurn();
}

class UserTurn extends LlmTurn {
  final String text;
  const UserTurn(this.text);
}

class AssistantTurn extends LlmTurn {
  final String text;
  final List<LlmToolCall> toolCalls;
  const AssistantTurn(this.text, {this.toolCalls = const []});
}

class ToolResultTurn extends LlmTurn {
  final String toolCallId;
  final String name;
  final Map<String, dynamic> response;
  const ToolResultTurn({
    required this.toolCallId,
    required this.name,
    required this.response,
  });
}

/// Result of a single model turn.
class LlmResult {
  final String text;
  final List<LlmToolCall> toolCalls;

  const LlmResult({required this.text, this.toolCalls = const []});

  bool get hasToolCalls => toolCalls.isNotEmpty;
}

/// Interface every provider adapter implements.
abstract interface class LlmService {
  /// Sends [history] to the model.
  ///
  /// When [enableTools] is true the model may respond with [LlmToolCall]s;
  /// [enabledTools], when provided, filters which tool schemas are offered.
  /// When [enableTools] is false the model is asked to answer in text only
  /// (used for the post-tool summary pass).
  Future<LlmResult> chat({
    required String apiKey,
    required List<LlmTurn> history,
    bool enableTools = true,
    Set<String>? enabledTools,
  });
}

/// Raised when a provider call fails; carries a user-facing message.
class LlmException implements Exception {
  final String message;
  LlmException(this.message);
  @override
  String toString() => message;
}
