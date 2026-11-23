import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../action_hub/providers/action_provider.dart';
import '../auth/providers/auth_provider.dart';
import '../home/providers/home_provider.dart';
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

class _BlueDotNavBar extends ConsumerStatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTapNav;

  const _BlueDotNavBar({required this.currentIndex, required this.onTapNav});

  @override
  ConsumerState<_BlueDotNavBar> createState() => _BlueDotNavBarState();
}

class _BlueDotNavBarState extends ConsumerState<_BlueDotNavBar> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () {
      ref.invalidate(homeFeedProvider);
      ref.read(notificationsProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final hasNewAction = ref.watch(hasNewActionProvider);
    ref.listen(
      homeFeedProvider.select((feed) => feed.value?.newActionUntil),
      (previous, next) {
        if (next == null || next == previous || !next.isAfter(DateTime.now())) return;
        ref.invalidate(eventsProvider);
        ref.invalidate(campaignsProvider);
      },
    );

    return CapsuleNavBar(
      currentIndex: widget.currentIndex,
      onTap: widget.onTapNav,
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
        CapsuleNavItem(
          icon: Icons.yard_outlined,
          activeIcon: Icons.yard_rounded,
          label: 'Action',
          showNewDot: hasNewAction,
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
