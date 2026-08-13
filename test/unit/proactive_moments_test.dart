import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/core/services/api_services/api_service.dart';
import 'package:ai_travel_assistant/core/services/active_account_store.dart';
import 'package:ai_travel_assistant/core/services/local_notification_service.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/services/concierge_moments_service.dart';

/// Records calls and replays canned envelopes, so the service's unwrapping
/// and its failure handling can both be exercised without a backend.
class _FakeApiService implements ApiService {
  _FakeApiService({this.getResponse, this.throwOnGet = false});

  final dynamic getResponse;
  final bool throwOnGet;

  final List<String> getPaths = [];
  final List<({String path, dynamic body})> posts = [];

  @override
  String get baseUrl => 'https://example.test';

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
  }) async {
    getPaths.add(endpoint);
    if (throwOnGet) throw Exception('tunnel down');
    return getResponse;
  }

  @override
  Future<dynamic> post(
    String endpoint, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    posts.add((path: endpoint, body: body));
    return {'ok': true};
  }
}

void main() {
  group('ConciergeMomentsService — push copy by seq', () {
    test('unwraps the ok/data envelope and returns the push string', () async {
      final api = _FakeApiService(getResponse: {
        'ok': true,
        'data': {
          'seq': 2,
          'stage': 'inspire',
          'push': '✈️ Award seats just opened for all 4 of you.',
        },
      });
      final service = ConciergeMomentsService(memberNo: '9BX37KM', apiService: api);

      final copy = await service.pushCopyFor(
        ConciergeMomentsService.awardAlertUseCase,
      );

      expect(copy, '✈️ Award seats just opened for all 4 of you.');
      // By seq, not via /pending: the award alert is an inspire-stage moment
      // and the trip sits at `book`, so /pending would not return it.
      expect(api.getPaths.single, '/api/v1/usecases/2');
    });

    test('an unreachable backend yields null rather than throwing', () async {
      // A demo that loses its proactive nudge must still book a flight.
      final service = ConciergeMomentsService(
        memberNo: '9BX37KM',
        apiService: _FakeApiService(throwOnGet: true),
      );

      expect(await service.pushCopyFor(2), isNull);
    });

    test('an ok:false envelope yields null', () async {
      final service = ConciergeMomentsService(
        memberNo: '9BX37KM',
        apiService: _FakeApiService(getResponse: {
          'ok': false,
          'error': {'code': 'not_found', 'message': 'no such use case'},
        }),
      );

      expect(await service.pushCopyFor(99), isNull);
    });
  });

  group('ConciergeMomentsService — pending moments', () {
    test('finds the document moment by seq in a pending list', () async {
      final api = _FakeApiService(getResponse: {
        'ok': true,
        'data': [
          {'seq': 3, 'stage': 'book', 'push': "🛂 Before you book: Leo…"},
          {'seq': 4, 'stage': 'book', 'push': '🔗 Your DFW connection…'},
        ],
      });
      final service = ConciergeMomentsService(
        memberNo: '9BX37KM',
        ownsSeededTrip: true,
        apiService: api,
      );

      final copy = await service.pendingPushCopyFor(
        ConciergeMomentsService.documentReadinessUseCase,
      );

      expect(copy, startsWith('🛂'));
      expect(api.getPaths.single, '/api/v1/trips/1/pending');
    });

    test('a moment already delivered is simply absent', () async {
      // This is what stops the interrupt firing twice in one demo run.
      final service = ConciergeMomentsService(
        memberNo: '9BX37KM',
        ownsSeededTrip: true,
        apiService: _FakeApiService(getResponse: {
          'ok': true,
          'data': [
            {'seq': 4, 'push': '🔗 Your DFW connection…'},
          ],
        }),
      );

      expect(await service.pendingPushCopyFor(3), isNull);
    });

    test('a member who does not own the trip is never told about it', () async {
      // Regression: observed on device. The trip endpoints ignore
      // `x-member-no`, so `/trips/1/pending` happily returns the Bennett
      // family's passport warning to anyone who asks — and it appeared in
      // Elena's checkout, a passenger with no children and no trip to Japan.
      final api = _FakeApiService(getResponse: {
        'ok': true,
        'data': [
          {'seq': 3, 'push': "🛂 Before you book: Leo…"},
        ],
      });
      final elena = ConciergeMomentsService(
        memberNo: '5QW08HB',
        ownsSeededTrip: false,
        apiService: api,
      );

      expect(await elena.pendingPushCopyFor(3), isNull);
      // Not merely filtered — the call is never made.
      expect(api.getPaths, isEmpty);
    });

    test('only Marcus Bennett owns the seeded trip', () {
      final owners =
          demoAccounts.where((a) => a.ownsSeededTrip).map((a) => a.memberNo);
      expect(owners, ['9BX37KM']);
    });

    test('marking delivered posts the use case and channel', () async {
      final api = _FakeApiService(getResponse: {'ok': true, 'data': []});
      final service = ConciergeMomentsService(memberNo: '9BX37KM', apiService: api);

      await service.markDelivered(3, channel: 'chat');

      expect(api.posts.single.path, '/api/v1/trips/1/notifications');
      expect(api.posts.single.body, {'useCase': 3, 'channel': 'chat'});
    });
  });

  group('live notification payload', () {
    test('round-trips the copy through the payload prefix', () {
      // The copy travels inside the payload so the tap needs no second fetch.
      const copy = '✈️ Award seats just opened for all 4 of you.';
      const payload = '${LocalNotificationService.liveMomentPayloadPrefix}$copy';

      expect(payload.startsWith(LocalNotificationService.liveMomentPayloadPrefix),
          isTrue);
      expect(
        payload.substring(
          LocalNotificationService.liveMomentPayloadPrefix.length,
        ),
        copy,
      );
    });

    test('a scripted scenario id is not mistaken for a live moment', () {
      // Scripted catalogue ids must keep their existing behaviour.
      expect(
        'inspire-deal-alert'
            .startsWith(LocalNotificationService.liveMomentPayloadPrefix),
        isFalse,
      );
    });
  });
}
