import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../auth/providers/auth_provider.dart';
import 'capsule_nav_bar.dart';

/// Hosts the shell and the floating [CapsuleNavBar].
class MainNavigationShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const MainNavigationShell({super.key, required this.navigationShell});

  static Widget buildBranchContainer(
    BuildContext context,
    StatefulNavigationShell shell,
    List<Widget> children,
  ) =>
      _NavigationBranches(currentIndex: shell.currentIndex, branches: children);

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
          _onTapNav(0);
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

class _NavigationBranches extends StatelessWidget {
  const _NavigationBranches({
    required this.currentIndex,
    required this.branches,
  });

  final int currentIndex;
  final List<Widget> branches;
  static const _duration = Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      // Each navigator stays in its own slot, even when animations overlap.
      for (var index = 0; index < branches.length; index++) _buildBranch(index),
    ],
  );

  Widget _buildBranch(int index) {
    final active = index == currentIndex;
    return AnimatedSlide(
      offset: active
          ? Offset.zero
          : Offset(index < currentIndex ? -0.04 : 0.04, 0),
      duration: _duration,
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: active ? 1 : 0,
        duration: _duration,
        curve: active ? Curves.easeOutCubic : Curves.easeInCubic,
        child: ExcludeSemantics(
          excluding: !active,
          child: ExcludeFocus(
            excluding: !active,
            child: IgnorePointer(
              ignoring: !active,
              child: TickerMode(enabled: active, child: branches[index]),
            ),
          ),
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
