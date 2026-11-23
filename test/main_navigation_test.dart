import 'package:bluedot_app/features/navigation/main_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('rapid tab switches keep one shell and preserve branch state', (
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
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
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
