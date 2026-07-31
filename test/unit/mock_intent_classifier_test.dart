import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/intent.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/mock_backend/mock_backend_server.dart';

/// The demo classifier is keyword-ordered, so which check runs first decides
/// where an utterance lands. These pin the orderings that are easy to get
/// wrong.
void main() {
  IntentType classify(String utterance) =>
      MockBackendServer.instance.classifyIntent(utterance).type;

  test('a seat request wins over the booking keywords it happens to contain', () {
    // "book me a window seat" is a seat request, not a flight search — a
    // passenger who says it should not land on a page of fares.
    expect(classify('book me a window seat'), IntentType.seatSelection);
    expect(classify('book a seat'), IntentType.seatSelection);
    expect(classify('reserve a seat'), IntentType.seatSelection);
    expect(classify('I want to change my seat'), IntentType.seatSelection);
  });

  test('booking a flight is still a flight search', () {
    expect(classify('I want to book a flight'), IntentType.bookFlight);
    expect(classify('find flights to Chicago'), IntentType.bookFlight);
  });

  test('the other intents keep their routing', () {
    expect(classify('add 10 kg of baggage'), IntentType.addBaggage);
    expect(classify('is my flight delayed'), IntentType.flightStatus);
    expect(classify('which terminal'), IntentType.terminalInformation);
    expect(classify('I want a human agent'), IntentType.humanAgent);
  });
}
