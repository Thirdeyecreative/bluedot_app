import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'push_notification_service.dart';

/// Top-level background message handler required by `firebase_messaging`.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message received: ${message.messageId}');
}

/// Concrete [PushProviderAdapter] backed by Firebase Cloud Messaging (FCM).
class FcmPushAdapter implements PushProviderAdapter {
  final FirebaseMessaging _messaging;

  final _tokenRefreshCtrl = StreamController<String>.broadcast();
  final _foregroundCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _tapCtrl = StreamController<Map<String, dynamic>>.broadcast();

  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;
  String? _currentToken;

  FcmPushAdapter({FirebaseMessaging? messaging})
      : _messaging = messaging ?? FirebaseMessaging.instance;

  @override
  String get providerName => 'fcm';

  @override
  Future<void> initialize({required bool requestPermission}) async {
    if (requestPermission) {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    await _tokenSub?.cancel();
    await _foregroundSub?.cancel();
    await _openedAppSub?.cancel();

    _tokenSub = _messaging.onRegistered.listen((token) {
      _currentToken = token;
      _tokenRefreshCtrl.add(token);
    });

    _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
      _foregroundCtrl.add(_messageToMap(message));
    });

    _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _tapCtrl.add(_messageToMap(message));
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _tapCtrl.add(_messageToMap(initialMessage));
    }
  }

  Map<String, dynamic> _messageToMap(RemoteMessage message) {
    return <String, dynamic>{
      ...message.data,
      if (message.notification?.title != null)
        'title': message.notification!.title,
      if (message.notification?.body != null)
        'body': message.notification!.body,
    };
  }

  @override
  Future<String?> getToken() async {
    if (_currentToken != null) return _currentToken;
    await _messaging.register();
    return _currentToken;
  }

  @override
  Future<void> deleteToken() async {
    _currentToken = null;
    await _messaging.unregister();
  }

  @override
  Future<void> subscribeToTopic(String topic) =>
      _messaging.subscribeToTopic(topic);

  @override
  Future<void> unsubscribeFromTopic(String topic) =>
      _messaging.unsubscribeFromTopic(topic);

  @override
  Stream<String> get onTokenRefresh => _tokenRefreshCtrl.stream;

  @override
  Stream<Map<String, dynamic>> get onForegroundMessage => _foregroundCtrl.stream;

  @override
  Stream<Map<String, dynamic>> get onNotificationTap => _tapCtrl.stream;
}

