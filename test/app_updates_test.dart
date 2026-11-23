import 'package:bluedot_app/core/services/connectivity_service.dart';
import 'package:bluedot_app/core/widgets/app_update_prompt.dart';
import 'package:bluedot_app/core/widgets/app_update_sheet.dart';
import 'package:bluedot_app/features/profile/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _storeChannel = MethodChannel('in_app_update_flutter');
const _permissionsChannel = MethodChannel(
  'flutter.baseflow.com/permissions/methods',
);

class _OnlineConnectivity extends ConnectivityNotifier {
  @override
  bool build() => true;
}

Future<GoRouter> _mountApp(
  WidgetTester tester, {
  required Future<Object?> Function(MethodCall) storeHandler,
}) async {
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_storeChannel, storeHandler);
  messenger.setMockMethodCallHandler(_permissionsChannel, (_) async => 0);
  final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, _) => const Scaffold(body: Text('Starting BlueDot')),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
    ],
  );
  addTearDown(() {
    router.dispose();
    messenger.setMockMethodCallHandler(_storeChannel, null);
    messenger.setMockMethodCallHandler(_permissionsChannel, null);
  });

  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [connectivityProvider.overrideWith(_OnlineConnectivity.new)],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (_, child) => AppUpdatePrompt(router: router, child: child!),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets(
    'Android prompts after splash and the Settings pill reopens it',
    (tester) async {
      var updateAttempts = 0;
      final router = await _mountApp(
        tester,
        storeHandler: (call) async {
          if (call.method == 'checkForUpdateAndroid') {
            return {
              'updateAvailability': 2,
              'availableVersionCode': 3,
              'updatePriority': 0,
              'isImmediateUpdateAllowed': true,
              'isFlexibleUpdateAllowed': true,
              'installStatus': 0,
            };
          }
          expect(call.method, 'startImmediateUpdateAndroid');
          updateAttempts++;
          return 0;
        },
      );

      expect(find.byType(AppUpdateSheet), findsNothing);
      router.go('/settings');
      await tester.pumpAndSettle();
      expect(find.byType(AppUpdateSheet), findsOneWidget);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(AppUpdateSheet), findsNothing);

      await tester.tap(find.widgetWithText(ActionChip, 'Update available'));
      await tester.pumpAndSettle();
      expect(find.byType(AppUpdateSheet), findsOneWidget);
      await tester.tap(find.text('Update now'));
      await tester.pumpAndSettle();
      expect(updateAttempts, 1);
      expect(find.byType(AppUpdateSheet), findsNothing);
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'iOS shows an update after resume only when a newer version is offered',
    (tester) async {
      var hasUpdate = false;
      String? presentedAppStoreId;
      final router = await _mountApp(
        tester,
        storeHandler: (call) async {
          if (call.method == 'checkForUpdateIos') {
            return {
              'updateAvailability': hasUpdate
                  ? 'updateAvailable'
                  : 'updateNotAvailable',
              'installedVersion': '1.0.0',
              'storeVersion': hasUpdate ? '1.1.0' : '1.0.0',
              'appStoreId': '12345',
              'storeUrl': 'https://apps.apple.com/app/id12345',
              'country': 'in',
            };
          }
          expect(call.method, 'showStoreUpdateIos');
          presentedAppStoreId = call.arguments['appStoreId'] as String;
          return null;
        },
      );

      router.go('/settings');
      await tester.pumpAndSettle();
      expect(find.byType(AppUpdateSheet), findsNothing);
      expect(find.widgetWithText(ActionChip, 'Update available'), findsNothing);

      hasUpdate = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('BlueDot 1.1.0 is ready to install.'), findsOneWidget);
      await tester.tap(find.text('Update now'));
      await tester.pumpAndSettle();
      expect(presentedAppStoreId, '12345');
      expect(find.byType(AppUpdateSheet), findsNothing);
      expect(
        find.widgetWithText(ActionChip, 'Update available'),
        findsOneWidget,
      );
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );
}
