import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/airport_info.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/card_speech_text_builder.dart';

/// The builder is what makes rich cards audible, so the coverage here is
/// about facts surviving the trip to speech — prices, flight numbers and
/// gates must come out intact and pronounceable.
void main() {
  const builder = CardSpeechTextBuilder();

  /// What would be spoken for [message], or null if nothing would be.
  ///
  /// `build` returns a [SpokenLine] rather than a bare string, because callers
  /// need to know whether the words came from a card payload — factual lines
  /// skip the LLM summarizer so a PNR can never be reworded. These cases only
  /// care about the wording.
  String? spokenText(ChatMessage message) => builder.build(message)?.text;

  ChatMessage message({
    required ChatMessageType type,
    String text = '',
    Object? payload,
    ChatRole role = ChatRole.assistant,
  }) {
    return ChatMessage(
      id: 'id',
      role: role,
      type: type,
      timestamp: DateTime(2026, 8, 4, 9),
      text: text,
      payload: payload,
    );
  }

  final offers = [
    FlightOffer(
      id: 'UA482',
      airline: 'United Airlines',
      flightNumber: 'UA482',
      origin: 'EWR',
      destination: 'ORD',
      departureTime: DateTime(2026, 8, 5, 6, 45),
      arrivalTime: DateTime(2026, 8, 5, 8, 58),
      price: 189,
      currency: 'USD',
      stops: 0,
    ),
    FlightOffer(
      id: 'B6935',
      airline: 'JetBlue',
      flightNumber: 'B6935',
      origin: 'EWR',
      destination: 'ORD',
      departureTime: DateTime(2026, 8, 5, 17, 5),
      arrivalTime: DateTime(2026, 8, 5, 19, 22),
      price: 165,
      currency: 'USD',
      stops: 1,
    ),
  ];

  group('flight offers', () {
    test('leads with the count and describes the cheapest option', () {
      final spoken = spokenText(
        message(
          type: ChatMessageType.flightOffersCard,
          text: 'Here are a few options.',
          payload: offers,
        ),
      );

      // The caption is deliberately not spoken when there is payload detail
      // behind it. On a live turn every card is handed the backend's reply as
      // its caption, and that reply summarizes the very same answer — so
      // speaking both read it out twice, in different words.
      expect(spoken, isNot(contains('Here are a few options.')));
      // Small counts are words, not digits — an engine reads "2 options"
      // acceptably but "two options" is what a person would say.
      expect(spoken, contains('two options'));
      // Cheapest, not first.
      expect(spoken, contains('JetBlue'));
      expect(spoken, contains('165 dollars'));
      expect(spoken, contains('one stop'));
    });

    test('spells codes and airports so they are intelligible aloud', () {
      final spoken = spokenText(
        message(type: ChatMessageType.flightOffersCard, payload: offers),
      )!;

      // "B6935" as a word is unintelligible; "E W R" beats "ewer".
      expect(spoken, contains('flight B 6935'));
      expect(spoken, contains('E W R to O R D'));
    });

    test('speaks a single-digit minute as "oh five", not "five"', () {
      final spoken = spokenText(
        message(
          type: ChatMessageType.flightOffersCard,
          payload: [
            FlightOffer(
              id: 'DL2071',
              airline: 'Delta Air Lines',
              flightNumber: 'DL2071',
              origin: 'EWR',
              destination: 'ORD',
              departureTime: DateTime(2026, 8, 5, 5, 5),
              arrivalTime: DateTime(2026, 8, 5, 7, 40),
              price: 176,
              currency: 'USD',
              stops: 0,
            ),
          ],
        ),
      )!;

      expect(spoken, contains('5 oh 5 A M'));
    });
  });

  group('flight status', () {
    test('contrasts the new departure time against the scheduled one', () {
      final spoken = spokenText(
        message(
          type: ChatMessageType.flightStatusCard,
          payload: Flight(
            flightNumber: 'FZ123',
            origin: 'DXB',
            destination: 'LHR',
            status: FlightStatus.delayed,
            scheduledDeparture: DateTime(2026, 8, 5, 7, 0),
            estimatedDeparture: DateTime(2026, 8, 5, 7, 20),
            gate: 'C14',
            terminal: '3',
          ),
        ),
      )!;

      expect(spoken, contains('is delayed'));
      expect(spoken, contains('now departing 7 20 A M instead of 7 A M'));
      expect(spoken, contains('gate C 14'));
    });
  });

  group('booking confirmation', () {
    test('reads the PNR back spelled out', () {
      final spoken = spokenText(
        message(
          type: ChatMessageType.bookingConfirmationCard,
          payload: Booking(
            pnr: 'TB123456',
            passengerName: 'Joe Traveler',
            flight: Flight(
              flightNumber: 'UA482',
              origin: 'EWR',
              destination: 'ORD',
              status: FlightStatus.scheduled,
              scheduledDeparture: DateTime(2026, 8, 5, 6, 45),
            ),
          ),
        ),
      )!;

      expect(spoken, contains('Booking confirmed.'));
      // A booking reference gets every character on its own, digits included:
      // it is something the passenger writes down, not a number they hear.
      // "TB 123456" would be read back as "tee-bee one hundred and twenty-three
      // thousand...".
      expect(spoken, contains('reference is T B 1 2 3 4 5 6'));
    });
  });

  group('airport info', () {
    test('covers terminal, counter, gate and walking time', () {
      final spoken = spokenText(
        message(
          type: ChatMessageType.airportInfoCard,
          payload: const AirportInfo(
            terminal: '3',
            checkInCounter: 'D12',
            gate: 'C14',
            walkingTimeMinutes: 12,
            directions: [],
          ),
        ),
      )!;

      expect(spoken, contains('Terminal 3'));
      expect(spoken, contains('check-in D 12'));
      expect(spoken, contains('12 minutes on foot'));
    });
  });

  group('nothing to say', () {
    test('user turns are never spoken', () {
      final spoken = spokenText(
        message(
          type: ChatMessageType.text,
          text: 'Where is my gate?',
          role: ChatRole.user,
        ),
      );

      expect(spoken, isNull);
    });

    test('errors are not read aloud', () {
      final spoken = spokenText(
        message(type: ChatMessageType.error, text: 'Something went wrong'),
      );

      expect(spoken, isNull);
    });

    test('a card with an unexpected payload falls back to its caption', () {
      final spoken = spokenText(
        message(
          type: ChatMessageType.flightOffersCard,
          text: 'Here are a few options.',
          payload: 'not a list of offers',
        ),
      );

      expect(spoken, 'Here are a few options.');
    });

    test('a card with neither caption nor usable payload stays silent', () {
      final spoken = spokenText(
        message(type: ChatMessageType.flightOffersCard, payload: null),
      );

      expect(spoken, isNull);
    });
  });
}
