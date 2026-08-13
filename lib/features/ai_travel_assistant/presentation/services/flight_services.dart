import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:ai_travel_assistant/core/services/active_account_store.dart';

import '../../../../core/services/api_services/api_service.dart';

/// Fallbacks used when `.env` carries no TravelBuddy entry — a host app
/// embedding this module without one still reaches a working backend, which
/// is also what keeps the widget tests running with no `.env` loaded.
///
/// The tunnel URL changes whenever the tunnel restarts, so `.env` is the
/// place to update it; this constant is only the last resort.
const _fallbackBaseUrl = 'https://truly-wear-tray-assistance.trycloudflare.com';
const _fallbackApiKey = 'njv+D1R/BdIz/U0BS7p1aN+6TodQI5hnKVZw3eThx4Y=';

/// Reads [key] from `.env`, tolerating dotenv never having been loaded.
///
/// `dotenv.env` throws when `load()` was not called, and this service is
/// built eagerly by the chat provider graph — the same reason
/// [SpeechSummaryService] guards its reads this way.
String _envOr(String key, String fallback) {
  if (!dotenv.isInitialized) return fallback;
  final value = dotenv.env[key];
  return (value == null || value.isEmpty) ? fallback : value;
}

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
  ///
  /// [memberNo] is the passenger the journey runs as — the app picks it from
  /// the account switcher on Home (see `activeAccountProvider`), so it is
  /// passed in rather than hardcoded.
  FlightServices({String? sessionId, String? memberNo})
      : sessionId =
            sessionId ?? 'tb-${DateTime.now().millisecondsSinceEpoch}',
        memberNo = memberNo ?? demoAccounts.first.memberNo;

  final ApiService _apiService =
      ApiService(baseUrl: _envOr('TRAVELBUDDY_API_URL', _fallbackBaseUrl));

  final String sessionId;
  final String memberNo;

  /// The base URL actually in use, so a presenter can confirm which backend
  /// the app is pointed at without reading logs.
  static String get resolvedBaseUrl =>
      _envOr('TRAVELBUDDY_API_URL', _fallbackBaseUrl);

  /// Shared with [ConciergeMomentsService], which talks to the same backend
  /// on the trip endpoints rather than `/chat`.
  static String get resolvedApiKey =>
      _envOr('TRAVELBUDDY_API_KEY', _fallbackApiKey);

  Map<String, String> get _headers => {
        'x-member-no': memberNo,
        'x-session-id': sessionId,
        'x-api-key': resolvedApiKey,
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
