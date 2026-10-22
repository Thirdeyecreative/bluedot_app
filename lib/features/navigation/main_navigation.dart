import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../auth/providers/auth_provider.dart';
import 'curved_nav_bar.dart';

/// Main navigation container wrapping the GoRouter StatefulShellRoute.
///
/// Houses the newly designed modern curved navigation bar with animated
/// hump, elevated floating bubble, and smooth slide transitions matching the
/// requested mobile navigation design.
class MainNavigationShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const MainNavigationShell({super.key, required this.navigationShell});

  void _onTapNav(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = navigationShell.currentIndex;

    return PopScope(
      canPop: currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (currentIndex != 0) {
          navigationShell.goBranch(0);
        }
      },
      child: Scaffold(
        extendBody: true,
        body: navigationShell,
        bottomNavigationBar: _BlueDotNavBar(
          currentIndex: currentIndex,
          onTapNav: _onTapNav,
        ),
      ),
    );
  }
}

class _BlueDotNavBar extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTapNav;

  const _BlueDotNavBar({
    required this.currentIndex,
    required this.onTapNav,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return CurvedNavBar(
      currentIndex: currentIndex,
      onTap: onTapNav,
      primaryGreen: AppColors.forestGreen,
      activeIconColor: AppColors.forestGreen,
      activeCircleColor: Colors.white,
      inactiveColor: const Color(0xFFD2DDD4),
      items: [
        const CurvedNavBarItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home',
        ),
        const CurvedNavBarItem(
          icon: Icons.explore_outlined,
          activeIcon: Icons.explore_rounded,
          label: 'Action Hub',
        ),
        const CurvedNavBarItem(
          icon: Icons.park_outlined,
          activeIcon: Icons.park_rounded,
          label: 'Directory',
        ),
        CurvedNavBarItem(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Profile',
          avatarUrl: user?.avatarUrl,
        ),
      ],
    );
  }
}
