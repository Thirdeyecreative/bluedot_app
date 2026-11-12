import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bluedot_app/core/services/api_client.dart';
import 'package:bluedot_app/core/services/storage_service.dart';
import 'package:bluedot_app/core/theme/app_theme.dart';
import 'package:bluedot_app/features/auth/models/user_model.dart';
import 'package:bluedot_app/features/auth/providers/auth_provider.dart';
import 'package:bluedot_app/features/home/data/notifications_repository.dart';
import 'package:bluedot_app/features/home/models/notification_model.dart';
import 'package:bluedot_app/features/home/pages/notifications_page.dart';
import 'package:bluedot_app/features/home/providers/home_provider.dart';

class _FakeNotificationsRepository extends NotificationsRepository {
  List<AppNotification> store;
  String? lastRequestedCategory;

  _FakeNotificationsRepository(this.store) : super(ApiClient(StorageService()));

  @override
  Future<PaginatedNotificationsResponse> fetchNotifications({
    int skip = 0,
    int limit = 20,
    String? category,
  }) async {
    lastRequestedCategory = category;
    final filtered = (category == null || category == 'all')
        ? store
        : store.where((n) => n.category == category).toList();
    final unread = store.where((n) => !n.read).length;
    return PaginatedNotificationsResponse(
      items: filtered,
      unreadCount: unread,
      total: filtered.length,
      hasMore: false,
    );
  }

  @override
  Future<void> markAllRead() async {
    store = [for (final n in store) n.copyWith(read: true)];
  }

  @override
  Future<void> markRead(String id) async {
    store = [
      for (final n in store)
        if (n.id == id) n.copyWith(read: true) else n,
    ];
  }

  @override
  Future<void> deleteNotification(String id) async {
    store = store.where((n) => n.id != id).toList();
  }
}

class _LoggedInUserNotifier extends CurrentUserNotifier {
  @override
  AppUser? build() => const AppUser(
        id: 'user-1',
        phone: '+919999999999',
        fullName: 'Test User',
      );
}

void main() {
  testWidgets('NotificationsPage shows empty state instead of hardcoded DemoData when backend returns empty',
      (WidgetTester tester) async {
    final fakeRepo = _FakeNotificationsRepository([]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(_LoggedInUserNotifier.new),
          notificationsRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const NotificationsPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text("You're all caught up"), findsOneWidget);
    expect(find.text('Drive starting soon 🌱'), findsNothing);
  });

  testWidgets('NotificationsPage renders live API items, filters by category, and marks all read',
      (WidgetTester tester) async {
    final fakeRepo = _FakeNotificationsRepository([
      const AppNotification(
        id: 'live-1',
        type: AppNotificationType.donation,
        rawType: 'donation_confirmed',
        category: 'donations',
        title: 'Live 80G Receipt Ready',
        body: 'Your ₹500 donation was settled.',
        timeLabel: 'Just now',
        read: false,
      ),
      const AppNotification(
        id: 'live-2',
        type: AppNotificationType.drive,
        rawType: 'drive_reminder',
        category: 'drives',
        title: 'Cubbon Park Drive',
        body: 'Starts tomorrow at 7 AM.',
        timeLabel: '1h ago',
        read: false,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(_LoggedInUserNotifier.new),
          notificationsRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const NotificationsPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Live 80G Receipt Ready'), findsOneWidget);
    expect(find.text('Cubbon Park Drive'), findsOneWidget);
    expect(find.text('2 unread'), findsOneWidget);

    // Filter to Donations tab
    await tester.tap(find.widgetWithText(ChoiceChip, 'Donations'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastRequestedCategory, 'donations');
    expect(find.text('Live 80G Receipt Ready'), findsOneWidget);
    expect(find.text('Cubbon Park Drive'), findsNothing);

    // Mark all read
    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();

    expect(find.text('Mark all read'), findsNothing);
    expect(find.text('2 unread'), findsNothing);
  });
}

