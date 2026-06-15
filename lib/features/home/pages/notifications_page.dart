import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../models/notification_model.dart';
import '../providers/home_provider.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notificationsProvider);
    final unread = items.where((n) => !n.read).length;

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: const BackButton(),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () => ref.read(notificationsProvider.notifier).markAllRead(),
              child: const Text('Mark all read', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: items.isEmpty
          ? const _EmptyNotifications()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 130),
              children: [
                if (unread > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12, left: 4),
                    child: Text(
                      '$unread unread',
                      style: const TextStyle(color: AppColors.textMedium, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                for (int i = 0; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _NotificationCard(item: items[i])
                        .animate()
                        .fadeIn(delay: (60 * i).ms)
                        .slideY(begin: 0.06, end: 0, delay: (60 * i).ms),
                  ),
              ],
            ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_off_outlined, size: 64, color: AppColors.slateBlue.withAlpha(120)),
              const SizedBox(height: 16),
              const Text("You're all caught up", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textDark)),
              const SizedBox(height: 8),
              const Text(
                'Drive reminders, badge unlocks, and campaign updates will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMedium, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
      );
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
        if (item.route != null) context.push(item.route!);
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
                  Text(item.timeLabel, style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
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
