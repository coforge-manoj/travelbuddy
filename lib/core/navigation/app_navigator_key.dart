import 'package:flutter/material.dart';

/// Shared navigator key so app-level callbacks that don't have a
/// `BuildContext` of their own — e.g. `LocalNotificationService`'s
/// notification-tap handler — can still push a route.
final rootNavigatorKey = GlobalKey<NavigatorState>();
