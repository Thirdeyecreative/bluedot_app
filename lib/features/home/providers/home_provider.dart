import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/demo/demo_data.dart';
import '../data/home_repository.dart';
import '../models/banner_model.dart';
import '../models/blog_model.dart';
import '../models/campaign_model.dart';
import '../models/notification_model.dart';

final bannersProvider = FutureProvider<List<AppBanner>>((ref) {
  return ref.watch(homeRepositoryProvider).fetchBanners();
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
  List<AppNotification> build() => DemoData.notifications;

  int get unreadCount => state.where((n) => !n.read).length;

  void markAllRead() => state = [for (final n in state) n.copyWith(read: true)];

  void markRead(String id) =>
      state = [for (final n in state) if (n.id == id) n.copyWith(read: true) else n];
}

final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).where((n) => !n.read).length;
});
