import 'package:bluedot_app/features/home/data/home_repository.dart';
import 'package:bluedot_app/features/home/providers/home_provider.dart';
import 'package:bluedot_app/features/navigation/main_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('rapid tab switches preserve state and the Action dot expires', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        StatefulShellRoute(
          builder: (_, _, shell) => MainNavigationShell(navigationShell: shell),
          navigatorContainerBuilder: MainNavigationShell.buildBranchContainer,
          branches: [
            for (final tab in ['home', 'action-hub', 'directory', 'profile'])
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/$tab',
                    builder: (_, _) => _TabCounter(tab: tab),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeFeedProvider.overrideWith((ref) async => HomeFeedData(
            newActionUntil: DateTime.now().add(const Duration(seconds: 10)),
            banners: [],
            campaigns: [],
            events: [],
          )),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> switchTo(int index) async {
      await tester.tap(find.byKey(ValueKey('capsule-tab-$index')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        find.byType(StatefulNavigationShell, skipOffstage: false),
        findsOneWidget,
      );
    }

    await switchTo(3);
    await tester.pumpAndSettle();
    await tester.tap(find.text('profile count: 0'));
    await tester.pump();

    await switchTo(0);
    await switchTo(2);
    await switchTo(3);
    await tester.pumpAndSettle();

    expect(find.text('profile count: 1').hitTestable(), findsOneWidget);
    expect(find.text('directory count: 0').hitTestable(), findsNothing);
    final actionDot = find.descendant(
      of: find.byKey(const ValueKey('capsule-tab-1')),
      matching: find.byType(Badge),
    );
    expect(actionDot, findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
    expect(actionDot, findsNothing);
  });
}

class _TabCounter extends StatefulWidget {
  const _TabCounter({required this.tab});

  final String tab;

  @override
  State<_TabCounter> createState() => _TabCounterState();
}

class _TabCounterState extends State<_TabCounter> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: () => setState(() => _count++),
      child: Text('${widget.tab} count: $_count'),
    ),
  );
}
