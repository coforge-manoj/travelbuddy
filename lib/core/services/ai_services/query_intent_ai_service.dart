import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../../features/ai_travel_assistant/domain/entities/intent.dart';

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
        return  IntentResult(
          type: IntentType.unknown,
          confidence: 0.0,
          originalMessage: input
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
  "entities": {},
  "qnPrompt": ""
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
tripDiscovery
tripRecommendation
travelDocuments
itineraryOptimization
travelPlanning
destinationGuidance
airportAmenities
inflightAssistance
arrivalAssistance
baggageTracking
tripManagement
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
  
- tripDiscovery:
  User is exploring destinations,
  travel ideas,
  best time to travel,
  family trip planning,
  trip costs,
  reward points usage.

- tripRecommendation:
  Fare alerts,
  reward seat alerts,
  travel deals,
  savings opportunities,
  booking recommendations.

- travelDocuments:
  Passport,
  visa,
  immigration requirements,
  document validity,
  travel eligibility.

- itineraryOptimization:
  Connection time evaluation,
  alternate routing,
  layover recommendations,
  itinerary improvements.

- travelPlanning:
  Leave-home recommendations,
  pre-trip planning,
  departure preparation,
  travel reminders.

- destinationGuidance:
  Destination information,
  weather,
  local culture,
  etiquette,
  packing recommendations.

- airportAmenities:
  Airport restaurants,
  lounges,
  kids play areas,
  shopping,
  airport facilities.

- inflightAssistance:
  Entertainment,
  wifi,
  meal requests,
  seating comfort,
  onboard assistance.

- arrivalAssistance:
  Immigration,
  customs,
  arrival guidance,
  meeting points,
  destination arrival support.

- baggageTracking:
  Baggage status,
  baggage location,
  baggage carousel,
  baggage pickup information.

- tripManagement:
  Existing trip summary,
  travel reminders,
  trip preparation,
  earned rewards,
  return journey planning.  

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
9. For searchFlights always generate qnPrompt.

Format:

If source and destination available:
"flights from {source} to {destination}"

If date is available:
"flights from {source} to {destination} on {yyyy-MM-dd}"

Use airport codes when confidently known:
Dallas -> DFW
London Heathrow -> LHR
New York JFK -> JFK

If source or destination is missing, keep qnPrompt empty.

Examples:

Input:
Best time for our family of 4 to visit Tokyo?

Output:
{
  "action":"tripDiscovery",
  "confidence":0.99,
  "entities":{
    "destination":"Tokyo",
    "travellers":"4"
  }
}

Input:
Can we use points for our Tokyo trip?

Output:
{
  "action":"tripDiscovery",
  "confidence":0.98,
  "entities":{
    "destination":"Tokyo",
    "travelType":"reward_points"
  }
}

Input:
Any better deals available for our April Tokyo trip?

Output:
{
  "action":"tripRecommendation",
  "confidence":0.98,
  "entities":{
    "destination":"Tokyo",
    "month":"April"
  }
}

Input:
Award seats just opened. Is this a good deal?

Output:
{
  "action":"tripRecommendation",
  "confidence":0.97,
  "entities":{}
}

Input:
Does my child need a passport to travel to Japan?

Output:
{
  "action":"travelDocuments",
  "confidence":0.99,
  "entities":{
    "country":"Japan"
  }
}

Input:
Will my passport expire too soon for this trip?

Output:
{
  "action":"travelDocuments",
  "confidence":0.98,
  "entities":{}
}

Input:
Is a 55-minute DFW connection enough for my family?

Output:
{
  "action":"itineraryOptimization",
  "confidence":0.99,
  "entities":{
    "airport":"DFW",
    "connectionTime":"55"
  }
}

Input:
Do you recommend a longer layover?

Output:
{
  "action":"itineraryOptimization",
  "confidence":0.97,
  "entities":{}
}

Input:
What time should we leave home for the airport tomorrow?

Output:
{
  "action":"travelPlanning",
  "confidence":0.99,
  "entities":{}
}

Input:
Please remind us when to leave for the airport.

Output:
{
  "action":"travelPlanning",
  "confidence":0.98,
  "entities":{}
}

Input:
What should we pack for Tokyo in April?

Output:
{
  "action":"destinationGuidance",
  "confidence":0.99,
  "entities":{
    "destination":"Tokyo",
    "month":"April"
  }
}

Input:
What should my kids know before visiting Japan?

Output:
{
  "action":"destinationGuidance",
  "confidence":0.98,
  "entities":{
    "country":"Japan"
  }
}

Input:
Where is Gate 22?

Output:
{
  "action":"airportNavigation",
  "confidence":0.99,
  "entities":{
    "gate":"22"
  }
}

Input:
How do I get to the family security lane?

Output:
{
  "action":"airportNavigation",
  "confidence":0.98,
  "entities":{
    "type":"family_security"
  }
}

Input:
Any kid-friendly restaurants near my gate?

Output:
{
  "action":"airportAmenities",
  "confidence":0.99,
  "entities":{
    "travellerType":"family"
  }
}

Input:
Is there a play area for children at DFW?

Output:
{
  "action":"airportAmenities",
  "confidence":0.99,
  "entities":{
    "airport":"DFW"
  }
}

Input:
Can I get Wi-Fi during the flight?

Output:
{
  "action":"inflightAssistance",
  "confidence":0.99,
  "entities":{}
}

Input:
What entertainment options are available for kids onboard?

Output:
{
  "action":"inflightAssistance",
  "confidence":0.98,
  "entities":{
    "travellerType":"child"
  }
}

Input:
How do we clear customs at Narita?

Output:
{
  "action":"arrivalAssistance",
  "confidence":0.99,
  "entities":{
    "airport":"Narita"
  }
}

Input:
Where do we meet our family after immigration?

Output:
{
  "action":"arrivalAssistance",
  "confidence":0.98,
  "entities":{}
}

Input:
Which carousel has my baggage?

Output:
{
  "action":"baggageTracking",
  "confidence":0.99,
  "entities":{}
}

Input:
Have my checked bags arrived yet?

Output:
{
  "action":"baggageTracking",
  "confidence":0.98,
  "entities":{}
}

Input:
How many miles did I earn from this trip?

Output:
{
  "action":"tripManagement",
  "confidence":0.99,
  "entities":{}
}

Input:
Remind me about my return flight.

Output:
{
  "action":"tripManagement",
  "confidence":0.98,
  "entities":{}
}

Input:
Show available flights from Dallas to London on June 10 2027

Output:
{
  "action":"searchFlights",
  "confidence":0.99,
  "entities":{
    "source":"DFW",
    "destination":"LHR",
    "date":"2027-06-10"
  },
  "qnPrompt":"flights from DFW to LHR on 2027-06-10"
}
Input:
Show available flights from Delhi to Mumbai.

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
My flight is delayed.

Output:
{
  "action":"flightStatus",
  "confidence":0.98,
  "entities":{}
}

Input:
Show me window seats.

Output:
{
  "action":"seatSelection",
  "confidence":0.98,
  "entities":{
    "seatType":"window"
  }
}

Input:
I need extra 10 kg baggage.

Output:
{
  "action":"addBaggage",
  "confidence":0.99,
  "entities":{
    "weightKg":"10"
  }
}

Input:
Which terminal does my flight depart from?

Output:
{
  "action":"terminalInformation",
  "confidence":0.98,
  "entities":{}
}

Input:
Where is the check-in counter?

Output:
{
  "action":"counterInformation",
  "confidence":0.98,
  "entities":{}
}

Input:
When does boarding start?

Output:
{
  "action":"boardingTime",
  "confidence":0.98,
  "entities":{}
}

Input:
What is my baggage allowance?

Output:
{
  "action":"baggageAllowance",
  "confidence":0.99,
  "entities":{}
}

Input:
Connect me to a live agent.

Output:
{
  "action":"humanAgent",
  "confidence":0.99,
  "entities":{}
}

Input:
Can I travel with an expired passport?

Output:
{
  "action":"faq",
  "confidence":0.95,
  "entities":{}
}

Important Classification Priority:

1. If user is exploring a trip, destination, travel ideas, costs or points -> tripDiscovery
2. If user is asking for passport, visa, immigration or eligibility -> travelDocuments
3. If user is asking for layover quality, connection risks or itinerary improvements -> itineraryOptimization
4. If user is asking for packing, destination weather, local culture or etiquette -> destinationGuidance
5. If user is asking for airport facilities such as restaurants, lounges, play areas or shopping -> airportAmenities
6. If user is asking about customs, immigration, meeting points or arriving at destination -> arrivalAssistance
7. If user mentions a specific flight and asks status -> flightStatus
8. If user wants to find available flights -> searchFlights

When a message matches multiple intents, choose the MOST SPECIFIC intent rather than the more general one.
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
          originalMessage: input,
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
        qnPromt: result['qnPrompt']?.toString() ?? '',
      );
    } catch (e) {
      print('QueryUnderstandingService Error: $e');

      return  IntentResult(
        type: IntentType.unknown,
        confidence: 0.0,
          originalMessage: input
      );
    }
  }

  IntentType _parseIntent(String? value) {
    switch (value) {
      case 'searchFlights':
        return IntentType.searchFlights;

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

      case 'tripDiscovery':
        return IntentType.tripDiscovery;

      case 'tripRecommendation':
        return IntentType.tripRecommendation;

      case 'travelDocuments':
        return IntentType.travelDocuments;

      case 'itineraryOptimization':
        return IntentType.itineraryOptimization;

      case 'travelPlanning':
        return IntentType.travelPlanning;

      case 'destinationGuidance':
        return IntentType.destinationGuidance;

      case 'airportAmenities':
        return IntentType.airportAmenities;

      case 'inflightAssistance':
        return IntentType.inflightAssistance;

      case 'arrivalAssistance':
        return IntentType.arrivalAssistance;

      case 'baggageTracking':
        return IntentType.baggageTracking;

      case 'tripManagement':
        return IntentType.tripManagement;

      default:
        return IntentType.unknown;
    }
  }
}




