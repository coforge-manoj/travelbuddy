import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/chat_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/document_check_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/document_check.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/card_speech_text_builder.dart';

import '../fixtures/document_check_card.dart';

void main() {
  Map<String, dynamic> card([Map<String, Object?> overrides = const {}]) => {
        ...documentCheckCardFixture,
        ...overrides,
      };

  group('document_check — against the live payload', () {
    test('splits the party into cleared and blocked', () {
      final check = DocumentCheckCardMapper.fromCard(card())!;

      expect(check.clear.map((c) => c.passenger),
          ['Marcus Bennett', 'Priya Bennett']);
      expect(check.issues.map((i) => i.passenger),
          ['Leo Bennett', 'Zoe Bennett']);
      expect(check.ready, isFalse);
      expect(check.destination, 'Tokyo');
    });

    test('carries the remedy, not just the problem', () {
      // A warning without an action is pure alarm — the action is what makes
      // this card helpful two months before departure.
      final zoe = DocumentCheckCardMapper.fromCard(card())!
          .issues
          .firstWhere((i) => i.passenger == 'Zoe Bennett');

      expect(zoe.issue, 'expires_before_return');
      expect(zoe.isBlocking, isTrue);
      expect(zoe.detail, contains('2027-04-09'));
      expect(zoe.action, contains('expedited'));
    });

    test('keeps the expiry dates for the passengers who pass', () {
      final marcus = DocumentCheckCardMapper.fromCard(card())!.clear.first;
      expect(marcus.expiry, '2031-02-17');
    });

    test('an absent `ready` flag is inferred from the issue list', () {
      final noIssues = DocumentCheckCardMapper.fromCard(
        card({'issues': <Object?>[], 'ready': null}),
      )!;
      expect(noIssues.ready, isTrue);

      final withIssues = DocumentCheckCardMapper.fromCard(card({'ready': null}))!;
      expect(withIssues.ready, isFalse);
    });

    test('a card with nobody on either list is skipped', () {
      expect(
        DocumentCheckCardMapper.fromCard({
          'type': 'document_check',
          'ok': <Object?>[],
          'issues': <Object?>[],
        }),
        isNull,
      );
    });

    test('a passenger row with no name is dropped, not half-rendered', () {
      final check = DocumentCheckCardMapper.fromCard(card({
        'issues': [
          {'detail': 'orphaned row with no passenger'},
        ],
      }))!;
      expect(check.issues, isEmpty);
    });
  });

  group('document_check — dispatch', () {
    test('the turn maps to a documentCheckCard message', () {
      final cards = ChatCardMapper.fromResponse([card()]);

      expect(cards, hasLength(1));
      expect(cards.single.type, ChatMessageType.documentCheckCard);
      expect(cards.single.payload, isA<DocumentCheck>());
    });

    test('document_check is declared supported', () {
      expect(
        ChatCardMapper.supportedCardTypes,
        contains(DocumentCheckCardMapper.documentCheckCardType),
      );
    });
  });

  group('document_check — speech', () {
    String? spoken(Map<String, dynamic> json) {
      return const CardSpeechTextBuilder()
          .build(ChatMessage(
            id: 'd',
            role: ChatRole.assistant,
            type: ChatMessageType.documentCheckCard,
            timestamp: DateTime(2026, 8, 13),
            text: '2 document issue(s).',
            payload: DocumentCheckCardMapper.fromCard(json),
          ))
          ?.text;
    }

    test('names who needs attention and what to do', () {
      final line = spoken(card())!;

      expect(line, contains('two passengers need attention'));
      expect(line, contains('Zoe Bennett'));
      expect(line, contains('expedited'));
    });

    test('says ISO dates as words rather than reading the dashes', () {
      // "2027-04-09" read raw becomes "two thousand and twenty seven dash
      // zero four dash zero nine".
      final line = spoken(card())!;

      expect(line, contains('April 9, 2027'));
      expect(line, isNot(contains('2027-04-09')));
    });

    test('a clean party gets a short all-clear instead of a list', () {
      final line = spoken(card({'issues': <Object?>[], 'ready': true}))!;
      expect(line, contains('in order'));
      expect(line, contains('Tokyo'));
    });
  });
}
