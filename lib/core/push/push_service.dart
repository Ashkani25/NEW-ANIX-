import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../online/online_service.dart';

/// Remote push notifications (Firebase Cloud Messaging), OFF unless the build turns it on.
///
/// Build flags (all public client config, from repo Variables -> --dart-define, see docs/PUSH_NOTIFICATIONS.md):
///   FCM_ENABLED=true, FCM_API_KEY, FCM_APP_ID, FCM_SENDER_ID, FCM_PROJECT_ID.
/// Firebase is initialised from these options in Dart, so no google-services.json / Gradle plugin is needed. Without
/// them nothing here touches Firebase and the app behaves exactly as before (in-app Realtime banners + local reminders).
///
/// Server side: the token goes to core `nx_push_register` (device_tokens); chat messages, calls, tournament / match
/// notifications and game invites reach `nx_push_notify_batch` -> Edge Function push-send -> FCM HTTP v1 (needs the
/// FCM_SERVICE_ACCOUNT function secret). The system tray shows them while the app is in the background; a tap opens
/// `data.route`. In the foreground FCM messages are ignored: the in-app watchers already show the same events.
class PushService extends ChangeNotifier {
  PushService._();
  static final PushService instance = PushService._();

  static const bool _flag = bool.fromEnvironment('FCM_ENABLED');
  static const String _apiKey = String.fromEnvironment('FCM_API_KEY');
  static const String _appId = String.fromEnvironment('FCM_APP_ID');
  static const String _senderId = String.fromEnvironment('FCM_SENDER_ID');
  static const String _projectId = String.fromEnvironment('FCM_PROJECT_ID');

  /// The build carries the flag and every Firebase option (pure, unit-tested).
  static bool isConfigured({
    bool flag = _flag,
    String apiKey = _apiKey,
    String appId = _appId,
    String senderId = _senderId,
    String projectId = _projectId,
  }) =>
      flag && apiKey.isNotEmpty && appId.isNotEmpty && senderId.isNotEmpty && projectId.isNotEmpty;

  static bool get configured => isConfigured();

  /// True once a device token is registered for the signed-in account (local tray duplicates can be skipped then).
  bool get active => _registeredFor != null;

  /// Opens an app route (set by the app widget).
  void Function(String route)? onOpen;

  bool _started = false;
  bool _firebaseReady = false;
  String? _token;
  String? _registeredFor;
  String Function() _locale = () => 'fa';
  OnlineService? _online;
  final List<StreamSubscription<dynamic>> _subs = <StreamSubscription<dynamic>>[];

  /// Android channels push-send addresses (`android.notification.channel_id`).
  static const List<AndroidNotificationChannel> channels = <AndroidNotificationChannel>[
    AndroidNotificationChannel('messages', 'Messages', importance: Importance.high),
    AndroidNotificationChannel('calls', 'Calls', importance: Importance.max),
    AndroidNotificationChannel('matches', 'Matches & tournaments', importance: Importance.high),
    AndroidNotificationChannel('social', 'Social', importance: Importance.defaultImportance),
    AndroidNotificationChannel('general', 'General', importance: Importance.defaultImportance),
  ];

  /// Routes a tap may open: in-app paths only.
  static String? routeOf(Map<String, dynamic> data) {
    final String r = '${data['route'] ?? ''}';
    if (r.isEmpty || !r.startsWith('/') || r.startsWith('//')) return null;
    return r;
  }

  Future<void> start({required String Function() locale}) async {
    if (_started || !configured || kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _started = true;
    _locale = locale;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: _apiKey,
            appId: _appId,
            messagingSenderId: _senderId,
            projectId: _projectId,
          ),
        );
      }
      _firebaseReady = true;
      final AndroidFlutterLocalNotificationsPlugin? android = FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      for (final AndroidNotificationChannel ch in channels) {
        await android?.createNotificationChannel(ch);
      }
      final FirebaseMessaging m = FirebaseMessaging.instance;
      await m.requestPermission();
      _subs.add(m.onTokenRefresh.listen((String t) {
        _token = t;
        _registeredFor = null;
        unawaited(sync());
      }));
      _subs.add(FirebaseMessaging.onMessageOpenedApp.listen(_opened));
      final RemoteMessage? initial = await m.getInitialMessage();
      if (initial != null) _opened(initial);
    } catch (e) {
      debugPrint('push: firebase unavailable: $e');
      _firebaseReady = false;
    }
    final OnlineService? o = OnlineService.current;
    if (o != null) {
      _online = o;
      o.addListener(_onAuth);
    }
    await sync();
  }

  void _onAuth() => unawaited(sync());

  void _opened(RemoteMessage msg) {
    final String? r = routeOf(msg.data);
    if (r != null) onOpen?.call(r);
  }

  /// Registers this device for the signed-in (non-guest) account; drops the token on sign-out so the previous
  /// account stops receiving pushes on this phone.
  Future<void> sync() async {
    if (!_firebaseReady) return;
    final OnlineService? o = OnlineService.current;
    final String? uid = (o != null && o.isOnline && !o.isGuest) ? o.uid : null;
    try {
      if (uid == null) {
        if (_registeredFor != null || _token != null) {
          _registeredFor = null;
          _token = null;
          await FirebaseMessaging.instance.deleteToken();
          notifyListeners();
        }
        return;
      }
      if (_registeredFor == uid) return;
      _token ??= await FirebaseMessaging.instance.getToken();
      final String? t = _token;
      if (t == null || o?.client == null) return;
      final dynamic ok = await o!.client!
          .rpc('nx_push_register', params: <String, dynamic>{'p_token': t, 'p_platform': 'android', 'p_locale': _locale()})
          .timeout(const Duration(seconds: 15));
      if (ok == true) {
        _registeredFor = uid;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('push: register: $e');
    }
  }

  void stop() {
    for (final StreamSubscription<dynamic> s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    _online?.removeListener(_onAuth);
    _online = null;
    _started = false;
  }
}
