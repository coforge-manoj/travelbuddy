import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../../../features/ai_travel_assistant/domain/entities/intent.dart';
import '../ai_json_parser.dart';
import 'conversation_router_result.dart';
import 'conversational_route_promt.dart' show ConversationRouterPrompt;



class ConversationRouterService {
  ConversationRouterService._();

  static final ConversationRouterService instance =
  ConversationRouterService._();

  final String _apiUrl = dotenv.env['API_URL'] ?? '';
  final String _apiKey = dotenv.env['API_KEY'] ?? '';
  final String _model =
      dotenv.env['MODEL_NAME'] ?? 'gemini-2.5-flash';

  Future<ConversationRouterResult> route({
    required IntentType activeIntent,
    required String assistantMessage,
    required String userMessage,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          "Content-Type": "application/json",
          "x-api-key": _apiKey,
        },
        body: jsonEncode({
          "model": _model,
          "temperature": 0,
          "messages": [
            {
              "role": "system",
              "content": ConversationRouterPrompt.systemPrompt,
            },
            {
              "role": "user",
              "content": """
Current Active Intent:
${activeIntent.name}

Assistant Previous Message:
$assistantMessage

User Message:
$userMessage
"""
            }
          ]
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(response.body);
      }

      final body =
      jsonDecode(response.body) as Map<String, dynamic>;

      final content =
      body["choices"][0]["message"]["content"].toString();

      final json = AiJsonParser.parseObject(content);

      return ConversationRouterResult.fromJson(json);
    } catch (e) {
      print("ConversationRouterService");
      print(e);

      /// safest behaviour
      /// if router fails,
      /// let classifier decide
      return const ConversationRouterResult(
        continueConversation: false,
      );
    }
  }
}