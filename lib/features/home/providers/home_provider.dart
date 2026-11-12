import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/home_repository.dart';
import '../data/notifications_repository.dart';
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

class NotificationsState {
  final List<AppNotification> items;
  final int unreadCount;
  final int total;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String selectedCategory;
  final String? error;

  const NotificationsState({
    this.items = const [],
    this.unreadCount = 0,
    this.total = 0,
    this.hasMore = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.selectedCategory = 'all',
    this.error,
  });

  NotificationsState copyWith({
    List<AppNotification>? items,
    int? unreadCount,
    int? total,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    String? selectedCategory,
    String? error,
    bool clearError = false,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, NotificationsState>(NotificationsNotifier.new);

class NotificationsNotifier extends Notifier<NotificationsState> {
  static const int _pageSize = 20;

  @override
  NotificationsState build() {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const NotificationsState();
    }

    Future.microtask(() => _loadInitial(category: 'all'));
    return const NotificationsState(isLoading: true);
  }

  NotificationsRepository get _repo => ref.read(notificationsRepositoryProvider);

  Future<void> _loadInitial({required String category}) async {
    state = state.copyWith(
      selectedCategory: category,
      isLoading: true,
      clearError: true,
    );

    try {
      final res = await _repo.fetchNotifications(
        skip: 0,
        limit: _pageSize,
        category: category,
      );
      state = state.copyWith(
        items: res.items,
        unreadCount: res.unreadCount,
        total: res.total,
        hasMore: res.hasMore,
        isLoading: false,
        isLoadingMore: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: 'Unable to load notifications. Pull down to retry.',
      );
    }
  }

  Future<void> refresh() async {
    if (ref.read(currentUserProvider) == null) return;
    await _loadInitial(category: state.selectedCategory);
  }

  Future<void> setCategory(String category) async {
    if (state.selectedCategory == category && !state.isLoading && state.error == null) {
      return;
    }
    await _loadInitial(category: category);
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    if (ref.read(currentUserProvider) == null) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final res = await _repo.fetchNotifications(
        skip: state.items.length,
        limit: _pageSize,
        category: state.selectedCategory,
      );
      final existingIds = state.items.map((e) => e.id).toSet();
      final appended = [
        ...state.items,
        ...res.items.where((e) => !existingIds.contains(e.id)),
      ];
      state = state.copyWith(
        items: appended,
        unreadCount: res.unreadCount,
        total: res.total,
        hasMore: res.hasMore,
        isLoadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> markAllRead() async {
    if (state.items.isEmpty && state.unreadCount == 0) return;

    final previousState = state;
    state = state.copyWith(
      items: [for (final n in state.items) n.copyWith(read: true)],
      unreadCount: 0,
    );

    try {
      await _repo.markAllRead();
    } catch (_) {
      state = previousState;
    }
  }

  Future<void> markRead(String id) async {
    final targetIndex = state.items.indexWhere((n) => n.id == id);
    if (targetIndex == -1 || state.items[targetIndex].read) return;

    final previousState = state;
    final updatedItems = [
      for (final n in state.items)
        if (n.id == id) n.copyWith(read: true) else n,
    ];
    final nextUnread = (state.unreadCount - 1).clamp(0, 999999);

    state = state.copyWith(
      items: updatedItems,
      unreadCount: nextUnread,
    );

    try {
      await _repo.markRead(id);
    } catch (_) {
      state = previousState;
    }
  }

  Future<bool> deleteNotification(String id) async {
    final targetIndex = state.items.indexWhere((n) => n.id == id);
    if (targetIndex == -1) return false;
    final target = state.items[targetIndex];
    if (target.isBroadcast) return false;

    final previousState = state;
    final nextItems = List<AppNotification>.of(state.items)..removeAt(targetIndex);
    final nextUnread = target.read ? state.unreadCount : (state.unreadCount - 1).clamp(0, 999999);

    state = state.copyWith(
      items: nextItems,
      unreadCount: nextUnread,
      total: (state.total - 1).clamp(0, 999999),
    );

    try {
      await _repo.deleteNotification(id);
      return true;
    } catch (_) {
      state = previousState;
      return false;
    }
  }
}

final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).unreadCount;
});
