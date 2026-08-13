/// Pinned snapshot of TravelBuddy chat capabilities.
///
/// **Source:** tools and card types observed on live `POST /api/v1/chat`
/// payloads captured in [journey_live_payloads_test.dart] (2026-08-07), not
/// a fresh `GET /api/v1/chat/capabilities` response — the tunnel was
/// unreachable when this fixture was written. Replace this map wholesale
/// once that endpoint can be captured; [JourneyStage.values] must stay a
/// subset of [tools] and must not invent names that are not listed here.
const chatCapabilitiesFixture = <String, Object?>{
  'capturedFrom': 'journey_live_payloads_test.dart / POST /api/v1/chat',
  'capturedAt': '2026-08-07',
  'incomplete': true,
  'note':
      'Only tools seen on the wire are listed. Refresh from '
      'GET /api/v1/chat/capabilities (expected ~25 tools, ~21 card types) '
      'before adding more JourneyStage rows.',
  'tools': <String>[
    'search_flights',
    'search_flight',
    'list_extras',
    'cancel_booking',
  ],
  'cardTypes': <String>[
    'flight_list',
    'flight_selected',
    'basket',
    'extras_list',
    'booking_confirmed',
    'booking_detail',
    'seat_map',
    'seat_confirmed',
    'boarding_pass',
    'upgrade_quote',
    'cancellation',
    'travel_history',
    'spend_summary',
  ],
};
