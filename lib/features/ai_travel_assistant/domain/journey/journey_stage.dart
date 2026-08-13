import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/basket_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/boarding_pass_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/booking_confirmed_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/cancellation_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/document_check_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/flight_list_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/flight_selected_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/member_wallet_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/seat_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/upgrade_quote_card_mapper.dart';

/// What a TravelBuddy `/chat` tool is expected to produce, and how the client
/// should recover when it does not.
///
/// Looked up by the backend's `tool` string. An unknown or absent tool
/// resolves to `null`, which [ChatCardMapper.outcomeOf] classifies as
/// `conversational` — exactly today's behaviour. Wrong guesses therefore
/// degrade safely rather than breaking a journey.
///
/// Only tools confirmed on the wire belong here. See
/// [test/fixtures/chat_capabilities.dart] — extend this table from that
/// fixture, do not invent names.
class JourneyStage {
  const JourneyStage({
    required this.id,
    required this.tools,
    required this.expects,
    required this.collects,
    required this.mutating,
    this.repairMessage,
    this.correctiveChip,
    this.collectingHint,
  });

  /// Stable id for tests and logging (usually the canonical tool name).
  final String id;

  /// Backend `tool` spellings that map to this stage.
  final Set<String> tools;

  /// Card `type` values a successful turn is expected to produce.
  final Set<String> expects;

  /// Whether this tool legitimately asks follow-up questions (missing
  /// origin/date, which extra, which seat, …). Collecting turns park the
  /// stage on [ChatState.awaitingDetailsFor] so the next message is merged
  /// before posting.
  final bool collects;

  /// Whether the step moves money or booking state. Mutating misfires are
  /// never silently re-posted — a duplicate "yes" is a double charge.
  final bool mutating;

  /// Alternate phrasing posted once on a non-mutating misfire (or on a
  /// confirm-flag misfire). `null` means there is nothing safe to retry.
  final String? repairMessage;

  /// Chip offered after a failed repair (or instead of repair when
  /// [mutating] is true).
  final String? correctiveChip;

  /// Short description handed to the conversation router while [collects]
  /// is true, so the merge is stage-aware rather than search-shaped.
  final String? collectingHint;

  bool get isSearch =>
      tools.contains('search_flights') || tools.contains('search_flight');

  /// Resolves [tool] against the table, or `null` when unknown/absent.
  static JourneyStage? forTool(String? tool) {
    if (tool == null || tool.isEmpty) return null;
    final key = tool.toLowerCase();
    for (final stage in values) {
      if (stage.tools.contains(key)) return stage;
    }
    return null;
  }

  /// Every tool in the pinned [chatCapabilitiesFixture] that this client
  /// drives, in journey order. The fixture is a real
  /// `GET /chat/capabilities` capture, so these names are the published
  /// contract rather than guesses.
  ///
  /// Tools deliberately absent: `remove_extras`, `view_basket`, `hold_fare`,
  /// `get_booking`, `boarding_pass`, `get_profile`, `trip_context`,
  /// `travel_history`, `spend_summary`, `interaction_history`, `brand_info`
  /// and `suggest_destinations`. They are read-only lookups with nothing to
  /// repair — an unknown tool already resolves to `conversational`, which is
  /// the right handling for all of them.
  static const values = <JourneyStage>[
    search,
    selectFlight,
    listExtras,
    addExtras,
    checkout,
    showSeats,
    changeSeat,
    checkIn,
    quoteUpgrade,
    confirmUpgrade,
    cancelBooking,
    getWallet,
    checkDocuments,
  ];

  /// Flight search — may ask for origin, destination, and date before any
  /// `flight_list` card appears.
  static const search = JourneyStage(
    id: 'search_flights',
    tools: {'search_flights', 'search_flight'},
    expects: {FlightListCardMapper.flightListCardType},
    collects: true,
    mutating: false,
    collectingHint:
        'Assembling a flight search. Merge origin, destination and travel '
        'date into one complete search prompt.',
  );

  /// Catalogue of add-ons for the held flight. Empty with no card means the
  /// session has nothing held — safe to restate the ask once.
  static const listExtras = JourneyStage(
    id: 'list_extras',
    tools: {'list_extras'},
    expects: {BasketCardMapper.extrasListCardType},
    collects: false,
    mutating: false,
    repairMessage: 'what extras can I add',
    correctiveChip: 'What extras can I add',
  );

  /// Puts a flight in the basket. Resolves against the previous search held
  /// in session state, so an empty turn means the search is gone, not that
  /// the flight is invalid.
  static const selectFlight = JourneyStage(
    id: 'select_flight',
    tools: {'select_flight'},
    expects: {FlightSelectedCardMapper.flightSelectedCardType},
    collects: false,
    mutating: false,
    repairMessage: 'show me the flights again',
    correctiveChip: 'Show flights',
  );

  /// Adds ancillaries by code. Reprices the basket, so a successful turn
  /// returns the basket rather than the extras list.
  static const addExtras = JourneyStage(
    id: 'add_extras',
    tools: {'add_extras'},
    expects: {BasketCardMapper.basketCardType},
    collects: false,
    mutating: false,
    repairMessage: 'show me my basket',
    correctiveChip: 'Show my basket',
  );

  /// Pays for the basket. **Mutating** — the backend flags this
  /// `confirms: true`, and a duplicate "yes" is a double charge, so a
  /// misfire is never silently re-posted.
  ///
  /// `expects` lists both cards because the first ask returns a `basket`
  /// preview with `needsConfirmation`, and only the confirmed turn produces
  /// `booking_confirmed`.
  static const checkout = JourneyStage(
    id: 'checkout',
    tools: {'checkout'},
    expects: {
      BasketCardMapper.basketCardType,
      BookingConfirmedCardMapper.bookingConfirmedCardType,
    },
    collects: false,
    mutating: true,
    correctiveChip: 'Show my basket',
  );

  /// Seat map for the current booking.
  static const showSeats = JourneyStage(
    id: 'show_seats',
    tools: {'show_seats'},
    expects: {SeatCardMapper.seatMapCardType},
    collects: false,
    mutating: false,
    repairMessage: 'show me the seat map',
    correctiveChip: 'Show the seat map',
  );

  /// Takes a specific seat. Changes the booking but moves no money, so a
  /// re-ask is safe.
  static const changeSeat = JourneyStage(
    id: 'change_seat',
    tools: {'change_seat'},
    expects: {SeatCardMapper.seatConfirmedCardType},
    collects: false,
    mutating: false,
    repairMessage: 'show me the seat map',
    correctiveChip: 'Show the seat map',
  );

  /// Issues a boarding pass. Re-asking simply returns the same pass.
  static const checkIn = JourneyStage(
    id: 'check_in',
    tools: {'check_in'},
    expects: {BoardingPassCardMapper.boardingPassCardType},
    collects: false,
    mutating: false,
    repairMessage: 'check me in',
    correctiveChip: 'Check me in',
  );

  /// Prices an upgrade without applying it — safe to repeat.
  static const quoteUpgrade = JourneyStage(
    id: 'quote_upgrade',
    tools: {'quote_upgrade'},
    expects: {UpgradeQuoteCardMapper.upgradeQuoteCardType},
    collects: false,
    mutating: false,
    repairMessage: 'what would an upgrade cost',
    correctiveChip: 'Quote an upgrade',
  );

  /// Applies a quoted upgrade. **Mutating** — `confirms: true` on the wire.
  static const confirmUpgrade = JourneyStage(
    id: 'confirm_upgrade',
    tools: {'confirm_upgrade'},
    expects: {BookingConfirmedCardMapper.bookingDetailCardType},
    collects: false,
    mutating: true,
    // Only for a misfire that followed `confirm: true`.
    repairMessage: 'go ahead',
    correctiveChip: 'Quote an upgrade',
  );

  /// Cancel a booking. Mutating: never silent-retry a fresh cancel ask.
  /// Confirm-flag misfires ("Left it as it was.") repair with an alternate
  /// affirmation — see [ChatViewModel] confirm path.
  static const cancelBooking = JourneyStage(
    id: 'cancel_booking',
    tools: {'cancel_booking'},
    expects: {CancellationCardMapper.cancellationCardType},
    collects: false,
    mutating: true,
    // Used only when the misfire follows `confirm: true`.
    repairMessage: 'go ahead',
    correctiveChip: 'Cancel my booking',
  );

  /// Miles, voucher and card on file. A pure lookup.
  static const getWallet = JourneyStage(
    id: 'get_wallet',
    tools: {'get_wallet'},
    expects: {MemberWalletMapper.walletCardType},
    collects: false,
    mutating: false,
    repairMessage: 'how many miles do I have',
    correctiveChip: 'My miles',
  );

  /// Passport readiness for the current trip.
  ///
  /// The repair phrasing is not interchangeable: only "is my passport OK for
  /// this trip" was observed to route here — "show me everyone's documents"
  /// and "are our documents ready" both fell through to a generic reply. See
  /// [documentCheckTriggerPhrase] in the fixture.
  static const checkDocuments = JourneyStage(
    id: 'check_documents',
    tools: {'check_documents'},
    expects: {DocumentCheckCardMapper.documentCheckCardType},
    collects: false,
    mutating: false,
    repairMessage: 'is my passport OK for this trip',
    correctiveChip: 'Check our passports',
  );
}
