import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // FlutterAppDelegate conforms to FlutterAppLifeCycleProvider, which is
    // itself a UNUserNotificationCenterDelegate that fans out to registered
    // plugins (see FlutterPlugin.h) — but Flutter does NOT register it
    // automatically. Without this, UNUserNotificationCenter never calls
    // willPresent for a foregrounded app, so flutter_local_notifications'
    // notifications silently only show once the app is backgrounded.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
