import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/basket_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/cancellation_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/chat_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/flight_list_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/journey/journey_stage.dart';

import '../fixtures/chat_capabilities.dart';

void main() {
  group('JourneyStage table', () {
    test('every table tool is listed in the capabilities fixture', () {
      // Published tools, plus the handful of legacy spellings the fixture
      // explicitly tolerates — so a genuine typo still fails here.
      final known = <String>{
        ...(chatCapabilitiesFixture['tools'] as List).cast<String>(),
        ...(chatCapabilitiesFixture['toleratedAliases'] as List).cast<String>(),
      };
      for (final stage in JourneyStage.values) {
        for (final tool in stage.tools) {
          expect(
            known,
            contains(tool),
            reason: '${stage.id} uses `$tool` which is not in the fixture',
          );
        }
      }
    });

    test('mutating mirrors the backend\'s own `confirms: true` set', () {
      // The backend is the authority on which steps take a confirmation.
      // If these drift, a mutating step could be silently re-posted — and a
      // duplicate "yes" on checkout is a double charge.
      final confirming =
          (chatCapabilitiesFixture['confirmingTools'] as List).cast<String>();

      final mutating = <String>{
        for (final stage in JourneyStage.values)
          if (stage.mutating) ...stage.tools,
      };

      expect(mutating, unorderedEquals(confirming));
    });

    test('every card a stage expects has a mapper behind it', () {
      // `expects` drives misfire detection: naming a card the client cannot
      // draw would make a good turn look like a failure.
      for (final stage in JourneyStage.values) {
        for (final card in stage.expects) {
          expect(
            ChatCardMapper.supportedCardTypes,
            contains(card),
            reason: '${stage.id} expects `$card`, which has no mapper',
          );
        }
      }
    });

    test('unknown tools resolve to null — safe fallback', () {
      expect(JourneyStage.forTool(null), isNull);
      expect(JourneyStage.forTool(''), isNull);
      expect(JourneyStage.forTool('wallet'), isNull);
    });

    test('search accepts both spellings and collects', () {
      expect(JourneyStage.forTool('search_flights'), same(JourneyStage.search));
      expect(JourneyStage.forTool('search_flight'), same(JourneyStage.search));
      expect(JourneyStage.search.collects, isTrue);
      expect(JourneyStage.search.mutating, isFalse);
      expect(
        JourneyStage.search.expects,
        contains(FlightListCardMapper.flightListCardType),
      );
    });

    test('list_extras is non-mutating and repairable', () {
      final stage = JourneyStage.forTool('list_extras')!;
      expect(stage.collects, isFalse);
      expect(stage.mutating, isFalse);
      expect(stage.repairMessage, isNotNull);
      expect(
        stage.expects,
        contains(BasketCardMapper.extrasListCardType),
      );
    });

    test('cancel_booking is mutating — no silent fresh retry', () {
      final stage = JourneyStage.forTool('cancel_booking')!;
      expect(stage.mutating, isTrue);
      expect(stage.collects, isFalse);
      expect(
        stage.expects,
        contains(CancellationCardMapper.cancellationCardType),
      );
      // repairMessage is reserved for the confirm-flag path.
      expect(stage.repairMessage, isNotNull);
    });
  });

  group('TurnOutcome matrix (confirmed tools)', () {
    test('1 search collecting — half-finished search', () {
      expect(
        ChatCardMapper.outcomeOf({
          'reply': 'I need an origin, a destination and a date.',
          'tool': 'search_flights',
          'cards': <Object>[],
          'needsConfirmation': false,
        }),
        TurnOutcome.collecting,
      );
      expect(
        ChatCardMapper.needsSearchDetails({
          'tool': 'search_flights',
          'cards': <Object>[],
        }),
        isTrue,
      );
    });

    test('1 search result — flight_list present', () {
      expect(
        ChatCardMapper.outcomeOf({
          'tool': 'search_flights',
          'cards': [
            {'type': 'flight_list', 'flights': <Object>[]},
          ],
        }),
        TurnOutcome.result,
      );
    });

    test('4 list_extras misfire — no card, nothing held', () {
      expect(
        ChatCardMapper.outcomeOf({
          'tool': 'list_extras',
          'cards': <Object>[],
          'needsConfirmation': false,
        }),
        TurnOutcome.misfire,
      );
      // Must not look like a collecting search.
      expect(
        ChatCardMapper.needsSearchDetails({
          'tool': 'list_extras',
          'cards': <Object>[],
        }),
        isFalse,
      );
    });

    test('7/13 cancel awaiting approval', () {
      expect(
        ChatCardMapper.outcomeOf({
          'reply': "That's RLTYVL — AA50 DFW to LHR. Cancel it?",
          'tool': 'cancel_booking',
          'cards': <Object>[],
          'needsConfirmation': true,
        }),
        TurnOutcome.awaitingApproval,
      );
    });

    test('13 cancel misfire — Left it as it was', () {
      expect(
        ChatCardMapper.outcomeOf({
          'reply': 'Left it as it was.',
          'tool': 'cancel_booking',
          'cards': <Object>[],
        }),
        TurnOutcome.misfire,
      );
      // Protects the journey: must NOT route the next message.
      expect(
        ChatCardMapper.needsSearchDetails({
          'reply': 'Left it as it was.',
          'tool': 'cancel_booking',
          'cards': <Object>[],
        }),
        isFalse,
      );
    });

    test('unknown tool stays conversational', () {
      expect(
        ChatCardMapper.outcomeOf({
          'tool': 'wallet',
          'cards': <Object>[],
        }),
        TurnOutcome.conversational,
      );
    });

    test('card type with no mapper still counts as result', () {
      expect(
        ChatCardMapper.outcomeOf({
          'tool': 'spend_summary_tool',
          'cards': [
            {'type': 'spend_summary'},
          ],
        }),
        TurnOutcome.result,
      );
    });
  });
}
