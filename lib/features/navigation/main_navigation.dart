import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_assets.dart';
import '../auth/providers/auth_provider.dart';

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
        floatingActionButton: GestureDetector(
          onTap: () => context.push('/scanner'),
          child: const _PulsingScanFab(),
        ),
        floatingActionButtonLocation: const _CustomCenterDockedFabLocation(),
        bottomNavigationBar: _BlueDotNavBar(
          currentIndex: currentIndex,
          onTapNav: _onTapNav,
        ),
      ),
    );
  }
}

class _CustomCenterDockedFabLocation extends FloatingActionButtonLocation {
  const _CustomCenterDockedFabLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double fabX = (scaffoldGeometry.scaffoldSize.width - scaffoldGeometry.floatingActionButtonSize.width) / 2.0;
    // Push the FAB down by exactly 20 pixels
    final double fabY = scaffoldGeometry.contentBottom - (scaffoldGeometry.floatingActionButtonSize.height / 2.0) + 20.0;
    return Offset(fabX, fabY);
  }
}

class _BlueDotNavBar extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTapNav;

  const _BlueDotNavBar({
    required this.currentIndex,
    required this.onTapNav,
  });

  static const _items = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.hub_rounded, label: 'Action Hub'),
    (icon: Icons.local_florist_rounded, label: 'Directory'),
    (icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return BottomAppBar(
      color: AppColors.forestGreen,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      height: 74,
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: _NavItem(
              icon: _items[0].icon,
              label: _items[0].label,
              selected: currentIndex == 0,
              onTap: () => onTapNav(0),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: _items[1].icon,
              label: _items[1].label,
              selected: currentIndex == 1,
              onTap: () => onTapNav(1),
            ),
          ),
          const SizedBox(width: 72), // Empty space for the docked FAB notch
          Expanded(
            child: _NavItem(
              icon: _items[2].icon,
              label: _items[2].label,
              selected: currentIndex == 2,
              onTap: () => onTapNav(2),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: _items[3].icon,
              label: _items[3].label,
              selected: currentIndex == 3,
              onTap: () => onTapNav(3),
              avatarUrl: user?.avatarUrl,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? avatarUrl;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: selected
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.textDark,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.backgroundCream, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.textDark.withAlpha(110),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: hasAvatar 
                       ? ClipOval(child: CachedNetworkImage(imageUrl: avatarUrl!, fit: BoxFit.cover))
                       : Icon(icon, color: AppColors.backgroundCream, size: 22),
                  ).animate().scaleXY(begin: 0.6, end: 1, curve: Curves.elasticOut, duration: 500.ms),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ).animate().fadeIn(delay: 150.ms, duration: 300.ms),
                ],
              )
            : hasAvatar
                ? Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withAlpha(190), width: 1.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ClipOval(child: CachedNetworkImage(imageUrl: avatarUrl!, fit: BoxFit.cover)),
                  )
                : Icon(icon, color: Colors.white.withAlpha(190), size: 24),
      ),
    );
  }
}

class _PulsingScanFab extends StatelessWidget {
  const _PulsingScanFab();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Expanding radar rings
          for (int i = 0; i < 2; i++)
            const SizedBox(width: 76, height: 76)
                .animate(onPlay: (c) => c.repeat())
                .custom(
                  delay: (i * 900).ms,
                  duration: 2200.ms,
                  curve: Curves.easeOut,
                  builder: (_, value, _) => Transform.scale(
                    scale: 0.65 + 0.35 * value,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryYellow.withAlpha((140 * (1 - value)).round()),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),

          // Soft glow behind the artwork
          const SizedBox(width: 60, height: 60)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .custom(
                duration: 1800.ms,
                curve: Curves.easeInOut,
                builder: (_, value, _) => Transform.scale(
                  scale: 1 + 0.05 * value,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryYellow.withAlpha((130 * value).round()),
                          blurRadius: 15,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

          // The Green Lens artwork
          ClipOval(
            child: Container(
              width: 60,
              height: 60,
              color: AppColors.primaryBlue,
              padding: const EdgeInsets.all(8),
              child: Image.asset(
                AppAssets.greenLensButton,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(end: 1.05, duration: 1800.ms, curve: Curves.easeInOut),
        ],
      ),
    );
  }
}
