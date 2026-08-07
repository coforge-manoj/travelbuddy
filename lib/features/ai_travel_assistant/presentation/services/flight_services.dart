import '../../../../core/services/api_services/api_service.dart';

/// Talks to the TravelBuddy `/chat` endpoint — the single endpoint the whole
/// conversational journey (search → select → extras → book → seat → check-in
/// → upgrade → cancel) runs through.
class FlightServices {
  /// One session id per instance. The backend holds the last search and the
  /// current booking against `x-session-id`, which is what lets "take the
  /// cheapest one" and "change my seat to 12A" resolve without the app
  /// re-sending context. A fresh instance therefore starts a clean journey —
  /// [ChatViewModel] creates one per chat session, matching the local
  /// history reset.
  FlightServices({String? sessionId})
      : sessionId =
            sessionId ?? 'tb-${DateTime.now().millisecondsSinceEpoch}';

  final ApiService _apiService = ApiService(
    // Tunnel URL — it changes whenever the tunnel restarts, so this is the
    // one value to update, not a constant spread across the data layer.
    baseUrl: 'https://flying-rug-probably-deemed.trycloudflare.com',
  );

  final String sessionId;

  static const _memberNo = '5QW08HB';
  static const _apiKey = 'njv+D1R/BdIz/U0BS7p1aN+6TodQI5hnKVZw3eThx4Y=';

  Map<String, String> get _headers => {
        'x-member-no': _memberNo,
        'x-session-id': sessionId,
        'x-api-key': _apiKey,
      };

  /// Sends what the passenger typed. [confirm] re-sends the same message as
  /// an approval — the backend treats `{ "message": "book it", "confirm":
  /// true }` exactly like the passenger answering "yes", which is what the
  /// Confirm button does.
  Future<dynamic> getFlightResponse(
    String message, {
    bool confirm = false,
  }) async {
    return _apiService.post(
      '/api/v1/chat',
      headers: _headers,
      body: {
        'message': message,
        if (confirm) 'confirm': true,
      },
    );
  }

  /// Clears the last search and the current booking held against this
  /// session, so the next turn starts the journey over.
  Future<dynamic> resetSession() async {
    return _apiService.post(
      '/api/v1/chat/reset',
      headers: _headers,
      body: const <String, dynamic>{},
    );
  }
}
