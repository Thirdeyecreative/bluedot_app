import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';

/// Data model representing a single navigation item in [CapsuleNavBar].
class CapsuleNavItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final String? avatarUrl;

  const CapsuleNavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    this.avatarUrl,
  });
}

/// A high-polish, floating capsule bottom navigation bar inspired by modern conservation UI.
///
/// Features:
/// - Floating rounded dock with soft ambient shadow and hairline border.
/// - Active tab expands into a comfortable soft blue or tinted pill.
/// - Inactive tabs display clean, minimalist icons with label below.
/// - Optional center elevated action button (e.g. Green Lens camera scanner).
/// - Tactile haptic feedback on tab changes and action triggers.
class CapsuleNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<CapsuleNavItem> items;
  final VoidCallback? onCenterTap;

  /// Background color of the floating bar.
  final Color backgroundColor;

  /// Capsule tint for the active tab.
  final Color activeCapsuleColor;

  /// Foreground icon & text color for the active tab.
  final Color activeColor;

  /// Icon & text color for inactive tabs.
  final Color inactiveColor;

  const CapsuleNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.onCenterTap,
    this.backgroundColor = AppColors.primaryBlue,
    this.activeCapsuleColor = const Color(0xFF26377B),
    this.activeColor = Colors.white,
    this.inactiveColor = const Color(0xB3FFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = backgroundColor.computeLuminance() < 0.4;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(38),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.18)
                : AppColors.borderLight,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? const Color(0xFF162354).withOpacity(0.35)
                  : Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.15)
                  : Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: _buildNavChildren(context),
        ),
      ),
    );
  }

  List<Widget> _buildNavChildren(BuildContext context) {
    final children = <Widget>[];

    for (int i = 0; i < items.length; i++) {
      // If onCenterTap is provided and we reached the halfway point (after tab 1), insert Center Action Button
      if (onCenterTap != null && i == 2) {
        children.add(_buildCenterActionButton(context));
      }

      final isSelected = i == currentIndex;
      children.add(
        _CapsuleTabItem(
          key: ValueKey('capsule-tab-$i'),
          item: items[i],
          isSelected: isSelected,
          activeCapsuleColor: activeCapsuleColor,
          activeColor: activeColor,
          inactiveColor: inactiveColor,
          onTap: () {
            if (!isSelected) {
              HapticFeedback.selectionClick();
              onTap(i);
            }
          },
        ),
      );
    }

    return children;
  }

  Widget _buildCenterActionButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.heavyImpact();
        onCenterTap?.call();
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF22316E),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.camera_alt_outlined,
            color: AppColors.primaryYellow,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _CapsuleTabItem extends StatefulWidget {
  final CapsuleNavItem item;
  final bool isSelected;
  final Color activeCapsuleColor;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _CapsuleTabItem({
    super.key,
    required this.item,
    required this.isSelected,
    required this.activeCapsuleColor,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  State<_CapsuleTabItem> createState() => _CapsuleTabItemState();
}

class _CapsuleTabItemState extends State<_CapsuleTabItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: widget.isSelected ? 1.0 : 0.0,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void didUpdateWidget(covariant _CapsuleTabItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final t = _animation.value;
        final capsuleBg = Color.lerp(
          Colors.transparent,
          widget.activeCapsuleColor,
          t,
        )!;
        final contentColor = Color.lerp(
          widget.inactiveColor,
          widget.activeColor,
          t,
        )!;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(18),
            splashColor: widget.activeColor.withOpacity(0.08),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: capsuleBg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildIcon(contentColor, widget.isSelected),
                  const SizedBox(height: 3),
                  Text(
                    widget.item.label,
                    style: TextStyle(
                      color: contentColor,
                      fontSize: 11,
                      fontWeight:
                          widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIcon(Color color, bool isSelected) {
    if (widget.item.avatarUrl != null && widget.item.avatarUrl!.isNotEmpty) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: widget.item.avatarUrl!,
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(color: AppColors.borderLight),
            errorWidget: (_, _, _) => Icon(
              widget.item.icon,
              size: 15,
              color: color,
            ),
          ),
        ),
      );
    }

    final iconData = (isSelected && widget.item.activeIcon != null)
        ? widget.item.activeIcon!
        : widget.item.icon;

    return Icon(
      iconData,
      size: 22,
      color: color,
    );
  }
}
