import 'package:bluedot_app/core/config/api_config.dart';
import 'package:bluedot_app/core/constants/app_colors.dart';
import 'package:bluedot_app/core/services/api_client.dart';
import 'package:bluedot_app/core/services/push_notification_service.dart';
import 'package:bluedot_app/core/services/storage_service.dart';
import 'package:bluedot_app/features/auth/models/user_model.dart';
import 'package:bluedot_app/features/auth/providers/auth_provider.dart';
import 'package:bluedot_app/features/home/data/home_repository.dart';
import 'package:bluedot_app/features/home/data/notifications_repository.dart';
import 'package:bluedot_app/features/home/models/banner_model.dart';
import 'package:bluedot_app/features/home/models/campaign_model.dart';
import 'package:bluedot_app/features/home/pages/home_page.dart';
import 'package:bluedot_app/features/home/providers/home_provider.dart';
import 'package:bluedot_app/features/home/widgets/promo_banner_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _ProfileUser extends CurrentUserNotifier {
  @override
  AppUser build() => AppUser.fromJson({'id': 'eco-user', 'city': 'Mysore'});
}

class _EcoApi extends ApiClient {
  _EcoApi({this.unavailable = false}) : super(StorageService());

  final bool unavailable;
  int calls = 0;

  @override
  Future<dynamic> get(
    String url, {
    bool requireAuth = true,
    Map<String, String>? query,
  }) async {
    if (url == ApiConfig.consentStatus) return {'requires_consent': false};
    calls++;
    expect(url, ApiConfig.ecoVitals);
    expect(requireAuth, isFalse);
    expect(query, {'city': 'Mysore'});
    if (unavailable) {
      throw const ApiException(message: 'Unavailable', statusCode: 503);
    }
    return {
      'city': 'Mysore',
      'aqi': 103,
      'status': 'Sensitive',
      'recommendation': 'Server air quality guidance',
      'uv_index': 0,
      'uv_status': 'Low',
      'uv_advisory': 'Server UV guidance',
      'temperature': 31,
      'feels_like': 33,
      'humidity': 72,
      'comfort_status': 'Humid Air',
      'canopy_metrics': {'platform_trees': 7, 'estimated_co2_kg': 154},
    };
  }
}

ProviderContainer _container(_EcoApi api) => ProviderContainer.test(
  overrides: [
    currentUserProvider.overrideWith(_ProfileUser.new),
    apiClientProvider.overrideWithValue(api),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Home opens with paired actions and places banners below local vitals',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 560);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const HomePage()),
          for (final path in [
            '/scanner',
            '/action-hub/suggest-site',
            '/profile/leaderboard',
            '/map',
          ])
            GoRoute(
              path: path,
              builder: (_, _) => Scaffold(body: Text(path)),
            ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(_EcoApi()),
            pushNotificationServiceProvider.overrideWith(
              (ref) => PushNotificationService(
                ref.watch(notificationsRepositoryProvider),
              ),
            ),
            homeFeedProvider.overrideWith(
              (_) async => HomeFeedData(
                hero: const AppBanner(
                  id: 'hero',
                  mediaUrl: 'https://example.test/hero.jpg',
                ),
                banners: const [
                  AppBanner(
                    id: 'promo',
                    mediaUrl: 'https://example.test/promo.jpg',
                  ),
                ],
                campaigns: [],
                events: [],
              ),
            ),
            blogsProvider.overrideWith((_) async => []),
            cityAqiProvider.overrideWith(
              (ref) => ref
                  .watch(homeRepositoryProvider)
                  .fetchEcoVitals(city: 'Mysore'),
            ),
            hasNewNotificationsProvider.overrideWith((_) => false),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      Rect cardBounds(String title) => tester.getRect(
        find
            .ancestor(of: find.text(title), matching: find.byType(InkWell))
            .first,
      );
      final scanner = cardBounds('Instant Flora Scanner');
      final suggest = cardBounds('Suggest Site');
      final scannerSurface = find
          .ancestor(
            of: find.text('Instant Flora Scanner'),
            matching: find.byType(Material),
          )
          .first;
      expect(
        tester.widget<Material>(scannerSurface).color,
        AppColors.primaryBlue,
      );
      expect(suggest.top, scanner.top);
      expect(suggest.size, scanner.size);
      expect(suggest.left, greaterThan(scanner.right));
      expect(find.textContaining('Local Eco Vitals'), findsNothing);
      expect(find.textContaining('Mysore'), findsNothing);
      final heading = tester.getRect(find.text('Direct Access'));
      expect(heading.bottom, lessThanOrEqualTo(scanner.top));
      Finder shortcutButton(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((widget) => widget is TextButton),
      );
      final leaderboard = shortcutButton('Leaderboard');
      final mapView = shortcutButton('Map View');
      final shortcuts = find.byWidgetPredicate(
        (widget) => widget is Material && widget.shape is StadiumBorder,
      );
      final pillSurface = find.ancestor(of: leaderboard, matching: shortcuts);
      expect(pillSurface, findsOneWidget);
      expect(
        find.descendant(of: pillSurface, matching: mapView),
        findsOneWidget,
      );
      expect(tester.getTopLeft(pillSurface).dy, greaterThan(scanner.bottom));
      expect(tester.getCenter(leaderboard).dy, tester.getCenter(mapView).dy);
      final supportButton = find.ancestor(
        of: find.text('Support our Cause'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      );
      final supportBounds = tester.getRect(supportButton);
      final shortcutBounds = tester.getRect(pillSurface);
      expect(supportBounds.size, shortcutBounds.size);
      expect(supportBounds.left, shortcutBounds.left);
      expect(supportBounds.top, shortcutBounds.bottom + 8);
      Finder pill(String label) => find.widgetWithText(TextButton, label);
      final pills = [
        for (final label in ['AQI 103', 'UV 0.0', '31°C', 'Noise'])
          tester.getRect(pill(label).hitTestable()),
      ];
      final greeting = find.text(
        "Let's nurture our living planet together today.",
      );
      expect(
        pills.first.top,
        greaterThanOrEqualTo(tester.getBottomLeft(greeting).dy),
      );
      expect(pills.first.left, scanner.left);
      expect(pills.last.right, suggest.right);
      expect(pills.last.bottom, lessThanOrEqualTo(heading.top));
      for (var i = 1; i < pills.length; i++) {
        expect(pills[i].top, pills.first.top);
        expect(pills[i].width, closeTo(pills.first.width, 0.01));
        expect(pills[i].left, greaterThan(pills[i - 1].right));
      }
      final aqi = pill('AQI 103');
      await tester.tap(aqi);
      await tester.pumpAndSettle();
      expect(find.text('Air Quality Index (AQI)'), findsOneWidget);
      Navigator.of(tester.element(find.text('Air Quality Index (AQI)'))).pop();
      await tester.pumpAndSettle();
      for (final (label, path) in [
        ('Instant Flora Scanner', '/scanner'),
        ('Suggest Site', '/action-hub/suggest-site'),
      ]) {
        final action = find.text(label).hitTestable();
        expect(action, findsOneWidget);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.text(path), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
      }
      for (final (label, path) in [
        ('Leaderboard', '/profile/leaderboard'),
        ('Map View', '/map'),
      ]) {
        final shortcut = shortcutButton(label);
        await tester.scrollUntilVisible(shortcut.hitTestable(), 80);
        final height = tester.getSize(shortcut).height;
        expect(height, greaterThanOrEqualTo(kMinInteractiveDimension));
        expect(height, lessThan(scanner.height));
        await tester.tap(shortcut);
        await tester.pumpAndSettle();
        expect(find.text(path), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
      }
      Finder banner(String id) => find.byWidgetPredicate(
        (widget) =>
            widget is PromoBannerCarousel && widget.banners.first.id == id,
      );
      await tester.scrollUntilVisible(banner('hero'), 100);
      expect(
        tester.getTopLeft(banner('hero')).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.text('Map View')).dy),
      );
      await tester.scrollUntilVisible(banner('promo'), 100);
      expect(
        tester.getTopLeft(banner('promo')).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(banner('hero')).dy),
      );
    },
  );

  testWidgets('Stories moves up when the last Home campaign is removed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const campaign = Campaign(
      id: 'campaign',
      title: 'Plant native trees',
      targetAmount: 1000,
      currentAmountRaised: 100,
    );
    var campaigns = [campaign];
    final container = ProviderContainer.test(
      overrides: [
        apiClientProvider.overrideWithValue(_EcoApi()),
        pushNotificationServiceProvider.overrideWith(
          (ref) => PushNotificationService(
            ref.watch(notificationsRepositoryProvider),
          ),
        ),
        homeFeedProvider.overrideWith(
          (_) async =>
              HomeFeedData(banners: [], campaigns: campaigns, events: []),
        ),
        blogsProvider.overrideWith((_) async => []),
        cityAqiProvider.overrideWith(
          (ref) =>
              ref.watch(homeRepositoryProvider).fetchEcoVitals(city: 'Mysore'),
        ),
        hasNewNotificationsProvider.overrideWith((_) => false),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();
    final stories = find.text('Stories & Eco Updates');
    final section = find.text('Active Campaigns');
    final campaignTop = tester.getTopLeft(section).dy;
    expect(find.text(campaign.title), findsOneWidget);
    expect(tester.getTopLeft(stories).dy, greaterThan(campaignTop));

    campaigns = [];
    container.invalidate(homeFeedProvider);
    await tester.pumpAndSettle();
    expect(section, findsNothing);
    expect(find.text(campaign.title), findsNothing);
    expect(tester.getTopLeft(stories).dy, closeTo(campaignTop, 1));
  });

  test('Eco Vitals sends the profile city and renders API readings', () async {
    final api = _EcoApi();
    final container = _container(api);

    final readings = await container.read(cityAqiProvider.future);
    expect(readings.aqi, 103);
    expect(readings.uvIndex, 0);
    expect(readings.temperature, 31);
    expect(readings.platformTrees, 7);
    expect(api.calls, 1);
  });

  test('Eco Vitals reports API errors without substituting readings', () async {
    final api = _EcoApi(unavailable: true);
    final container = _container(api);

    await expectLater(
      container.read(cityAqiProvider.future),
      throwsA(isA<ApiException>()),
    );
    expect(container.read(cityAqiProvider).value, isNull);
    expect(api.calls, 1);
  });
}
