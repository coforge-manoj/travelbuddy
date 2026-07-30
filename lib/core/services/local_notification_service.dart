import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// Fires a one-shot local notification a fixed delay after it's scheduled —
/// used to nudge the passenger back into the Journey Concierge chat once a
/// scripted use case wraps up. Deliberately simple: schedules via
/// `Future.delayed` + an immediate `show()`, rather than the plugin's
/// `zonedSchedule`, since this only needs to survive while the app process
/// is alive (foreground or backgrounded) — not a device reboot — so no
/// exact-alarm permissions or timezone setup are needed.
class LocalNotificationService {
  LocalNotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _channelId = 'journey_concierge_reminders';
  static const _channelName = 'Journey Concierge';

  /// Set once by the app shell after its `Navigator` is ready — invoked with
  /// the tapped notification's payload (a `ProactiveScenario.id`) so the app
  /// can open the chat and resume with that use case.
  void Function(String scenarioId)? onScenarioTapped;

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    final initialized = await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        _log.i('[LocalNotificationService] Notification tapped — payload: $payload');
        if (payload != null && payload.isNotEmpty) {
          onScenarioTapped?.call(payload);
        }
      },
    );
    _log.i('[LocalNotificationService] Plugin initialized: $initialized');

    final androidGranted = await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _log.i('[LocalNotificationService] Android notification permission granted: $androidGranted');

    final iosGranted = await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _log.i('[LocalNotificationService] iOS notification permission granted: $iosGranted');
  }

  /// Shows a notification [delay] after this is called — long enough that
  /// the passenger has left the chat, short enough to still feel connected
  /// to the use case they just finished. Callers word [title]/[body] like a
  /// normal message from the concierge. [payload] is handed back via
  /// [onScenarioTapped] on tap.
  void showAfterDelay({
    required String payload,
    required String title,
    required String body,
    Duration delay = const Duration(seconds: 5),
  }) {
    _log.i(
      '[LocalNotificationService] Registered reminder — payload: $payload, '
      'title: "$title", fires in: ${delay.inSeconds}s',
    );
    unawaited(_showAfterDelay(payload: payload, title: title, body: body, delay: delay));
  }

  Future<void> _showAfterDelay({
    required String payload,
    required String title,
    required String body,
    required Duration delay,
  }) async {
    await Future<void>.delayed(delay);
    _log.i('[LocalNotificationService] Delay elapsed — showing notification for payload: $payload');
    try {
      await _plugin.show(
        payload.hashCode & 0x7fffffff,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          // Without these, iOS silently delivers the notification to
          // Notification Center but won't pop up a banner while the app is
          // in the foreground — the exact "not showing at opened
          // application" symptom.
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentList: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
      _log.i('[LocalNotificationService] Notification shown successfully — payload: $payload');
    } catch (error, stackTrace) {
      _log.e(
        '[LocalNotificationService] Failed to show notification — payload: $payload',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

/// Deliberately not `autoDispose`, so it outlives every chat session — the
/// plugin registration and permission grant only need to happen once per
/// app run. Initialization is fire-and-forget: scheduling a reminder before
/// it resolves simply means that first `show()` call is a no-op on some
/// platforms, which is an acceptable trade-off for this demo.
final localNotificationServiceProvider = Provider<LocalNotificationService>((ref) {
  final service = LocalNotificationService();
  unawaited(service.initialize());
  return service;
});
