import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/flight_offer.dart';

import '../models/flight_offer_model.dart';

class ChatContext {
  const ChatContext({
    this.activeFlight,
    this.lastFlightSearchResults = const [],
  });

  final FlightOffer? activeFlight;
  final List<FlightOffer> lastFlightSearchResults;

  ChatContext copyWith({
    FlightOffer? activeFlight,
    List<FlightOffer>? lastFlightSearchResults,
  }) {
    return ChatContext(
      activeFlight: activeFlight ?? this.activeFlight,
      lastFlightSearchResults:
      lastFlightSearchResults ?? this.lastFlightSearchResults,
    );
  }
}