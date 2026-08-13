/// Pinned snapshot of TravelBuddy chat capabilities.
///
/// **Source:** a real `GET /api/v1/chat/capabilities` response, captured
/// 2026-08-13. This replaces the earlier partial snapshot, which was inferred
/// from observed `POST /chat` payloads because the tunnel was unreachable at
/// the time. The full contract is now pinned, so [JourneyStage.values] can be
/// extended against it rather than against guesses.
///
/// `confirmingTools` is the set the backend flags `confirms: true` — the
/// mutating steps that come back with `needsConfirmation` and must never be
/// silently re-posted, since a duplicate "yes" is a double charge.
///
/// `toleratedAliases` holds spellings seen on the wire that the published
/// list does not carry — `search_flight` (singular) appeared in 2026-08-07
/// payloads. `JourneyStage` may accept those, but they are kept apart from
/// `tools` so the published contract stays the source of truth and an alias
/// is a deliberate choice rather than a typo nobody noticed.
const chatCapabilitiesFixture = <String, Object?>{
  'capturedFrom': 'GET /api/v1/chat/capabilities',
  'capturedAt': '2026-08-13',
  'incomplete': false,
  'tools': <String>[
    'search_flights',
    'select_flight',
    'list_extras',
    'add_extras',
    'remove_extras',
    'view_basket',
    'checkout',
    'hold_fare',
    'get_booking',
    'show_seats',
    'change_seat',
    'check_in',
    'boarding_pass',
    'quote_upgrade',
    'confirm_upgrade',
    'cancel_booking',
    'get_wallet',
    'get_profile',
    'trip_context',
    'check_documents',
    'travel_history',
    'spend_summary',
    'interaction_history',
    'brand_info',
    'suggest_destinations',
  ],
  'confirmingTools': <String>[
    'checkout',
    'confirm_upgrade',
    'cancel_booking',
  ],
  'toleratedAliases': <String>[
    'search_flight',
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
    'wallet',
    'trip_context',
    'document_check',
    'suggestion_list',
    'member_profile',
    'travel_history',
    'spend_summary',
    'interaction_history',
    'brand_info',
    'text',
  ],
};
