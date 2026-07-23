import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class InputSummarizeService {
  InputSummarizeService._();

  static final InputSummarizeService instance = InputSummarizeService._();

  final String _apiUrl =
  dotenv.env['API_URL'] ?? '';

  final String _apiKey =
  dotenv.env['API_KEY'] ?? '';

  final String _model =
  dotenv.env['MODEL_NAME'] ?? 'gemini-2-5-flash';

  Future<String> summarizeInput(String input) async {
    try {
      if (input.trim().isEmpty) {
        return '';
      }

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey,
        },
        body: jsonEncode({
          "model": _model,
          "messages": [
            {
              "role": "system",
              "content": """
You are an intent-cleaning assistant.

Your task is to clean speech-to-text transcripts.

Rules:
- Remove filler words such as um, umm, uh, hmm, er, ah.
- Remove unnecessary repetitions.
- Fix grammar and punctuation.
- Preserve all important information.
- Preserve names, dates, amounts, locations, and user intent.
- Do not shorten the message unless the removed text is irrelevant filler.
- Return only the cleaned text.
- Do not explain your changes.
"""
            },
            {
              "role": "user",
              "content": input,
            }
          ],
          "temperature": 0.0,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'API Error (${response.statusCode}): ${response.body}',
        );
      }

      final data = jsonDecode(response.body);

      return data['choices'][0]['message']['content']?.toString().trim() ??
          input;
    } catch (e) {
      print('InputSummarizeService Error: $e');
      return input;
    }
  }
}
