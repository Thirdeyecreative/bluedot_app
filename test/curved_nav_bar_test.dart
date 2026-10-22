import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bluedot_app/features/navigation/curved_nav_bar.dart';

void main() {
  testWidgets('CurvedNavBar renders all items and handles tab switching', (tester) async {
    int tappedIndex = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox(),
          bottomNavigationBar: StatefulBuilder(
            builder: (context, setState) {
              return CurvedNavBar(
                currentIndex: tappedIndex,
                onTap: (index) {
                  setState(() => tappedIndex = index);
                },
                items: const [
                  CurvedNavBarItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    label: 'Home',
                  ),
                  CurvedNavBarItem(
                    icon: Icons.explore_outlined,
                    activeIcon: Icons.explore_rounded,
                    label: 'Action Hub',
                  ),
                  CurvedNavBarItem(
                    icon: Icons.park_outlined,
                    activeIcon: Icons.park_rounded,
                    label: 'Directory',
                  ),
                  CurvedNavBarItem(
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    label: 'Profile',
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    // Initial check: all labels should be rendered
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Action Hub'), findsWidgets);
    expect(find.text('Directory'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);

    // Initial active icon
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);

    // Tap on Action Hub (index 1)
    await tester.tap(find.text('Action Hub').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify tapped index updated
    expect(tappedIndex, 1);
    expect(find.byIcon(Icons.explore_rounded), findsOneWidget);

    // Tap on Directory (index 2)
    await tester.tap(find.text('Directory').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tappedIndex, 2);
    expect(find.byIcon(Icons.park_rounded), findsOneWidget);

    // Tap on Profile (index 3)
    await tester.tap(find.text('Profile').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tappedIndex, 3);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
  });
}
