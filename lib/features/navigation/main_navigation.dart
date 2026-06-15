import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';

class MainNavigationShell extends StatelessWidget {
  final Widget child;
  const MainNavigationShell({super.key, required this.child});

  static const _tabs = ['/home', '/action-hub', '/directory', '/profile'];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: _BlueDotNavBar(currentIndex: index),
    );
  }
}

class _BlueDotNavBar extends StatelessWidget {
  final int currentIndex;
  const _BlueDotNavBar({required this.currentIndex});

  static const _items = [
    (icon: Icons.home_rounded, label: 'Home', route: '/home'),
    (icon: Icons.hub_rounded, label: 'Action Hub', route: '/action-hub'),
    (icon: Icons.local_florist_rounded, label: 'Directory', route: '/directory'),
    (icon: Icons.person_rounded, label: 'Profile', route: '/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        height: 68,
        clipBehavior: Clip.none,
        decoration: BoxDecoration(
          color: AppColors.forestGreen,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: AppColors.forestGreen.withAlpha(90),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            for (int i = 0; i < _items.length; i++)
              Expanded(
                child: _NavItem(
                  icon: _items[i].icon,
                  label: _items[i].label,
                  selected: currentIndex == i,
                  onTap: () => context.go(_items[i].route),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: selected
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.translate(
                    offset: const Offset(0, -14),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.textDark,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.backgroundCream, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.textDark.withAlpha(110),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(icon, color: AppColors.backgroundCream, size: 26),
                    ).animate().scaleXY(begin: 0.6, end: 1, curve: Curves.elasticOut, duration: 500.ms),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -10),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ).animate().fadeIn(delay: 150.ms, duration: 300.ms),
                  ),
                ],
              )
            : Icon(icon, color: Colors.white.withAlpha(190), size: 24),
      ),
    );
  }
}
