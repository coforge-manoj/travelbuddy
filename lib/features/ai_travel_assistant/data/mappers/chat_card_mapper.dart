import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/basket_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/boarding_pass_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/booking_confirmed_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/cancellation_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/card_json.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/flight_list_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/flight_selected_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/seat_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/travel_history_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/upgrade_quote_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';

/// One rendered card: the [ChatMessageType] the UI switches on, and the
/// domain object behind it.
class ChatCard {
  const ChatCard({required this.type, required this.payload});

  final ChatMessageType type;
  final Object payload;
}

/// Turns the `cards` array of a TravelBuddy `/chat` response into the cards
/// the chat can render.
///
/// Dispatch is on each card's own `type`, which is the documented contract —
/// not on the turn's `tool`. A turn may carry more than one card, and the
/// same card type shows up under different tools (a `basket` arrives from
/// adding extras *and* as the confirmation preview for "book it"), so `type`
/// is the only field that reliably says what to draw.
///
/// Types we have no widget for are skipped rather than guessed at: every
/// card comes with a `reply` sentence that stands on its own, so the turn
/// still reads correctly as text.
class ChatCardMapper {
  const ChatCardMapper._();

  /// [needsConfirmation] is the turn-level flag from the response envelope —
  /// it decides whether a `cancellation` card is a preview or a receipt.
  static List<ChatCard> fromResponse(
    Object? cards, {
    bool needsConfirmation = false,
  }) {
    final out = <ChatCard>[];

    for (final card in CardJson.asMapList(cards)) {
      final mapped = _fromCard(card, needsConfirmation: needsConfirmation);
      if (mapped != null) out.add(mapped);
    }

    return out;
  }

  /// The follow-up chips to offer for a turn, or empty when there are none
  /// worth showing.
  ///
  /// The backend attaches its stock suggestions to every turn, including
  /// ones that produced nothing: "search for flight to london" answers "I
  /// need an origin, a destination and a date" and still offers "Book the
  /// recommended one", with no flights on screen to book. A turn only earns
  /// its chips if it came back with a card or is waiting on a confirmation.
  ///
  /// Deliberately keyed off the backend's own `cards`, not the cards this
  /// client managed to map, so a card type we cannot draw yet still counts
  /// as a result and keeps its follow-ups.
  static List<String> followUpsFrom(Map<String, dynamic> data) {
    if (!_producedResult(data)) return const [];
    return CardJson.asStringList(data['suggestions']);
  }

  /// True when the backend is still collecting the origin, destination and
  /// date for a search — it answers "I need an origin, a destination and a
  /// date." under `tool: search_flights` with nothing to render.
  ///
  /// This is what tells a half-finished search apart from a journey turn.
  /// The passenger's next message has to be merged into the search being
  /// assembled (see `ConversationRouterService`) rather than posted to
  /// `/chat` verbatim, which is right for every other turn.
  ///
  /// Safe by construction: a journey turn always either carries a card or
  /// is waiting on a confirmation, and a no-op reply such as "Left it as it
  /// was." comes back under a different tool.
  static bool needsSearchDetails(Map<String, dynamic> data) {
    if (_producedResult(data)) return false;
    final tool = CardJson.asString(data['tool'])?.toLowerCase();
    return tool != null && _searchFlightsTools.contains(tool);
  }

  /// Both spellings the backend has used for the search tool.
  static const _searchFlightsTools = <String>{'search_flights', 'search_flight'};

  /// Whether a turn came back with something to act on. Deliberately keyed
  /// off the backend's own `cards`, not the cards this client managed to
  /// map, so a card type we cannot draw yet still counts as a result.
  static bool _producedResult(Map<String, dynamic> data) {
    final cards = data['cards'];
    return (cards is List && cards.isNotEmpty) ||
        data['needsConfirmation'] == true;
  }

  /// Card types the client knows how to draw. Anything outside this set
  /// falls back to the reply text — see [ChatCardMapper]'s doc comment.
  static const supportedCardTypes = <String>{
    FlightListCardMapper.flightListCardType,
    FlightSelectedCardMapper.flightSelectedCardType,
    BasketCardMapper.basketCardType,
    BasketCardMapper.extrasListCardType,
    BookingConfirmedCardMapper.bookingConfirmedCardType,
    BookingConfirmedCardMapper.bookingDetailCardType,
    SeatCardMapper.seatMapCardType,
    SeatCardMapper.seatConfirmedCardType,
    BoardingPassCardMapper.boardingPassCardType,
    UpgradeQuoteCardMapper.upgradeQuoteCardType,
    CancellationCardMapper.cancellationCardType,
    TravelHistoryCardMapper.travelHistoryCardType,
  };

  static ChatCard? _fromCard(
    Map<String, dynamic> card, {
    required bool needsConfirmation,
  }) {
    switch (CardJson.typeOf(card)) {
      case FlightListCardMapper.flightListCardType:
        final offers = FlightListCardMapper.fromCard(card);
        return offers.isEmpty
            ? null
            : ChatCard(
                type: ChatMessageType.flightOffersCard,
                payload: offers,
              );

      case FlightSelectedCardMapper.flightSelectedCardType:
        return _card(
          ChatMessageType.flightSelectedCard,
          FlightSelectedCardMapper.fromCard(card),
        );

      case BasketCardMapper.basketCardType:
        return _card(
          ChatMessageType.basketCard,
          BasketCardMapper.fromCard(card),
        );

      case BasketCardMapper.extrasListCardType:
        return _card(
          ChatMessageType.extrasListCard,
          BasketCardMapper.extrasCatalogueFromCard(card),
        );

      case BookingConfirmedCardMapper.bookingConfirmedCardType:
        return _card(
          ChatMessageType.bookingConfirmedCard,
          BookingConfirmedCardMapper.fromCard(card),
        );

      case BookingConfirmedCardMapper.bookingDetailCardType:
        return _card(
          ChatMessageType.bookingConfirmedCard,
          BookingConfirmedCardMapper.fromCard(card, isDetail: true),
        );

      case SeatCardMapper.seatMapCardType:
        return _card(
          ChatMessageType.cabinSeatMapCard,
          SeatCardMapper.fromSeatMapCard(card),
        );

      case SeatCardMapper.seatConfirmedCardType:
        return _card(
          ChatMessageType.seatConfirmedCard,
          SeatCardMapper.fromSeatConfirmedCard(card),
        );

      case BoardingPassCardMapper.boardingPassCardType:
        return _card(
          ChatMessageType.boardingPassCard,
          BoardingPassCardMapper.fromCard(card),
        );

      case UpgradeQuoteCardMapper.upgradeQuoteCardType:
        return _card(
          ChatMessageType.upgradeQuoteCard,
          UpgradeQuoteCardMapper.fromCard(card),
        );

      case TravelHistoryCardMapper.travelHistoryCardType:
        return _card(
          ChatMessageType.travelHistoryCard,
          TravelHistoryCardMapper.fromCard(card),
        );

      case CancellationCardMapper.cancellationCardType:
        return _card(
          ChatMessageType.cancellationCard,
          CancellationCardMapper.fromCard(
            card,
            needsConfirmation: needsConfirmation,
          ),
        );

      default:
        return null;
    }
  }

  static ChatCard? _card(ChatMessageType type, Object? payload) =>
      payload == null ? null : ChatCard(type: type, payload: payload);
}
