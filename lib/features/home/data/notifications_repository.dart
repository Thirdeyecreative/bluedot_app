import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_config.dart';
import '../../../core/services/api_client.dart';
import '../models/notification_model.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(apiClientProvider));
});

class NotificationsRepository {
  final ApiClient _api;
  NotificationsRepository(this._api);

  Future<PaginatedNotificationsResponse> fetchNotifications({
    int skip = 0,
    int limit = 20,
    String? category,
  }) async {
    final query = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    if (category != null && category.isNotEmpty && category != 'all') {
      query['category'] = category;
    }

    final res = await _api.get(
      ApiConfig.notifications,
      requireAuth: true,
      query: query,
    );

    if (res is Map<String, dynamic>) {
      return PaginatedNotificationsResponse.fromJson(res);
    }
    return const PaginatedNotificationsResponse(
      items: [],
      unreadCount: 0,
      total: 0,
      hasMore: false,
    );
  }

  Future<void> markRead(String id) async {
    await _api.patch(ApiConfig.markNotificationRead(id), requireAuth: true);
  }

  Future<void> markAllRead() async {
    await _api.post(ApiConfig.markAllNotificationsRead, requireAuth: true);
  }

  Future<void> deleteNotification(String id) async {
    await _api.delete(ApiConfig.deleteNotification(id), requireAuth: true);
  }

  Future<void> registerDeviceToken(
    String token, {
    String provider = 'pending',
    String? platform,
  }) async {
    await _api.post(
      ApiConfig.notificationDeviceToken,
      body: {
        'token': token,
        'provider': provider,
        if (platform != null) 'platform': platform,
      },
      requireAuth: true,
    );
  }

  Future<void> unregisterDeviceToken() async {
    await _api.delete(ApiConfig.notificationDeviceToken, requireAuth: true);
  }

  Future<Map<String, bool>> fetchPreferences() async {
    final res = await _api.get(ApiConfig.notificationPreferences, requireAuth: true);
    if (res is Map<String, dynamic> && res['data'] is Map) {
      final raw = res['data'] as Map;
      return raw.map((k, v) => MapEntry(k.toString(), v == true));
    }
    return const {
      'push_enabled': true,
      'drive_updates': true,
      'badge_updates': true,
      'donation_alerts': true,
      'announcements': true,
      'email_enabled': true,
    };
  }

  Future<Map<String, bool>> updatePreferences(Map<String, bool> updates) async {
    final res = await _api.put(
      ApiConfig.notificationPreferences,
      data: updates,
      requireAuth: true,
    );
    if (res is Map<String, dynamic> && res['data'] is Map) {
      final raw = res['data'] as Map;
      return raw.map((k, v) => MapEntry(k.toString(), v == true));
    }
    return updates;
  }
}

