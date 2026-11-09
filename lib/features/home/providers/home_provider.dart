import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_config.dart';
import '../../../core/demo/demo_data.dart';
import '../../../core/services/api_client.dart';
import '../data/home_repository.dart';
import '../models/blog_model.dart';
import '../models/campaign_model.dart';
import '../models/notification_model.dart';

final homeFeedProvider = FutureProvider<HomeFeedData>((ref) {
  return ref.watch(homeRepositoryProvider).fetchHomeFeed();
});

final blogsProvider = FutureProvider<List<BlogPost>>((ref) {
  return ref.watch(homeRepositoryProvider).fetchBlogs();
});

final campaignsProvider = FutureProvider<List<Campaign>>((ref) {
  return ref.watch(homeRepositoryProvider).fetchCampaigns();
});

final blogDetailProvider = FutureProvider.family<BlogPost, String>((ref, slug) {
  return ref.watch(homeRepositoryProvider).fetchBlogBySlug(slug);
});

// In-memory notification feed with read/unread state.
final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<AppNotification>>(NotificationsNotifier.new);

class NotificationsNotifier extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() {
    _loadLiveNotifications();
    return DemoData.notifications;
  }

  Future<void> _loadLiveNotifications() async {
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.get(ApiConfig.notifications, requireAuth: true);
      if (res is Map<String, dynamic> && res.containsKey('data')) {
        final list = res['data'] as List<dynamic>? ?? [];
        state = list.map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      // Fallback gracefully to DemoData if offline or unauthenticated
    }
  }

  Future<void> refresh() async {
    await _loadLiveNotifications();
  }

  int get unreadCount => state.where((n) => !n.read).length;

  Future<void> markAllRead() async {
    state = [for (final n in state) n.copyWith(read: true)];
    try {
      final client = ref.read(apiClientProvider);
      await client.post(ApiConfig.markAllNotificationsRead, requireAuth: true);
    } catch (_) {}
  }

  Future<void> markRead(String id) async {
    state = [for (final n in state) if (n.id == id) n.copyWith(read: true) else n];
    try {
      final client = ref.read(apiClientProvider);
      await client.patch(ApiConfig.markNotificationRead(id), requireAuth: true);
    } catch (_) {}
  }
}

final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).where((n) => !n.read).length;
});
