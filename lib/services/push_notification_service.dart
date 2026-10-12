import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PushNotice {
  const PushNotice(this.title, this.body, {this.opened = false});
  final String title;
  final String body;
  final bool opened;
}

/// Firebase stays disabled until configured AND the reader opts in.
class PushNotificationService extends ChangeNotifier {
  PushNotificationService._();
  static final instance = PushNotificationService._();
  static const topic = 'library-announcements-v1';
  static const _preference = 'push_announcements_enabled';
  static const _project = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _sender = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _androidId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const _iosId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const _androidKey = String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  static const _iosKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
  static bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;
  static bool get configured =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || _ios) &&
      _project.isNotEmpty &&
      _sender.isNotEmpty &&
      (_ios
          ? _iosId.isNotEmpty && _iosKey.isNotEmpty
          : _androidId.isNotEmpty && _androidKey.isNotEmpty);

  final notice = ValueNotifier<PushNotice?>(null);
  bool enabled = false;
  bool busy = false;
  bool _listening = false;
  Future<void>? _initializing;

  Future<void> _initialize() =>
      _initializing ??= _initializeFirebase().catchError((Object error) {
        _initializing = null;
        throw error;
      });

  Future<void> _initializeFirebase() async {
    if (!configured) throw StateError('Push notifications are not configured');
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
          options: FirebaseOptions(
        apiKey: _ios ? _iosKey : _androidKey,
        appId: _ios ? _iosId : _androidId,
        messagingSenderId: _sender,
        projectId: _project,
        iosBundleId: _ios ? 'com.athariyyah.appname' : null,
      ));
    }
    if (_listening) return;
    _listening = true;
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification != null) {
        notice.value =
            PushNotice(notification.title ?? '', notification.body ?? '');
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen(_opened);
    FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      if (enabled) unawaited(_subscribe().catchError((Object _) {}));
    }, onError: (Object _) {});
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _opened(initial);
  }

  void _opened(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      notice.value = PushNotice(
          notification.title ?? '', notification.body ?? '',
          opened: true);
    }
  }

  Future<void> _subscribe() async {
    // Apple must issue its token before Firebase topic registration.
    if (_ios) {
      for (var attempt = 0; attempt < 10; attempt++) {
        if (await FirebaseMessaging.instance.getAPNSToken() != null) break;
        if (attempt == 9) {
          throw StateError(
              'Apple push registration is not ready. Try again shortly.');
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    await FirebaseMessaging.instance.subscribeToTopic(topic);
  }

  Future<void> restore() async {
    if (busy) return;
    busy = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled = prefs.getBool(_preference) ?? false;
      if (!configured || !enabled) return;
      await _initialize();
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        await messaging.unsubscribeFromTopic(topic);
        await messaging.setAutoInitEnabled(false);
        await messaging.deleteToken();
        await prefs.setBool(_preference, false);
        enabled = false;
      } else if (settings.authorizationStatus ==
              AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await _subscribe();
      }
    } catch (_) {
      // Offline/device registration is retried on the next resume.
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> setEnabled(bool value) async {
    if (busy) return;
    busy = true;
    notifyListeners();
    try {
      await _initialize();
      final messaging = FirebaseMessaging.instance;
      if (value) {
        final settings = await messaging.requestPermission(
            alert: true, badge: false, sound: true);
        if (settings.authorizationStatus != AuthorizationStatus.authorized &&
            settings.authorizationStatus != AuthorizationStatus.provisional) {
          throw StateError(
              'Notification permission was not granted. You can enable it in your phone settings.');
        }
        await messaging.setAutoInitEnabled(true);
        await _subscribe();
      } else {
        await messaging.unsubscribeFromTopic(topic);
        await messaging.setAutoInitEnabled(false);
        await messaging.deleteToken();
      }
      await (await SharedPreferences.getInstance()).setBool(_preference, value);
      enabled = value;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
