import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/core/travel_tool_schemas.dart';
import 'llm_service.dart';

/// Adapter for the custom **OpenAI-compatible** chat gateway that fronts Gemini
/// Flash 2.5 (the Coforge QAG LLM router), reached with `X-API-KEY` auth.
///
/// ## Why this does NOT use native function calling
/// The gateway wraps Gemini's `generateContent` but reads the reply via
/// Gemini's `.text` convenience accessor, which throws whenever the candidate
/// has no text part. Any time Gemini decides to emit a **function-call** part —
/// which it does both when an OpenAI `tools` array is sent *and* when the prompt
/// tells it to "pick a tool" — the gateway crashes with HTTP 500
/// (`finish_reason 12`, "response.text ... none were returned"). So native
/// tool-calling is unusable here.
///
/// Instead we keep the model firmly in **text mode** and route tools ourselves:
/// the prompt asks for a single JSON object as plain text
/// (`{"action": "...", "args": {...}}` or `{"action": "none", "reply": "..."}`),
/// which this adapter parses back into the neutral [LlmToolCall]/[LlmResult]
/// contract the orchestrator already understands. The rest of the app —
/// including every rich card — is unchanged. History is serialized to plain
/// text messages too (no `tool_calls`/`tool` roles), so no turn can trip the
/// gateway's text-only assumption.
class CustomLlmService implements LlmService {
  CustomLlmService({
    required String url,
    Dio? dio,
    String? model,
    double temperature = 0.8,
    double topP = 0.9,
    int maxTokens = 1000,
  })  : _url = url,
        _dio = dio ?? Dio(),
        _model = model ?? 'gemini-2-5-flash',
        _temperature = temperature,
        _topP = topP,
        _maxTokens = maxTokens;

  final String _url;
  final Dio _dio;
  final String _model;
  final double _temperature;
  final double _topP;
  final int _maxTokens;

  @override
  Future<LlmResult> chat({
    required String apiKey,
    required List<LlmTurn> history,
    bool enableTools = true,
    Set<String>? enabledTools,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw LlmException(
        'Add your gateway API key to the .env file (CUSTOM_LLM_API_KEY) to '
        'start chatting.',
      );
    }

    final allowed = enabledTools ?? TravelToolSchemas.allToolNames;

    try {
      final res = await _dio.post<Map<String, dynamic>>(
        _url,
        options: Options(headers: {
          'Content-Type': 'application/json',
          // Header keeps the API key out of the URL/logs.
          'X-API-KEY': apiKey,
        },),
        data: {
          'model': _model,
          'messages': _toMessages(history, enableTools, allowed),
          'temperature': _temperature,
          'top_p': _topP,
          'max_tokens': _maxTokens,
          // Deliberately NO `tools` field — see the class doc: it makes the
          // gateway 500.
        },
      );

      final data = res.data ?? const {};
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw LlmException('The assistant service returned no answer.');
      }
      final message =
          ((choices.first as Map)['message'] as Map).cast<String, dynamic>();
      final content = (message['content'] as String?)?.trim() ?? '';

      // Summary / transcript passes want prose, not a routing decision.
      if (!enableTools) return LlmResult(text: content);

      return _parseRoutingDecision(content, allowed);
    } on DioException catch (e) {
      throw LlmException(_describeError(e));
    }
  }

  /// Interprets the model's plain-text JSON routing decision. Falls back to
  /// treating the whole reply as text if it isn't the expected JSON, so a
  /// chatty answer is never lost.
  LlmResult _parseRoutingDecision(String content, Set<String> allowed) {
    final json = _extractJsonObject(content);
    if (json == null) return LlmResult(text: content);

    final action = json['action']?.toString().trim() ?? '';
    if (action.isEmpty || action == 'none' || !allowed.contains(action)) {
      final reply = json['reply']?.toString().trim();
      return LlmResult(text: (reply != null && reply.isNotEmpty) ? reply : '');
    }

    final args = json['args'];
    return LlmResult(
      text: '',
      toolCalls: [
        LlmToolCall(
          // The gateway assigns no call id; synthesize a stable one.
          id: '${action}_0',
          name: action,
          args: (args is Map) ? args.cast<String, dynamic>() : const {},
        ),
      ],
    );
  }

  /// Pulls the first `{...}` block out of [content], tolerating markdown code
  /// fences or stray prose the model may wrap around it. Returns null if no
  /// valid JSON object is found.
  Map<String, dynamic>? _extractJsonObject(String content) {
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start == -1 || end <= start) return null;
    try {
      final decoded = jsonDecode(content.substring(start, end + 1));
      return decoded is Map ? decoded.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  /// Serializes neutral history to plain-text OpenAI messages. The system
  /// message is either the routing prompt (tool pass) or a plain summarizer
  /// prompt (summary/transcript pass) — neither uses `tools` or "pick a tool"
  /// phrasing, both of which crash the gateway. Assistant tool calls and tool
  /// results are folded into text so no message carries a `tool_calls`/`tool`
  /// role.
  List<Map<String, dynamic>> _toMessages(
    List<LlmTurn> history,
    bool enableTools,
    Set<String> allowed,
  ) {
    final out = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content':
            enableTools ? _routingSystemPrompt(allowed) : _summarySystemPrompt,
      },
    ];
    for (final turn in history) {
      switch (turn) {
        case UserTurn():
          out.add({'role': 'user', 'content': turn.text});
        case AssistantTurn():
          if (turn.text.isNotEmpty) {
            out.add({'role': 'assistant', 'content': turn.text});
          }
        // A bare tool-call assistant turn carries no user-visible text; the
        // following ToolResultTurn conveys everything the model needs.
        case ToolResultTurn():
          out.add({
            'role': 'user',
            'content':
                'Result of ${turn.name}: ${jsonEncode(turn.response)}',
          });
      }
    }
    return out;
  }

  /// The tool-routing instruction, built from [TravelToolSchemas] so it always
  /// lists exactly the [allowed] tools with their argument names.
  String _routingSystemPrompt(Set<String> allowed) {
    final catalog = StringBuffer();
    for (final t in TravelToolSchemas.openaiTools) {
      final fn = (t['function'] as Map).cast<String, dynamic>();
      final name = fn['name'].toString();
      if (!allowed.contains(name)) continue;
      final props =
          ((fn['parameters'] as Map)['properties'] as Map?)?.keys.join(', ') ??
              '';
      catalog.write('- $name: ${fn['description']}');
      if (props.isNotEmpty) catalog.write(' (args: $props)');
      catalog.write('\n');
    }

    return 'You are TravelBuddy, an airline travel assistant embedded in a '
        'mobile app. The passenger already has an active booking, so you do NOT '
        'need to ask for their flight number, PNR, or airport unless they '
        'mention a different one.\n\n'
        'Reply with a SINGLE JSON object as plain text — no markdown, no code '
        'fences, no extra prose. Do not call functions.\n\n'
        'To perform a travel action, reply exactly:\n'
        '{"action": "<one action name>", "args": { ... }}\n'
        'Omit any arg you were not told; the app fills it from the active '
        'booking. Available actions:\n'
        '$catalog\n'
        'If no action fits (greeting, thanks, small talk, or a general '
        'question you can answer directly), reply:\n'
        '{"action": "none", "reply": "<your short friendly answer>"}\n\n'
        'Output only the JSON object.';
  }

  static const String _summarySystemPrompt =
      'You are TravelBuddy, a friendly airline travel assistant. The app has '
      'just shown the passenger a rich card with the details. Write a short, '
      'friendly 1-2 sentence reply in plain text — do not restate every field '
      'and do not output JSON.';

  String _describeError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    String? serverMsg;
    if (data is Map && data['error'] != null) {
      final err = data['error'];
      serverMsg = err is Map ? err['message']?.toString() : err.toString();
    } else if (data is Map && data['detail'] != null) {
      serverMsg = data['detail']?.toString();
    } else if (data is Map && data['message'] != null) {
      serverMsg = data['message']?.toString();
    } else if (data is String && data.isNotEmpty) {
      serverMsg = data;
    }

    if (status == 429) {
      return 'Rate limit reached. Please wait a few seconds and try again.';
    }
    if (status == 500) {
      return 'The assistant service had a temporary problem. Please try again.';
    }
    if (serverMsg != null) {
      return 'Assistant service${status != null ? ' ($status)' : ''}: $serverMsg';
    }
    if (status == 400 || status == 401 || status == 403) {
      return 'The assistant service rejected the request (HTTP $status). '
          'Check your CUSTOM_LLM_API_KEY.';
    }
    return 'Network error talking to the assistant service: '
        '${e.message ?? e.type.name}';
  }
}
