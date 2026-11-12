import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/route_dispatcher.dart';
import '../models/notification_model.dart';
import '../providers/home_provider.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  static const List<({String key, String label})> _tabs = [
    (key: 'all', label: 'All'),
    (key: 'drives', label: 'Drives & Events'),
    (key: 'badges', label: 'Badges & Trees'),
    (key: 'donations', label: 'Donations'),
    (key: 'announcements', label: 'Announcements'),
  ];

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(notificationsProvider.notifier).refresh();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 220;
    if (_scrollController.position.pixels >= threshold) {
      ref.read(notificationsProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifState = ref.watch(notificationsProvider);
    final items = notifState.items;
    final unread = notifState.unreadCount;

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: const BackButton(),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () => ref.read(notificationsProvider.notifier).markAllRead(),
              child: const Text(
                'Mark all read',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          IconButton(
            tooltip: 'Notification settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go('/profile/settings'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              itemCount: _tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final tab = _tabs[index];
                final isSelected = notifState.selectedCategory == tab.key;
                return ChoiceChip(
                  label: Text(tab.label),
                  selected: isSelected,
                  onSelected: (_) => ref.read(notificationsProvider.notifier).setCategory(tab.key),
                  selectedColor: AppColors.primaryBlue.withAlpha(24),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: isSelected ? AppColors.primaryBlue : AppColors.borderLight,
                  ),
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.primaryBlue : AppColors.textMedium,
                  ),
                  visualDensity: VisualDensity.compact,
                  showCheckmark: false,
                );
              },
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
        color: AppColors.primaryBlue,
        child: _buildBody(notifState, items, unread),
      ),
    );
  }

  Widget _buildBody(NotificationsState notifState, List<AppNotification> items, int unread) {
    if (notifState.isLoading && items.isEmpty) {
      return const _NotificationsSkeleton();
    }

    if (notifState.error != null && items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.62,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.slateBlue.withAlpha(140)),
                    const SizedBox(height: 16),
                    Text(
                      notifState.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMedium, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => ref.read(notificationsProvider.notifier).refresh(),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.62,
            child: _EmptyNotifications(category: notifState.selectedCategory),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 130),
      itemCount: items.length + 1 + (notifState.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0) {
          if (unread <= 0) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: Text(
              '$unread unread',
              style: const TextStyle(
                color: AppColors.textMedium,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }

        final itemIndex = index - 1;
        if (itemIndex >= items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final item = items[itemIndex];
        final card = _NotificationCard(item: item)
            .animate()
            .fadeIn(delay: (35 * (itemIndex.clamp(0, 8))).ms)
            .slideY(begin: 0.04, end: 0, delay: (35 * (itemIndex.clamp(0, 8))).ms);

        if (item.isBroadcast) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: card,
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Dismissible(
            key: ValueKey(item.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: AppColors.errorRed.withAlpha(24),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: AppColors.errorRed),
            ),
            onDismissed: (_) async {
              final deleted = await ref.read(notificationsProvider.notifier).deleteNotification(item.id);
              if (!deleted && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not dismiss notification. Please try again.')),
                );
              }
            },
            child: card,
          ),
        );
      },
    );
  }
}

class _NotificationsSkeleton extends StatelessWidget {
  const _NotificationsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Notification title placeholder', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    SizedBox(height: 6),
                    Text('Notification body description line placeholder for loading state', style: TextStyle(fontSize: 12.5)),
                    SizedBox(height: 8),
                    Text('2h ago', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  final String category;
  const _EmptyNotifications({required this.category});

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (category) {
      'drives' => 'Upcoming plantation drive reminders and check-in updates will appear here.',
      'badges' => 'Badge unlocks, tree tagging milestones, and volunteer certificates will appear here.',
      'donations' => 'Your 80G tax receipt alerts and campaign milestones will appear here.',
      'announcements' => 'Community updates and announcements from BlueDot will appear here.',
      _ => 'Drive reminders, badge unlocks, donation alerts, and campaign updates will appear here.',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined, size: 64, color: AppColors.slateBlue.withAlpha(120)),
            const SizedBox(height: 16),
            const Text(
              "You're all caught up",
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textDark),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMedium, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  final AppNotification item;
  const _NotificationCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = _styleFor(item.type);

    return GestureDetector(
      onTap: () {
        ref.read(notificationsProvider.notifier).markRead(item.id);
        RouteDispatcher.dispatch(
          context,
          route: item.route,
          type: item.rawType,
          data: item.data,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: item.read ? AppColors.surfaceCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: item.read ? AppColors.borderLight : style.color.withAlpha(70)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: style.color.withAlpha(22), borderRadius: BorderRadius.circular(12)),
              child: Icon(style.icon, color: style.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: item.read ? FontWeight.w600 : FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      if (!item.read)
                        Container(
                          margin: const EdgeInsets.only(left: 8, top: 4),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: AppColors.primaryBlue, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(item.body, style: const TextStyle(color: AppColors.textMedium, fontSize: 12.5, height: 1.4)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(item.timeLabel, style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
                      if (item.isBroadcast) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withAlpha(18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Announcement',
                            style: TextStyle(
                              color: AppColors.primaryBlue,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _NotifStyle _styleFor(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.drive:
        return const _NotifStyle(Icons.park_rounded, AppColors.forestGreen);
      case AppNotificationType.badge:
        return const _NotifStyle(Icons.workspace_premium_rounded, AppColors.primaryYellow);
      case AppNotificationType.campaign:
        return const _NotifStyle(Icons.volunteer_activism_rounded, AppColors.terracotta);
      case AppNotificationType.certificate:
        return const _NotifStyle(Icons.verified_rounded, AppColors.primaryBlue);
      case AppNotificationType.donation:
        return const _NotifStyle(Icons.favorite_rounded, AppColors.forestGreen);
      case AppNotificationType.system:
        return const _NotifStyle(Icons.eco_rounded, AppColors.slateBlue);
    }
  }
}

class _NotifStyle {
  final IconData icon;
  final Color color;
  const _NotifStyle(this.icon, this.color);
}
