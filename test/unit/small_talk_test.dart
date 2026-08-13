import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/core/utils/app_date.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/small_talk.dart';

void main() {
  tearDown(() {
    AppDate.clock = DateTime.now;
  });

  test('a greeting names the passenger and hands the turn back', () {
    AppDate.clock = () => DateTime(2026, 8, 13, 9);
    final line = SmallTalkComposer(random: Random(7)).compose(
      SmallTalk.greeting,
      travelerFirstName: 'Elena',
      offers: const [],
    );

    expect(line, contains('Elena'));
    expect(
      line,
      anyOf(
        contains('What can I help you with?'),
        contains('What can I do for you?'),
        contains('How can I help?'),
        contains('What are we sorting out today?'),
        contains('What would you like to do?'),
      ),
    );
  });

  test('the greeting pool includes a day-part and a good-day opener', () {
    AppDate.clock = () => DateTime(2026, 8, 13, 9);
    final composer = SmallTalkComposer(random: Random(0));
    final lines = <String>{
      for (var i = 0; i < 16; i++)
        composer.compose(
          SmallTalk.greeting,
          travelerFirstName: 'Elena',
          offers: const [],
        ),
    };

    expect(lines.any((line) => line.startsWith('Good morning Elena')), isTrue);
    expect(lines.any((line) => line.startsWith('Good day Elena')), isTrue);
    expect(lines.any((line) => line.startsWith('Hello Elena')), isTrue);
  });
}
