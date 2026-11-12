import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/home/data/notifications_repository.dart';
import '../utils/route_dispatcher.dart';

/// Provider-agnostic contract for push notification SDKs (FCM, OneSignal, APNs).
///
/// Swap out [StubPushProviderAdapter] for `FcmPushAdapter` or `OneSignalPushAdapter`
/// once the service provider credentials are ready — no UI or API changes required.
abstract class PushProviderAdapter {
  String get providerName;

  Future<void> initialize({required bool requestPermission});
  Future<String?> getToken();
  Future<void> deleteToken();
  Future<void> subscribeToTopic(String topic);
  Future<void> unsubscribeFromTopic(String topic);

  Stream<String> get onTokenRefresh;
  Stream<Map<String, dynamic>> get onForegroundMessage;
  Stream<Map<String, dynamic>> get onNotificationTap;
}

/// Default no-op adapter used until a live Push Service Provider is configured.
class StubPushProviderAdapter implements PushProviderAdapter {
  final _tokenRefreshCtrl = StreamController<String>.broadcast();
  final _foregroundCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _tapCtrl = StreamController<Map<String, dynamic>>.broadcast();

  @override
  String get providerName => 'pending';

  @override
  Future<void> initialize({required bool requestPermission}) async {
    debugPrint('[PushNotificationService] Initialized in provider-pending stub mode.');
  }

  @override
  Future<String?> getToken() async => null;

  @override
  Future<void> deleteToken() async {}

  @override
  Future<void> subscribeToTopic(String topic) async {}

  @override
  Future<void> unsubscribeFromTopic(String topic) async {}

  @override
  Stream<String> get onTokenRefresh => _tokenRefreshCtrl.stream;

  @override
  Stream<Map<String, dynamic>> get onForegroundMessage => _foregroundCtrl.stream;

  @override
  Stream<Map<String, dynamic>> get onNotificationTap => _tapCtrl.stream;
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(ref.watch(notificationsRepositoryProvider));
});

/// Passiton-standard Push Notification coordinator:
/// - Deduplicates device token syncs per session
/// - Buffers terminated-state notification taps until navigator is mounted
/// - Delegates vendor SDK calls to a swappable [PushProviderAdapter]
class PushNotificationService {
  final NotificationsRepository _repo;
  PushProviderAdapter _adapter;

  bool _initialized = false;
  String? _lastSyncedToken;
  Map<String, dynamic>? _pendingTapData;
  final List<StreamSubscription<dynamic>> _subs = [];

  final _foregroundEventsCtrl = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get foregroundEvents => _foregroundEventsCtrl.stream;

  PushNotificationService(this._repo, {PushProviderAdapter? adapter})
      : _adapter = adapter ?? StubPushProviderAdapter();

  String get activeProvider => _adapter.providerName;

  /// Replace the stub adapter with a concrete SDK adapter (e.g., FCM / OneSignal)
  /// without changing callers.
  void setAdapter(PushProviderAdapter adapter) {
    _adapter = adapter;
    _initialized = false;
    _lastSyncedToken = null;
  }

  Future<void> initialize({bool requestPermission = false}) async {
    if (_initialized) return;
    _initialized = true;

    await _adapter.initialize(requestPermission: requestPermission);

    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();

    _subs.add(_adapter.onTokenRefresh.listen(syncTokenToBackend));
    _subs.add(_adapter.onForegroundMessage.listen(_foregroundEventsCtrl.add));
    _subs.add(_adapter.onNotificationTap.listen((data) {
      _pendingTapData = data;
    }));

    final token = await _adapter.getToken();
    if (token != null && token.isNotEmpty) {
      await syncTokenToBackend(token);
    }
  }

  Future<void> syncTokenToBackend(String? token) async {
    if (token == null || token.trim().isEmpty) return;
    if (_lastSyncedToken == token) return;

    try {
      final platform = kIsWeb
          ? 'web'
          : (Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'));
      await _repo.registerDeviceToken(
        token.trim(),
        provider: _adapter.providerName,
        platform: platform,
      );
      _lastSyncedToken = token;
    } catch (e) {
      debugPrint('[PushNotificationService] Failed to sync device token: $e');
    }
  }

  Future<void> clearTokenOnLogout() async {
    _lastSyncedToken = null;
    try {
      await _repo.unregisterDeviceToken();
    } catch (e) {
      debugPrint('[PushNotificationService] Failed to clear backend token: $e');
    }
    try {
      await _adapter.deleteToken();
    } catch (_) {}
  }

  /// Processes any notification tap captured during cold/terminated launch
  /// once the router & home screen are mounted.
  bool processPendingNotification(BuildContext context) {
    final data = _pendingTapData;
    _pendingTapData = null;
    if (data == null || data.isEmpty) return false;

    RouteDispatcher.dispatch(
      context,
      route: data['route']?.toString(),
      type: data['type']?.toString(),
      data: data,
    );
    return true;
  }

  Future<void> subscribeToTopic(String topic) => _adapter.subscribeToTopic(topic);
  Future<void> unsubscribeFromTopic(String topic) => _adapter.unsubscribeFromTopic(topic);
}

