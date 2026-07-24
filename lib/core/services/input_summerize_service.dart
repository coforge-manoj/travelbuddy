import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../features/ai_travel_assistant/data/models/summerized_input_result_model.dart';
import '../enum/flight_input_type.dart';

/// ---------------------------------------------------------------------------
/// InputSummarizeService
/// ---------------------------------------------------------------------------
///
/// Responsibilities:
/// 1. Cleans speech-to-text input by removing fillers and fixing grammar.
/// 2. Detects the user's intent using Gemini.
/// 3. Returns a [SummarizedInputResult] containing:
///    - cleanedText
///    - detected FlightInputType
///
/// Example:
///
/// Input:
/// "umm i need extra 10kg baggage"
///
/// Output:
/// SummarizedInputResult(
///   cleanedText: "I need an extra 10 kg baggage allowance.",
///   inputType: FlightInputType.addBaggage,
/// )
///
class InputSummarizeService {
  InputSummarizeService._();

  /// Singleton instance.
  static final InputSummarizeService instance = InputSummarizeService._();

  /// LLM API endpoint.
  final String _apiUrl = dotenv.env['API_URL'] ?? '';

  /// API key used for authentication.
  final String _apiKey = dotenv.env['API_KEY'] ?? '';

  /// Model name configured in .env.
  final String _model = dotenv.env['MODEL_NAME'] ?? 'gemini-2-5-flash';

  /// -------------------------------------------------------------------------
  /// summarizeInput
  /// -------------------------------------------------------------------------
  ///
  /// Sends the user input to the LLM and returns:
  /// - Cleaned text
  /// - Detected intent
  ///
  /// Supported intents:
  /// - flightStatus
  /// - seatSelection
  /// - addBaggage
  /// - checkInCounterAndTerminal
  /// - baggageAllowance
  /// - boardingTime
  /// - airportNavigation
  /// - travelDocuments
  /// - other
  ///
  Future<SummarizedInputResult> summarizeInput(
    String input,
  ) async {
    try {
      /// Return default result when input is empty.
      if (input.trim().isEmpty) {
        return SummarizedInputResult(
          cleanedText: '',
          inputType: FlightInputType.other,
        );
      }

      /// Call the LLM endpoint.
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
You are an intent detection assistant.

Your tasks:
1. Clean speech-to-text input.
2. Detect intent.

Available intent types:

- flightStatus
- seatSelection
- addBaggage
- checkInCounterAndTerminal
- baggageAllowance
- boardingTime
- airportNavigation
- travelDocuments
- other

Return ONLY JSON.

Example:

{
  "cleanedText":"What is my boarding time?",
  "inputType":"boardingTime"
}
"""
            },
            {
              "role": "user",
              "content": input,
            }
          ],
          "temperature": 0
        }),
      );

      /// Parse API response.
      final data = jsonDecode(response.body);

      /// Extract the model content.
      final content = data['choices'][0]['message']['content'].toString();

      /// Remove markdown code block wrappers if Gemini adds them.
      ///
      /// Example:
      /// ```json
      /// {
      ///   "cleanedText":"..."
      /// }
      /// ```
      final cleanedContent =
          content.replaceAll('```json', '').replaceAll('```', '').trim();

      print('CLEANED RESPONSE => $cleanedContent');

      /// Convert JSON string into a Map.
      final result = jsonDecode(cleanedContent);

      /// Read intent safely from response.
      final intent = result['inputType']?.toString().trim() ?? 'other';

      /// Convert string intent to enum.
      return SummarizedInputResult(
        cleanedText: result['cleanedText']?.toString() ?? input,
        inputType: FlightInputType.values.firstWhere(
          (e) => e.name.toLowerCase() == intent.toLowerCase(),
          orElse: () => FlightInputType.other,
        ),
      );
    } catch (e) {
      /// Fallback in case:
      /// - API failure
      /// - Invalid JSON
      /// - Unexpected model response
      print(e);

      return SummarizedInputResult(
        cleanedText: input,
        inputType: FlightInputType.other,
      );
    }
  }
}



///
//  final SummarizedInputResult result =
//     await InputSummarizeService.instance.summarizeInput(text);
// here you'll get into result type and msg.
