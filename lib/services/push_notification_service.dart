import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';

/// Must be a top-level (or static) function, not a closure — the FCM
/// plugin runs it on a separate background isolate when a data/notification
/// message arrives while the app is backgrounded or terminated. It's a
/// no-op: Android already renders the visible notification straight from
/// the payload's `notification` block without any app code involved; this
/// handler only needs to exist because the plugin requires one to be
/// registered.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Server-sent push notifications (Firebase Cloud Messaging), separate from
/// and additional to the on-device [NotificationService] reminders — a
/// Cloud Function sends these on a schedule (daily math-fact nudges, plus
/// streak-about-to-break warnings), so delivery doesn't depend on the app's
/// process surviving in the background the way local notifications do.
///
/// Static, matching the `AuthService`/`NotificationService` convention.
/// Every public method is best-effort: Firebase being unreachable/
/// unconfigured (e.g. no `google-services.json` yet) must never throw past
/// this class or block app startup — same precedent `AdsService` and
/// `NotificationService` already set.
abstract final class PushNotificationService {
  /// Set once by [initialize] so [_navigateHome] can pop back to the
  /// Home screen from wherever the player happens to be when they tap a
  /// push notification. The app has no named-route table (just
  /// `MaterialApp(home: ...)`), so popping to the first route is the
  /// simplest correct way to land back on Home from a mid-session
  /// `GameScreen`, without introducing a routing library for this one
  /// feature.
  static GlobalKey<NavigatorState>? _navigatorKey;

  static Future<void> initialize(
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    _navigatorKey = navigatorKey;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      // getToken()/onTokenRefresh are flagged deprecated in favor of
      // register()/onRegistered, but that newer API returns a Firebase
      // Installation ID for FCM's newer "Direct Send" flow, not a classic
      // registration token — the Cloud Function's Admin SDK send call
      // (sendEachForMulticast) is built around the classic token. Staying
      // on the deprecated-but-still-functional API deliberately until
      // Direct Send is better established.
      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token != null) {
        await _syncToken(token);
      }
      // ignore: deprecated_member_use
      messaging.onTokenRefresh.listen(_syncToken);

      FirebaseMessaging.onMessageOpenedApp.listen((_) => _navigateHome());
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _navigateHome();
      }
    } catch (_) {
      // Best-effort — e.g. Firebase isn't configured on this build yet, or
      // the player declined the notification permission. Push is a bonus
      // channel on top of the always-on local reminders, never load-bearing.
    }
  }

  static Future<void> _syncToken(String token) async {
    try {
      await AuthService.syncFcmToken(token);
    } catch (_) {
      // Best-effort, same convention as every other sync call here.
    }
  }

  static void _navigateHome() {
    _navigatorKey?.currentState?.popUntil((route) => route.isFirst);
  }
}
