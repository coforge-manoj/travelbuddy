import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/services/speech_prosody_planner.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/voice_service.dart';

void main() {
  test('statement rate maps to +0% on Edge', () {
    expect(
      VoiceService.edgeRatePercent(SpeechProsodyPlanner.statementRate),
      '+0%',
    );
  });

  test('slower rates become negative Edge percents', () {
    expect(
      VoiceService.edgeRatePercent(SpeechProsodyPlanner.softRate),
      startsWith('-'),
    );
  });

  test('statement pitch maps to +0Hz on Edge', () {
    expect(VoiceService.edgePitchHz(SpeechProsodyPlanner.statementPitch), '+0Hz');
  });

  test('question pitch becomes a positive Edge Hz lift', () {
    expect(
      VoiceService.edgePitchHz(SpeechProsodyPlanner.questionPitch),
      matches(RegExp(r'^\+\d+Hz$')),
    );
  });

  test('soft pitch becomes a negative Edge Hz drop', () {
    expect(
      VoiceService.edgePitchHz(SpeechProsodyPlanner.softPitch),
      startsWith('-'),
    );
  });
}
