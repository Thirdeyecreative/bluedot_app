import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../auth/providers/auth_provider.dart';
import 'capsule_nav_bar.dart';

/// Main navigation container wrapping the GoRouter StatefulShellRoute.
///
/// Features direction-aware fluid slide & crossfade transitions between tabs
/// and houses the custom floating [CapsuleNavBar].
class MainNavigationShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  const MainNavigationShell({super.key, required this.navigationShell});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _previousIndex = 0;

  void _onTapNav(int index) {
    if (index != widget.navigationShell.currentIndex) {
      setState(() {
        _previousIndex = widget.navigationShell.currentIndex;
      });
    }
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;
    final isMovingForward = currentIndex >= _previousIndex;

    return PopScope(
      canPop: currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (currentIndex != 0) {
          _onTapNav(0);
        }
      },
      child: Scaffold(
        extendBody: true,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final offsetTween = Tween<Offset>(
              begin: Offset(isMovingForward ? 0.04 : -0.04, 0),
              end: Offset.zero,
            );
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: SlideTransition(
                position: offsetTween.animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(currentIndex),
            child: widget.navigationShell,
          ),
        ),
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

  const _BlueDotNavBar({required this.currentIndex, required this.onTapNav});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return CapsuleNavBar(
      currentIndex: currentIndex,
      onTap: onTapNav,
      onCenterTap: () => context.push('/scanner'),
      backgroundColor: AppColors.primaryBlue,
      activeCapsuleColor: const Color(0xFF26377B),
      activeColor: Colors.white,
      inactiveColor: Colors.white.withOpacity(0.7),
      items: [
        const CapsuleNavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home',
        ),
        const CapsuleNavItem(
          icon: Icons.yard_outlined,
          activeIcon: Icons.yard_rounded,
          label: 'Action',
        ),
        const CapsuleNavItem(
          icon: Icons.explore_outlined,
          activeIcon: Icons.explore_rounded,
          label: 'Directory',
        ),
        CapsuleNavItem(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Profile',
          avatarUrl: user?.avatarUrl,
        ),
      ],
    );
  }
}
