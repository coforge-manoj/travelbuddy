import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/chat_card_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/member_wallet_mapper.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/member_wallet.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/card_speech_text_builder.dart';

import '../fixtures/wallet_card.dart';

void main() {
  Map<String, dynamic> card([Map<String, Object?> overrides = const {}]) => {
        ...walletCardFixture,
        ...overrides,
      };

  group('wallet card — against the live payload', () {
    test('reads the balances Marcus actually has', () {
      final wallet = MemberWalletMapper.fromCard(card())!;

      expect(wallet.miles, 214000);
      expect(wallet.tier, 'Platinum Pro');
      expect(wallet.loyaltyPoints, 121500);
      expect(wallet.card?.brand, 'Citi');
      expect(wallet.card?.last4, '4417');
    });

    test('a null voucher stays absent rather than becoming an empty row', () {
      // The live payload sends `voucher: null` for this member — the common
      // case — and the card must not render a zero-value voucher line.
      expect(MemberWalletMapper.fromCard(card())!.voucher, isNull);
    });

    test('a voucher object is read when one is present', () {
      final wallet = MemberWalletMapper.fromCard(card({
        'voucher': {'code': 'TRV-88', 'amount': 150},
      }))!;

      expect(wallet.voucher?.code, 'TRV-88');
      expect(wallet.voucher?.amount, 150);
    });

    test('a voucher flattened to a bare number is still read', () {
      final wallet = MemberWalletMapper.fromCard(card({'voucher': 150}))!;
      expect(wallet.voucher?.amount, 150);
      expect(wallet.voucher?.code, isNull);
    });

    test('a wallet with nothing to say is skipped, not drawn empty', () {
      expect(MemberWalletMapper.fromCard({'type': 'wallet'}), isNull);
    });
  });

  group('wallet card — dispatch', () {
    test('the turn maps to a memberWalletCard message', () {
      final cards = ChatCardMapper.fromResponse([card()]);

      expect(cards, hasLength(1));
      expect(cards.single.type, ChatMessageType.memberWalletCard);
      expect(cards.single.payload, isA<MemberWallet>());
    });

    test('wallet is declared supported, so it does not fall back to text', () {
      expect(
        ChatCardMapper.supportedCardTypes,
        contains(MemberWalletMapper.walletCardType),
      );
    });
  });

  group('wallet card — speech', () {
    String? spoken(MemberWallet wallet) {
      return const CardSpeechTextBuilder()
          .build(ChatMessage(
            id: 'w',
            role: ChatRole.assistant,
            type: ChatMessageType.memberWalletCard,
            timestamp: DateTime(2026, 8, 13),
            text: '214,000 miles, card ending 4417.',
            payload: wallet,
          ))
          ?.text;
    }

    test('speaks the miles balance and the tier', () {
      final line = spoken(MemberWalletMapper.fromCard(card())!)!;

      expect(line, contains('214000 miles'));
      expect(line, contains('Platinum Pro'));
    });

    test('spells the card digits out rather than reading them as a number', () {
      // "4417" read as a number becomes "four thousand four hundred and
      // seventeen", which no passenger can match against their card.
      final line = spoken(MemberWalletMapper.fromCard(card())!)!;
      expect(line, isNot(contains('ending 4417')));
      expect(line, contains('Citi card ending'));
    });

    test('does not read loyalty points aloud beside the miles', () {
      // Two large numbers in one breath are indistinguishable by ear, and
      // miles are the ones the question was about.
      final line = spoken(MemberWalletMapper.fromCard(card())!)!;
      expect(line, isNot(contains('121500')));
    });
  });
}
