import 'dart:convert';

import 'package:ai_travel_assistant/features/flight_assistant_chat/data/models/user_intent_result_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class QueryUnderstandingService {
  QueryUnderstandingService._();

  static final QueryUnderstandingService instance =
      QueryUnderstandingService._();

  final String _apiUrl = dotenv.env['API_URL'] ?? '';
  final String _apiKey = dotenv.env['API_KEY'] ?? '';
  final String _model = dotenv.env['MODEL_NAME'] ?? 'gemini-2-5-flash';

  Future<UserIntentResult> summarizeInput(String input) async {
    try {
      if (input.trim().isEmpty) {
        return const UserIntentResult(
          cleanedText: '',
          intent: 'unknown',
          filters: {},
        );
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
You are an AI Flight Assistant.

Your task is to understand the user's query and convert it into structured JSON.

Return ONLY valid JSON.

Schema:

{
  "cleanedText": "",
  "action": "",
  "filters": {}
}

Allowed actions:

flightStatus
seatSelection
addBaggage
checkInCounterAndTerminal
baggageAllowance
boardingTime
airportNavigation
travelDocuments
other

Instructions:

1. Clean speech-to-text mistakes.
2. Detect the most suitable action.
3. Extract all useful entities into filters.
4. Destination, flight number, airline, baggage weight,
   seat type, terminal, gate etc should be extracted when available.
5. If query doesn't match any action then use "other".
6. Return ONLY JSON.
7. No markdown.
8. No explanation.

Examples:

User:
What is the status of my London flight?

Output:
{
  "cleanedText":"What is the status of my London flight?",
  "action":"flightStatus",
  "filters":{
    "destination":"London"
  }
}

User:
Show available window seats

Output:
{
  "cleanedText":"Show available window seats",
  "action":"seatSelection",
  "filters":{
    "seatType":"window"
  }
}

User:
Can I add 15 kg baggage?

Output:
{
  "cleanedText":"Can I add 15 kg baggage?",
  "action":"addBaggage",
  "filters":{
    "weight":"15kg"
  }
}

User:
What baggage allowance do I have?

Output:
{
  "cleanedText":"What baggage allowance do I have?",
  "action":"baggageAllowance",
  "filters":{}
}

User:
Where is terminal 3 check-in counter?

Output:
{
  "cleanedText":"Where is terminal 3 check-in counter?",
  "action":"checkInCounterAndTerminal",
  "filters":{
    "terminal":"3"
  }
}

User:
When does boarding start?

Output:
{
  "cleanedText":"When does boarding start?",
  "action":"boardingTime",
  "filters":{}
}

User:
How do I reach gate A12?

Output:
{
  "cleanedText":"How do I reach gate A12?",
  "action":"airportNavigation",
  "filters":{
    "gate":"A12"
  }
}

User:
Do I need a passport?

Output:
{
  "cleanedText":"Do I need a passport?",
  "action":"travelDocuments",
  "filters":{}
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

      final data = jsonDecode(response.body);

      final content = data['choices'][0]['message']['content'].toString();

      final cleanedContent =
          content.replaceAll('```json', '').replaceAll('```', '').trim();

      print('INTENT RESPONSE => $cleanedContent');

      final result = jsonDecode(cleanedContent) as Map<String, dynamic>;

      return UserIntentResult.fromJson(result);
    } catch (e) {
      print('InputSummarizeService Error: $e');

      return UserIntentResult(
        cleanedText: input,
        intent: 'unknown',
        filters: const {},
      );
    }
  }
}
