import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/basket_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/boarding_pass_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/booking_confirmed_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/cancellation_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/card_json.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/document_check_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/flight_list_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/flight_selected_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/member_wallet_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/seat_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/travel_history_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/upgrade_quote_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/journey/journey_stage.dart';

/// How a TravelBuddy `/chat` turn should be handled by the client.
enum TurnOutcome {
  /// The turn produced a card (or is waiting on confirmation).
  result,

  /// Backend asked the passenger to approve a mutating action.
  awaitingApproval,

  /// A collecting stage is still gathering required details.
  collecting,

  /// A stage that expects a card produced nothing actionable.
  misfire,

  /// No known stage, or a stage that leaves the reply alone.
  conversational,
}

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

  /// Whether this turn is waiting on the passenger to approve a mutating
  /// action — paying, upgrading or cancelling.
  ///
  /// The Postman contract is that those three never happen on the first ask:
  /// they come back `needsConfirmation: true` with a preview card, and the
  /// Confirm bar (or a spoken "yes") re-sends the approval. Checkout and
  /// cancel honour the envelope flag. The live `quote_upgrade` turn often
  /// omits it even though the card's own note is "Confirm to apply", so an
  /// `upgrade_quote` is treated as awaiting approval either way — otherwise
  /// the bar never appears and voice mode offers "check me in" instead of
  /// "say yes to upgrade".
  static bool requiresConfirmation(Map<String, dynamic> data) {
    if (data['needsConfirmation'] == true) return true;
    return _hasUpgradeQuote(data);
  }

  /// Stage id to name the spoken yes/no. Falls back to `quote_upgrade`
  /// when the envelope omitted `tool` but still sent an upgrade quote.
  static String? confirmationStageId(Map<String, dynamic> data) {
    final stage = stageOf(data);
    if (stage != null) return stage.id;
    if (_hasUpgradeQuote(data)) return JourneyStage.quoteUpgrade.id;
    return null;
  }

  static bool _hasUpgradeQuote(Map<String, dynamic> data) {
    for (final card in CardJson.asMapList(data['cards'])) {
      if (CardJson.typeOf(card) == UpgradeQuoteCardMapper.upgradeQuoteCardType) {
        return true;
      }
    }
    return false;
  }

  /// True when the backend is still collecting details for a stage — today
  /// that is still origin/destination/date for search, but any
  /// [JourneyStage.collects] tool uses the same path.
  ///
  /// Kept as a named helper so existing call sites and tests stay readable;
  /// it is exactly `outcomeOf(data) == TurnOutcome.collecting`.
  static bool needsSearchDetails(Map<String, dynamic> data) =>
      outcomeOf(data) == TurnOutcome.collecting;

  /// Classifies a `/chat` envelope so the viewmodel can collect, repair, or
  /// leave the turn alone.
  ///
  /// Order matters: a card or confirmation is always a success; only then
  /// do we consult the stage table. Unknown tools fall through to
  /// [TurnOutcome.conversational], which is today's behaviour.
  static TurnOutcome outcomeOf(Map<String, dynamic> data) {
    if (_hasCards(data)) return TurnOutcome.result;
    if (data['needsConfirmation'] == true) {
      return TurnOutcome.awaitingApproval;
    }

    final stage = JourneyStage.forTool(CardJson.asString(data['tool']));
    if (stage == null) return TurnOutcome.conversational;
    if (stage.collects) return TurnOutcome.collecting;
    if (stage.expects.isNotEmpty) return TurnOutcome.misfire;
    return TurnOutcome.conversational;
  }

  /// The stage for this turn, or `null` when the tool is unknown.
  static JourneyStage? stageOf(Map<String, dynamic> data) =>
      JourneyStage.forTool(CardJson.asString(data['tool']));

  /// Whether a turn came back with something to act on. Deliberately keyed
  /// off the backend's own `cards`, not the cards this client managed to
  /// map, so a card type we cannot draw yet still counts as a result.
  ///
  /// Confirmation-only turns also count — the passenger has something to
  /// approve even when no card was drawn yet.
  static bool _producedResult(Map<String, dynamic> data) {
    return _hasCards(data) || data['needsConfirmation'] == true;
  }

  static bool _hasCards(Map<String, dynamic> data) {
    final cards = data['cards'];
    return cards is List && cards.isNotEmpty;
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
    MemberWalletMapper.walletCardType,
    DocumentCheckCardMapper.documentCheckCardType,
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

      case DocumentCheckCardMapper.documentCheckCardType:
        return _card(
          ChatMessageType.documentCheckCard,
          DocumentCheckCardMapper.fromCard(card),
        );

      case MemberWalletMapper.walletCardType:
        return _card(
          ChatMessageType.memberWalletCard,
          MemberWalletMapper.fromCard(card),
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
