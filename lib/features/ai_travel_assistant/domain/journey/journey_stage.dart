import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/basket_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/cancellation_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/flight_list_card_mapper.dart';

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

  /// Stages confirmed against live `/chat` payloads and pinned in
  /// [chatCapabilitiesFixture]. More rows land here only after the
  /// capabilities capture lists their tool names.
  static const values = <JourneyStage>[
    search,
    listExtras,
    cancelBooking,
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
}
