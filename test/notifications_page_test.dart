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
import 'package:bluedot_app/core/utils/route_dispatcher.dart';

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
  testWidgets(
    'NotificationsPage shows empty state instead of hardcoded DemoData when backend returns empty',
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
    },
  );

  testWidgets(
    'NotificationsPage renders live API items, filters by category, and marks all read',
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

      // Filter to Campaigns & Donations tab
      await tester.tap(
        find.widgetWithText(ChoiceChip, 'Campaigns & Donations'),
      );
      await tester.pumpAndSettle();

      expect(fakeRepo.lastRequestedCategory, 'donations');
      expect(find.text('Live 80G Receipt Ready'), findsOneWidget);
      expect(find.text('Cubbon Park Drive'), findsNothing);

      // Mark all read
      await tester.tap(find.text('Mark all read'));
      await tester.pumpAndSettle();

      expect(find.text('Mark all read'), findsNothing);
      expect(find.text('2 unread'), findsNothing);
    },
  );

  test('RouteDispatcher resolves event and campaign deep links cleanly', () {
    // 1. Direct explicit routes
    expect(
      RouteDispatcher.resolveRoute(route: '/action-hub/event/evt-123'),
      '/action-hub/event/evt-123',
    );
    expect(
      RouteDispatcher.resolveRoute(route: '/action-hub/campaign/cmp-456'),
      '/action-hub/campaign/cmp-456',
    );

    // 2. Fallback resolution when server passes generic route with event_id or campaign_id in data
    expect(
      RouteDispatcher.resolveRoute(
        route: '/notifications',
        type: 'drive',
        data: {'event_id': 'evt-123'},
      ),
      '/action-hub/event/evt-123',
    );
    expect(
      RouteDispatcher.resolveRoute(
        route: '/action-hub',
        type: 'campaign',
        data: {'campaign_id': 'cmp-456'},
      ),
      '/action-hub/campaign/cmp-456',
    );

    // 3. Fallback resolution when route is null but type + data provided
    expect(
      RouteDispatcher.resolveRoute(
        type: 'drive',
        data: {'event_id': 'evt-789'},
      ),
      '/action-hub/event/evt-789',
    );
    expect(
      RouteDispatcher.resolveRoute(
        type: 'campaign',
        data: {'campaign_id': 'cmp-999'},
      ),
      '/action-hub/campaign/cmp-999',
    );

    // 4. Missing IDs degrade cleanly to Action Hub tab index
    expect(RouteDispatcher.resolveRoute(type: 'drive'), '/action-hub?tab=0');
    expect(RouteDispatcher.resolveRoute(type: 'campaign'), '/action-hub?tab=1');

    // 5. Additional situations
    expect(
      RouteDispatcher.resolveRoute(type: 'blog', data: {'slug': 'urban-forests'}),
      '/home/blog/urban-forests',
    );
    expect(
      RouteDispatcher.resolveRoute(type: 'species', data: {'species_id': 'sp-101'}),
      '/directory/species/sp-101',
    );
    expect(
      RouteDispatcher.resolveRoute(type: 'leaderboard'),
      '/profile/leaderboard',
    );
    expect(
      RouteDispatcher.resolveRoute(type: 'receipt_80g'),
      '/profile/settings/tax-vault',
    );
    expect(
      RouteDispatcher.resolveRoute(type: 'volunteer_certificate'),
      '/profile/certificates',
    );
    expect(
      RouteDispatcher.resolveRoute(type: 'tree_approved'),
      '/map',
    );
    expect(
      RouteDispatcher.resolveRoute(type: 'site_suggestion'),
      '/action-hub/suggest-site',
    );
  });

  testWidgets('NotificationsPage displays action pills and opens announcement sheet on tap',
      (WidgetTester tester) async {
    final fakeRepo = _FakeNotificationsRepository([
      const AppNotification(
        id: 'drive-notif',
        type: AppNotificationType.drive,
        rawType: 'drive',
        category: 'drives',
        title: 'Holi Plantation Drive',
        body: 'Meet at Gate 2',
        timeLabel: '2m ago',
        route: '/action-hub/event/evt-101',
      ),
      const AppNotification(
        id: 'broadcast-notif',
        type: AppNotificationType.system,
        rawType: 'admin_broadcast',
        category: 'announcements',
        title: 'Happy Environment Day',
        body: 'Thank you for making Earth greener!',
        timeLabel: '1h ago',
        isBroadcast: true,
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

    // Verify "View Event" pill appears on actionable event notification
    expect(find.text('View Event'), findsOneWidget);

    // Tap the announcement card (without deep link)
    await tester.tap(find.text('Happy Environment Day'));
    await tester.pumpAndSettle();

    // Verify bottom sheet opened
    expect(find.text('Community Announcement'), findsOneWidget);
    expect(find.text('Explore Action Hub'), findsOneWidget);
  });

  test('AppNotification.fromJson correctly segregates events and campaigns', () {
    // Event linked notification
    final eventNotif = AppNotification.fromJson({
      'id': 'notif-e1',
      'type': 'drive',
      'title': 'Holi Tree Drive',
      'body': 'Join us at Cubbon Park',
      'data': {'event_id': 'evt-abc'},
    });
    expect(eventNotif.category, 'drives');
    expect(eventNotif.type, AppNotificationType.drive);

    // Campaign linked notification
    final campaignNotif = AppNotification.fromJson({
      'id': 'notif-c1',
      'type': 'campaign',
      'title': 'Plant 10,000 Trees',
      'body': 'Support our tree planting campaign',
      'data': {'campaign_id': 'cmp-xyz'},
    });
    expect(campaignNotif.category, 'donations');
    expect(campaignNotif.type, AppNotificationType.campaign);

    // Announcement with campaign data attached segregates into donations/campaign
    final broadcastCampaign = AppNotification.fromJson({
      'id': 'notif-b1',
      'type': 'admin_broadcast',
      'title': 'Exciting Campaign Launch',
      'body': 'Check out our new greening campaign',
      'data': {'campaign_id': 'cmp-xyz'},
    });
    expect(broadcastCampaign.category, 'donations');
    expect(broadcastCampaign.type, AppNotificationType.campaign);
  });
}
