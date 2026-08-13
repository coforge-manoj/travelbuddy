import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_travel_assistant/core/services/active_account_store.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/services/flight_services.dart';

import '../../../../core/services/api_services/api_service.dart';

/// The proactive half of the TravelBuddy backend: the 12 playbook use cases,
/// which of them are due for the current trip, and marking one delivered.
///
/// Separate from [FlightServices] because these carry no `x-session-id` —
/// they are about the *trip*, not a conversation — and because a failure here
/// must never take the chat down with it. Every method returns `null` rather
/// than throwing: a demo that loses its proactive nudge should still book a
/// flight.
class ConciergeMomentsService {
  ConciergeMomentsService({
    String? memberNo,
    this.ownsSeededTrip = false,
    ApiService? apiService,
  })  : memberNo = memberNo ?? '',
        _apiService =
            apiService ?? ApiService(baseUrl: FlightServices.resolvedBaseUrl);

  final ApiService _apiService;
  final String memberNo;

  /// Whether [memberNo] actually owns [tripId].
  ///
  /// The trip endpoints ignore `x-member-no`, so this is the only thing
  /// stopping the Bennett family's passport warning appearing in another
  /// passenger's checkout.
  final bool ownsSeededTrip;

  /// The seeded Bennett trip. The backend holds exactly one
  /// (`/health` reports `trips: 1`), so this is a constant rather than a
  /// lookup — if that ever changes, this is the single place to fix.
  static const tripId = 1;

  /// The award-seats alert that opens Journey A.
  static const awardAlertUseCase = 2;

  /// The document-readiness moment that interrupts the Bennett checkout.
  static const documentReadinessUseCase = 3;

  Map<String, String> get _headers => {
        'x-api-key': FlightServices.resolvedApiKey,
        if (memberNo.isNotEmpty) 'x-member-no': memberNo,
      };

  /// Push copy for one use case, by sequence number.
  ///
  /// Deliberately fetched by `seq` rather than read from `/trips/1/pending`:
  /// `pending` only returns moments due at the trip's *current* stage, so the
  /// inspire-stage award alert would need the trip moved to fetch it. By seq
  /// it comes back whatever stage the trip is in — no stage manipulation, and
  /// nothing about the trip record is disturbed.
  Future<String?> pushCopyFor(int seq) async {
    try {
      final response = await _apiService.get(
        '/api/v1/usecases/$seq',
        headers: _headers,
      );
      final data = _data(response);
      final push = data?['push'];
      return (push is String && push.trim().isNotEmpty) ? push.trim() : null;
    } catch (_) {
      return null;
    }
  }

  /// Push copy for a use case that is *currently due* and undelivered, or
  /// `null` if it has already been sent or the stage has moved past it.
  ///
  /// Used for the document interrupt, where "has this already fired?" is the
  /// question — unlike [pushCopyFor], which ignores delivery state.
  Future<String?> pendingPushCopyFor(int seq) async {
    if (!ownsSeededTrip) return null;
    try {
      final response = await _apiService.get(
        '/api/v1/trips/$tripId/pending',
        headers: _headers,
      );
      final data = _data(response);
      final rows = data is List ? data : (data?['pending'] as List?);
      if (rows == null) return null;

      for (final row in rows.whereType<Map>()) {
        if (row['seq'] == seq) {
          final push = row['push'];
          return (push is String && push.trim().isNotEmpty)
              ? push.trim()
              : null;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Marks a use case delivered so it drops out of `pending` and cannot fire
  /// twice in one run. Best-effort: the moment has already been shown by the
  /// time this is called, so a failure here is not worth surfacing.
  Future<void> markDelivered(int seq, {String channel = 'push'}) async {
    try {
      await _apiService.post(
        '/api/v1/trips/$tripId/notifications',
        headers: _headers,
        body: {'useCase': seq, 'channel': channel},
      );
    } catch (_) {
      // Intentionally ignored — see the doc comment.
    }
  }

  /// Unwraps the `{ ok, data }` envelope every endpoint returns.
  static dynamic _data(dynamic response) {
    if (response is! Map) return null;
    if (response['ok'] == false) return null;
    return response['data'];
  }
}

final conciergeMomentsServiceProvider =
    Provider.family<ConciergeMomentsService, String>((ref, memberNo) {
  final account = demoAccounts.firstWhere(
    (a) => a.memberNo == memberNo,
    orElse: () => demoAccounts.first,
  );
  return ConciergeMomentsService(
    memberNo: memberNo,
    ownsSeededTrip: account.ownsSeededTrip,
  );
});
