import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../../features/ai_travel_assistant/domain/entities/intent.dart';
import '../../utils/app_date.dart';

class QueryUnderstandingService {
  QueryUnderstandingService._();

  static final QueryUnderstandingService instance =
  QueryUnderstandingService._();

  final String _apiUrl = dotenv.env['API_URL'] ?? '';
  final String _apiKey = dotenv.env['API_KEY'] ?? '';
  final String _model = dotenv.env['MODEL_NAME'] ?? 'gemini-2-5-flash';

  /// Ceiling on the classification round trip.
  ///
  /// This call had no bound at all, and a hung request took the whole turn with
  /// it: nothing downstream runs until an intent comes back, so the passenger
  /// heard the acknowledgement and then silence — no answer, no error, and the
  /// microphone reopening as if the turn had been dealt with. Captured on a
  /// device: a booking request at 17:20:00 never produced an `INTENT RESPONSE`
  /// line at all.
  ///
  /// Generous, because the prompt is long and a slow-but-working
  /// classification is better than none: the fallback posts the raw message to
  /// the backend, which routes it but without the entities and `qnPrompt` this
  /// call extracts. 10s was expiring on real traffic — a booking request timed
  /// out at exactly 10.000s while the router was merely slow, not stuck.
  ///
  /// Expiring is safe rather than silent: the `catch` below flags
  /// [IntentResult.classifierFailed], and `ChatViewModel._handleIntent` posts
  /// the message straight to TravelBuddy `/chat` instead of guessing at it.
  /// The cost of the longer budget is that a genuinely stuck router now holds
  /// the turn for twenty seconds before that fallback runs.
  static const _classifyBudget = Duration(seconds: 20);

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
wallet
unknown


Intent Definitions:

- searchFlights:
  User wants to discover, find, list, browse, view,
  show or search available flights between locations.
  Includes flight options, schedules, departures,
  arrivals and available routes.

  A wish to BOOK, or a request for HELP booking, is also searchFlights
  whenever no specific flight has been chosen yet. A flight has to be found
  before it can be booked, so "book a flight" and "search for a flight" are
  the same request at this stage.

  Examples, all searchFlights:

  book a flight
  I want to book a flight
  I need to book a flight
  help me book a flight
  help me with booking a flight
  can you help me with booking a flight
  can you help me with booking of flight
  search for a flight
  find me a flight
  I want to fly somewhere

  Confidence for these is HIGH — 0.9 or above — even when origin,
  destination and date are ALL missing. Missing details are not a reason to
  lower confidence: the intent is certain, only the parameters are absent.
  Low confidence makes the assistant offer a human agent, which is the wrong
  answer to a clear request to book a flight.

  When origin or destination is missing, return an empty qnPrompt. The
  assistant asks for the missing details itself.



- bookFlight:
  User wants to book, reserve, confirm or purchase
  a specific flight.

  This intent should be selected only when the
  user has already chosen a particular flight,
  OR a flight number is available,
  OR the conversation context contains a selected flight.

  Examples:

  book AA2556

  yes book it

  confirm booking

  reserve this flight

  proceed with booking

  yes book now

  book the recommended flight

  confirm AA2556

  purchase this ticket


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
  whether points could cover a trip they are still planning.
  NOT their own balance - see wallet.

- wallet:
  User is asking what THEY currently hold:
  how many miles or points they have,
  their voucher, their card on file,
  their tier or loyalty status balance.
  This is a lookup of their own account,
  not an exploration of a trip.

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

BOOKING RULES

bookFlight applies ONLY when a particular flight is already identified —
a flight number in the message, or a flight chosen earlier in the
conversation. A general wish to book with no flight picked out is
searchFlights, not bookFlight.

  book AA2556            -> bookFlight  (a flight is named)
  yes book it            -> bookFlight  (a flight was chosen already)
  book a flight          -> searchFlights (nothing chosen yet)
  help me book a flight  -> searchFlights (nothing chosen yet)

If the user's message indicates they want to confirm or proceed with
booking a specific flight, classify it as:

action = "bookFlight"

Examples include:

- book
- book now
- yes
- yes please
- proceed
- proceed with booking
- reserve it
- confirm booking
- purchase ticket
- book AA2556
- book the recommended flight
- confirm AA2556

If a flightNumber is available in the message
or conversation context:

entities:

{
   "flightNumber":"AA2556"
}

Generate:

"qnPrompt":"book it"

Never generate a flight search prompt.

Never use:

flights from XXX to YYY

when action == bookFlight.

==========================
TRIP DISCOVERY QNPROMPT RULE
==========================

If action == "tripDiscovery":

- qnPrompt MUST contain the user's complete original message.
- Preserve the user's exact wording.
- Do NOT summarize, rewrite, normalize, translate, or modify it.
- Do NOT generate a flight-search prompt.
- qnPrompt must be exactly the same as the user's input message.

Example:

Input:
Best time for our family of 4 to visit Tokyo in spring?

Output:
{
  "action": "tripDiscovery",
  "confidence": 0.99,
  "entities": {
    "destination": "Tokyo",
    "travellers": "4",
    "season": "spring"
  },
  "qnPrompt": "Best time for our family of 4 to visit Tokyo in spring?"
}

==========================
QNPROMPT GENERATION RULES
==========================

The qnPrompt is used by the flight search API.

Always generate qnPrompt in one of these formats:

Without date:
"flights from {origin} to {destination}"

With date:
"flights from {origin} to {destination} on {yyyy-MM-dd}"

LOCATION NORMALIZATION

Whenever possible, convert locations to their official IATA airport codes.

Priority:
1. Airport name
2. Airport code
3. City
4. Otherwise keep original text

If the user explicitly mentions an airport, convert it to its IATA code.
Examples:
London Heathrow Airport -> LHR
John F. Kennedy Airport -> JFK
Indira Gandhi International Airport -> DEL
Chhatrapati Shivaji Airport -> BOM
Kempegowda Airport -> BLR
Dubai International Airport -> DXB
Singapore Changi Airport -> SIN

If the user already provides an IATA airport code, preserve it exactly.

If the user provides only a city and the city has one commonly accepted primary airport, replace the city with its IATA airport code.
Examples:
Delhi -> DEL
Mumbai -> BOM
Bengaluru/Bangalore -> BLR
Chennai -> MAA
Hyderabad -> HYD
Kolkata -> CCU
Pune -> PNQ
Ahmedabad -> AMD
Dubai -> DXB
Abu Dhabi -> AUH
Doha -> DOH
Singapore -> SIN
Bangkok -> BKK
Paris -> CDG
Frankfurt -> FRA
Amsterdam -> AMS
Los Angeles -> LAX
San Francisco -> SFO
San Diego -> SAN
Seattle -> SEA
Chicago -> ORD
Dallas -> DFW
Atlanta -> ATL
Miami -> MIA
Sydney -> SYD
Melbourne -> MEL
London -> LHR
California -> LAX
Texas -> DFW
Florida -> MIA
Japan -> HND
India -> DEL
England -> LHR
Paris -> CDG
New York -> JFK

Never guess when a city has multiple major airports.
Keep the original city name.
Examples:
London
New York
Milan
Moscow
Berlin

Never convert states, regions or countries into airport codes.
Examples:
California
Texas
England
India
Japan
Europe

Flights from London to California
-> flights from London to California

If a location cannot confidently be mapped, keep the original text.

If either source or destination is missing, keep qnPrompt empty.

If a date exists, append: on yyyy-MM-dd.

A relative date such as "today", "tomorrow", "this weekend" or "next Friday"
counts as a date. Resolve it against CURRENT DATE CONTEXT and append the
resolved yyyy-MM-dd — never pass the relative wording through, and never
treat the date as missing. Put the same resolved value in entities.date.

Never invent airport codes.
Never guess between multiple airports.
Only use airport codes when the mapping is confident.

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

book flight AA2556 from DEL to MIA on 2026-08-25

Output:

{
  "action":"bookFlight",
  "confidence":0.99,
  "entities":{
      "flightNumber":"AA2556",
      "source":"DEL",
      "destination":"MIA",
      "date":"2026-08-25"
  },
  "qnPrompt":"book it"
}
Input:

Book AA2556

Output:

{
  "action":"bookFlight",
  "confidence":0.99,
  "entities":{
      "flightNumber":"AA2556"
  },
  "qnPrompt":"book it"
}
Input:

Yes, book now.

Output:

{
  "action":"bookFlight",
  "confidence":0.98,
  "entities":{},
  "qnPrompt":"book it"
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
Can you help me with booking a flight

Output:
{
  "action":"searchFlights",
  "confidence":0.95,
  "entities":{},
  "qnPrompt":""
}

Input:
Help me with booking a flight

Output:
{
  "action":"searchFlights",
  "confidence":0.95,
  "entities":{},
  "qnPrompt":""
}

Input:
I want to book a flight

Output:
{
  "action":"searchFlights",
  "confidence":0.95,
  "entities":{},
  "qnPrompt":""
}

Input:
Search for a flight

Output:
{
  "action":"searchFlights",
  "confidence":0.95,
  "entities":{},
  "qnPrompt":""
}

Input:
Book a flight to London

Output:
{
  "action":"searchFlights",
  "confidence":0.94,
  "entities":{
    "destination":"LHR"
  },
  "qnPrompt":""
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
    "source":"DEL",
    "destination":"BOM"
  },
  "qnPrompt":"flights from DEL to BOM"
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

1. If user asks what they themselves hold - their miles/points balance, voucher, card or tier -> wallet
2. If user is exploring a trip, destination, travel ideas, costs, or whether points could pay for a trip -> tripDiscovery
3. If user is asking for passport, visa, immigration or eligibility -> travelDocuments
4. If user is asking for layover quality, connection risks or itinerary improvements -> itineraryOptimization
5. If user is asking for packing, destination weather, local culture or etiquette -> destinationGuidance
6. If user is asking for airport facilities such as restaurants, lounges, play areas or shopping -> airportAmenities
7. If user is asking about customs, immigration, meeting points or arriving at destination -> arrivalAssistance
8. If user mentions a specific flight and asks status -> flightStatus
9. If user wants to find available flights -> searchFlights
10. If user wants to book but has not chosen a flight -> searchFlights,
    with high confidence, even if origin, destination and date are missing.

When a message matches multiple intents, choose the MOST SPECIFIC intent rather than the more general one.
"""
            },
            {
              // Sent separately from the instruction prompt because it is the
              // only part that changes between calls — the rest of the system
              // prompt stays byte-identical and cacheable.
              "role": "system",
              "content": AppDate.promptContext,
            },
            {
              "role": "user",
              "content": input,
            }
          ],
          "temperature": 0,
        }),
      ).timeout(_classifyBudget);

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

      // Flagged rather than reported as a low-confidence `unknown`: the
      // message was never classified, so nothing here justifies telling the
      // passenger their wording was unclear. The caller passes these straight
      // to the TravelBuddy backend, which routes them itself.
      return  IntentResult(
          type: IntentType.unknown,
          confidence: 0.0,
          originalMessage: input,
          classifierFailed: true,
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

      case 'wallet':
        return IntentType.wallet;

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
      case 'bookFlight':
        return IntentType.bookFlight;

      default:
        return IntentType.unknown;
    }
  }
}




