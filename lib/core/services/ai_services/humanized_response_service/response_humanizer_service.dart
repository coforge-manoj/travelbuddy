import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../../../features/ai_travel_assistant/data/models/humanised_response.dart';
import '../ai_json_parser.dart';
import 'humanized_response_service_promt.dart';

class ResponseHumanizerService {
  ResponseHumanizerService._();

  static final instance = ResponseHumanizerService._();

  final String _apiUrl = dotenv.env['API_URL'] ?? '';
  final String _apiKey = dotenv.env['API_KEY'] ?? '';
  final String _model =
      dotenv.env['MODEL_NAME'] ?? 'gemini-2.5-flash';

  Future<HumanizedResponse> humanize({
    required String userMessage,
    required Map<String, dynamic> backendResponse,
    List<String>? suggestions,
    String? intent,
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
          "temperature": 0.7,
          "messages": [
            {
              "role": "system",
              "content": HumanizerPrompt.systemPrompt,
            },
            {
              "role": "user",
              "content": jsonEncode({
                "userMessage": userMessage,
                "backendReply":
                backendResponse['reply']?.toString() ?? '',
                "suggestions": suggestions ?? [],
              }),
              "Intent": intent
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
      body["choices"][0]["message"]["content"]
          .toString();

      print("===== HUMANIZED RESPONSE =====");
      print(content);

      final json = AiJsonParser.parseObject(content);

      return HumanizedResponse(
        message: json['message']?.toString() ?? '',
        payload: backendResponse,
      );
    } catch (e) {
      String fallbackMessage =
          backendResponse['reply']?.toString() ?? '';

      if (suggestions != null && suggestions.isNotEmpty) {
        fallbackMessage +=
        '\n\nWould you like to:';

        for (final suggestion in suggestions) {
          fallbackMessage += '\n• $suggestion';
        }
      }

      return HumanizedResponse(
        message: fallbackMessage,
        payload: backendResponse,
      );
    }
  }
}