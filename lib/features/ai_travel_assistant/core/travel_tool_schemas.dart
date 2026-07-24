/// Tool (function-calling) schemas the model uses to decide which airline REST
/// API to call, plus the system prompt that primes routing. Every tool maps
/// 1:1 to an existing use case (see `RunAssistantTurnUseCase`).
///
/// Schemas use Gemini's `function_declarations` format (UPPERCASE JSON-schema
/// types). All parameters are optional: the orchestrator falls back to the
/// active booking context (flight number / PNR / airport code) when the model
/// doesn't supply them.
class TravelToolSchemas {
  const TravelToolSchemas._();

  static const String getFlightStatus = 'get_flight_status';
  static const String getSeatMap = 'get_seat_map';
  static const String getBaggageOptions = 'get_baggage_options';
  static const String getBaggageAllowance = 'get_baggage_allowance';
  static const String getAirportInfo = 'get_airport_info';
  static const String escalateToAgent = 'escalate_to_agent';

  /// All tool names, used as the default enabled set.
  static const Set<String> allToolNames = {
    getFlightStatus,
    getSeatMap,
    getBaggageOptions,
    getBaggageAllowance,
    getAirportInfo,
    escalateToAgent,
  };

  static const String systemPrompt =
      'You are TravelBuddy, an airline travel assistant embedded in a mobile '
      'app. The passenger already has an active booking, so you do NOT need to '
      'ask for their flight number, PNR, or airport unless they mention a '
      'different one. Pick the ONE tool that best matches the request:\n'
      '- get_flight_status: flight status, delays, gate, boarding time, '
      'departure time.\n'
      '- get_seat_map: choosing, changing, or viewing seats (window/aisle).\n'
      '- get_baggage_options: buying or adding extra checked baggage.\n'
      '- get_baggage_allowance: how much baggage is already included '
      '(checked/cabin limits) — no purchase.\n'
      '- get_airport_info: terminal, check-in counter, gate directions, how to '
      'get to the gate, airport navigation.\n'
      '- escalate_to_agent: the passenger explicitly asks for a human/agent, or '
      'is clearly frustrated and no tool fits.\n'
      'After a tool returns, write a short, friendly 1-2 sentence summary of '
      'the result — do not restate every field, the app shows a rich card. '
      'For greetings, thanks, or anything no tool covers, reply in plain text '
      'without calling a tool.';

  /// Gemini `function_declarations` (single entry as Gemini expects).
  static const List<Map<String, dynamic>> geminiTools = [
    {
      'function_declarations': [
        {
          'name': getFlightStatus,
          'description':
              'Get the current status of the passenger\'s flight: delay, gate, '
                  'terminal, boarding time, and departure time.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'flightNumber': {
                'type': 'STRING',
                'description':
                    'Flight number, e.g. "FZ123". Omit to use the passenger\'s '
                        'active booking.',
              },
            },
          },
        },
        {
          'name': getSeatMap,
          'description':
              'Get the seat map so the passenger can choose or change a seat '
                  '(window/aisle/exit-row availability and prices).',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'flightNumber': {
                'type': 'STRING',
                'description':
                    'Flight number, e.g. "FZ123". Omit to use the active booking.',
              },
            },
          },
        },
        {
          'name': getBaggageOptions,
          'description':
              'Get purchasable extra checked-baggage options (extra weight and '
                  'price). Use when the passenger wants to ADD or BUY baggage.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'flightNumber': {
                'type': 'STRING',
                'description':
                    'Flight number, e.g. "FZ123". Omit to use the active booking.',
              },
            },
          },
        },
        {
          'name': getBaggageAllowance,
          'description':
              'Get the baggage allowance already included with the booking '
                  '(checked and cabin limits in kg). Use when the passenger asks '
                  'how much baggage they already have — not for purchases.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'pnr': {
                'type': 'STRING',
                'description':
                    'Booking reference (PNR), e.g. "ABC123". Omit to use the '
                        'active booking.',
              },
            },
          },
        },
        {
          'name': getAirportInfo,
          'description':
              'Get airport guidance: terminal, check-in counter, gate, walking '
                  'time, and step-by-step directions to the gate.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'flightNumber': {
                'type': 'STRING',
                'description':
                    'Flight number, e.g. "FZ123". Omit to use the active booking.',
              },
              'airportCode': {
                'type': 'STRING',
                'description':
                    'IATA airport code, e.g. "DXB". Omit to use the departure '
                        'airport of the active booking.',
              },
            },
          },
        },
        {
          'name': escalateToAgent,
          'description':
              'Hand the conversation to a human support agent. Use only when '
                  'the passenger explicitly asks for a person or no tool can help.',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'reason': {
                'type': 'STRING',
                'description':
                    'Short reason for the escalation, e.g. "passenger requested '
                        'a human agent".',
              },
            },
          },
        },
      ],
    },
  ];

  /// The same tools in OpenAI chat-completions `tools` format (lowercase
  /// JSON-schema types, `{type: 'function', function: {...}}` envelope). Used by
  /// the custom OpenAI-compatible gateway adapter. Derived from [geminiTools] so
  /// the two never drift.
  static List<Map<String, dynamic>> get openaiTools {
    final declarations =
        geminiTools.first['function_declarations'] as List<dynamic>;
    return [
      for (final d in declarations)
        {
          'type': 'function',
          'function': {
            'name': (d as Map)['name'],
            'description': d['description'],
            'parameters': _toOpenAiSchema(d['parameters'] as Map),
          },
        },
    ];
  }

  /// Recursively lowercases Gemini's UPPERCASE JSON-schema `type` values
  /// (`OBJECT` → `object`, `STRING` → `string`) so the schema is valid OpenAI.
  static Map<String, dynamic> _toOpenAiSchema(Map<dynamic, dynamic> schema) {
    final out = <String, dynamic>{};
    schema.forEach((key, value) {
      if (key == 'type' && value is String) {
        out['type'] = value.toLowerCase();
      } else if (key == 'properties' && value is Map) {
        out['properties'] = {
          for (final e in value.entries)
            e.key: _toOpenAiSchema(e.value as Map),
        };
      } else if (value is Map) {
        out[key as String] = _toOpenAiSchema(value);
      } else {
        out[key as String] = value;
      }
    });
    return out;
  }
}
