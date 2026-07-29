import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../features/ai_travel_assistant/domain/entities/intent.dart';

class QueryUnderstandingService {
  QueryUnderstandingService._();

  static final QueryUnderstandingService instance =
  QueryUnderstandingService._();

  final String _apiUrl = dotenv.env['API_URL'] ?? '';
  final String _apiKey = dotenv.env['API_KEY'] ?? '';
  final String _model = dotenv.env['MODEL_NAME'] ?? 'gemini-2-5-flash';

  Future<IntentResult> summarizeInput(String input) async {
    try {
      if (input.trim().isEmpty) {
        return const IntentResult(
          type: IntentType.unknown,
          confidence: 0.0,
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

Your task is to understand the user's message and classify it into the most appropriate intent.

Return ONLY valid JSON.

Schema:

{
  "action": "",
  "confidence": 0.0,
  "entities": {}
}

Allowed actions:
searchFlights
flightStatus
seatSelection
addBaggage
terminalInformation
counterInformation
boardingTime
airportNavigation
baggageAllowance
humanAgent
faq
unknown

Intent Definitions:

- searchFlights:
  User wants to discover, find, list, browse, view,
  show or search available flights between locations.
  Includes flight options, schedules, departures,
  arrivals and available routes.

- flightStatus:
  Flight status, delay, cancellation, departure status,
  arrival status, tracking.

- seatSelection:
  Seat availability, seat selection,
  window seat, aisle seat, upgrade.

- addBaggage:
  Extra baggage, baggage purchase,
  baggage add-on, baggage weight increase.

- terminalInformation:
  Terminal number, departure terminal,
  arrival terminal.

- counterInformation:
  Check-in counter, baggage drop counter,
  check-in desk.

- boardingTime:
  Boarding start time,
  boarding announcement,
  final call.

- airportNavigation:
  Gate directions, lounge directions,
  airport navigation, airport routes.

- baggageAllowance:
  Cabin baggage allowance,
  check-in baggage allowance,
  baggage limits.

- humanAgent:
  User wants customer support,
  live agent, airline representative.

- faq:
  General travel questions such as
  passport, visa, travel rules,
  web check-in policies.

- unknown:
  Intent cannot be determined.

Rules:

1. Understand meaning, not exact keywords.
2. Choose exactly one action.
3. Return confidence between 0.0 and 1.0.
4. Extract useful entities when available.
5. Use lower confidence if unsure.
6. Return only JSON.
7. No markdown.
8. No explanation.

Examples:
Input:
Show me available flights.

Output:
{
  "action":"searchFlights",
  "confidence":0.98,
  "entities":{}
}

Input:
What flights are available from Delhi to Mumbai?

Output:
{
  "action":"searchFlights",
  "confidence":0.99,
  "entities":{
    "source":"Delhi",
    "destination":"Mumbai"
  }
}

Input:
Find flights to London.

Output:
{
  "action":"searchFlights",
  "confidence":0.98,
  "entities":{
    "destination":"London"
  }
}

Input:
Show today's departures.

Output:
{
  "action":"searchFlights",
  "confidence":0.95,
  "entities":{
    "type":"departure"
  }
}

Input:
My flight is delayed.

Output:
{
  "action":"flightStatus",
  "confidence":0.97,
  "entities":{}
}

Input:
Show me window seats.

Output:
{
  "action":"seatSelection",
  "confidence":0.96,
  "entities":{
    "seatType":"window"
  }
}

Input:
I need extra 10 kg baggage.

Output:
{
  "action":"addBaggage",
  "confidence":0.98,
  "entities":{
    "weightKg":"10"
  }
}
"""
            },
            {
              "role": "user",
              "content": input,
            }
          ],
          "temperature": 0,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'API Error: ${response.statusCode} ${response.body}',
        );
      }

      final data = jsonDecode(response.body);

      final content =
      data['choices'][0]['message']['content'].toString();

      final cleanedContent = content
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      print('INTENT RESPONSE => $cleanedContent');

      final result =
      jsonDecode(cleanedContent) as Map<String, dynamic>;

      return IntentResult(
        type: _parseIntent(
          result['action']?.toString(),
        ),
        confidence:
        (result['confidence'] as num?)?.toDouble() ??
            0.0,
        entities:
        (result['entities'] as Map?)
            ?.map(
              (key, value) => MapEntry(
            key.toString(),
            value.toString(),
          ),
        ) ??
            const {},
      );
    } catch (e) {
      print('QueryUnderstandingService Error: $e');

      return const IntentResult(
        type: IntentType.unknown,
        confidence: 0.0,
      );
    }
  }

  IntentType _parseIntent(String? value) {
    switch (value) {
      case 'searchFlights':
        return IntentType.searchFlight;

      case 'flightStatus':
        return IntentType.flightStatus;

      case 'seatSelection':
        return IntentType.seatSelection;

      case 'addBaggage':
        return IntentType.addBaggage;

      case 'terminalInformation':
        return IntentType.terminalInformation;

      case 'counterInformation':
        return IntentType.counterInformation;

      case 'boardingTime':
        return IntentType.boardingTime;

      case 'airportNavigation':
        return IntentType.airportNavigation;

      case 'baggageAllowance':
        return IntentType.baggageAllowance;

      case 'humanAgent':
        return IntentType.humanAgent;

      case 'faq':
        return IntentType.faq;

      default:
        return IntentType.unknown;
    }
  }
}
