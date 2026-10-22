import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';

/// Data model representing a single tab item in the curved navigation bar.
class CurvedNavBarItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final String? avatarUrl;

  const CurvedNavBarItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    this.avatarUrl,
  });
}

/// A custom-sculpted curved navigation bar with green glassmorphism aesthetics.
///
/// Features:
/// - Mathematically continuous single-contour Bézier curve with zero corner distortion.
/// - The top-left and top-right corner radii remain 100% stable across all tabs (no green pop-out).
/// - True glassmorphic frosted backdrop blur (`BackdropFilter` + specular rim highlight).
/// - Translucent Forest Green eco-palette (`AppColors.forestGreen`).
/// - Elevated floating circular active button that extends cleanly above the bar with no green border on top.
/// - Fluid spring/glide animation between tab transitions.
class CurvedNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<CurvedNavBarItem> items;
  final Color primaryGreen;
  final Color activeIconColor;
  final Color activeCircleColor;
  final Color inactiveColor;

  const CurvedNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.primaryGreen = AppColors.forestGreen,
    this.activeIconColor = AppColors.forestGreen,
    this.activeCircleColor = Colors.white,
    this.inactiveColor = const Color(0xFFD2DDD4),
  });

  @override
  State<CurvedNavBar> createState() => _CurvedNavBarState();
}

class _CurvedNavBarState extends State<CurvedNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _fromPos = 0.0;
  double _toPos = 0.0;

  @override
  void initState() {
    super.initState();
    _fromPos = widget.currentIndex.toDouble();
    _toPos = widget.currentIndex.toDouble();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant CurvedNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _fromPos = _currentPosition;
      _toPos = widget.currentIndex.toDouble();
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _currentPosition {
    if (!_controller.isAnimating) return _toPos;
    return _fromPos + (_toPos - _fromPos) * _animation.value;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    const double barHeight = 84.0;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 6, // Headroom for the elevated floating active button
        bottom: bottomPadding > 0 ? bottomPadding : 10,
      ),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final pos = _currentPosition;

          return SizedBox(
            height: barHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final itemCount = widget.items.length;
                final itemWidth = width / itemCount;
                final activeCenterX = (pos + 0.5) * itemWidth;

                // Subtle spring bounce scale during slide
                final progress = _controller.value;
                final bounceScale = _controller.isAnimating
                    ? 1.0 - (math.sin(progress * math.pi) * 0.16)
                    : 1.0;

                final barPath = _buildCurvedBarPath(
                  Size(width, barHeight),
                  activeCenterX,
                );

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Frosted Backdrop Glassmorphism Filter
                    ClipPath(
                      clipper: _CurvedBarClipper(barPath),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: Container(
                          width: width,
                          height: barHeight,
                          color: Colors.transparent,
                        ),
                      ),
                    ),

                    // 2. Custom Painter: Glass gradient background + specular rim highlight + drop shadow
                    CustomPaint(
                      size: Size(width, barHeight),
                      painter: _CurvedNavBarPainter(
                        barPath: barPath,
                        primaryGreen: widget.primaryGreen,
                      ),
                    ),

                    // 3. Tab Items Row (Inactive Icons/Labels + Active Bold Label)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 22, // starts at the flat body baseline
                      bottom: 8,
                      child: Row(
                        children: List.generate(itemCount, (index) {
                          final item = widget.items[index];
                          final dist = (index - pos).abs();
                          // Inactive items smoothly fade out as active hump approaches
                          final inactiveOpacity = (dist * 1.5).clamp(0.0, 1.0);
                          final activeTextOpacity = (1.0 - dist * 2.0).clamp(0.0, 1.0);

                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (index != widget.currentIndex) {
                                  HapticFeedback.lightImpact();
                                  widget.onTap(index);
                                }
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Inactive Icon + Label
                                  if (inactiveOpacity > 0.01)
                                    Opacity(
                                      opacity: inactiveOpacity,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          _buildInactiveIcon(item),
                                          const SizedBox(height: 3),
                                          Text(
                                            item.label,
                                            style: TextStyle(
                                              color: Colors.white.withAlpha(210),
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: -0.2,
                                              shadows: const [
                                                Shadow(
                                                  color: Color(0x66000000),
                                                  blurRadius: 4,
                                                  offset: Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),

                                  // Active Bold White Label under the floating circle
                                  if (activeTextOpacity > 0.01)
                                    Opacity(
                                      opacity: activeTextOpacity,
                                      child: Align(
                                        alignment: const Alignment(0, 0.78),
                                        child: Text(
                                          item.label,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.2,
                                            shadows: [
                                              Shadow(
                                                color: Color(0x88000000),
                                                blurRadius: 6,
                                                offset: Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    // 4. Floating Elevated Circle over the active tab (projects cleanly above with NO green border on top)
                    Positioned(
                      left: activeCenterX - 26,
                      top: -4, // Floats elevated above the bar
                      child: Transform.scale(
                        scale: bounceScale,
                        child: _buildActiveFloatingCircle(
                          widget.items[widget.currentIndex],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildInactiveIcon(CurvedNavBarItem item) {
    if (item.avatarUrl != null && item.avatarUrl!.isNotEmpty) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.inactiveColor.withAlpha(180),
            width: 1.2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: item.avatarUrl!,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) => Icon(
              item.icon,
              color: widget.inactiveColor.withAlpha(200),
              size: 16,
            ),
          ),
        ),
      );
    }

    return Icon(
      item.icon,
      color: Colors.white.withAlpha(225),
      size: 22,
      shadows: const [
        Shadow(
          color: Color(0x66000000),
          blurRadius: 4,
          offset: Offset(0, 1),
        ),
      ],
    );
  }

  Widget _buildActiveFloatingCircle(CurvedNavBarItem item) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: widget.activeCircleColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 3.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(55),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: widget.primaryGreen.withAlpha(45),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: item.avatarUrl != null && item.avatarUrl!.isNotEmpty
            ? ClipOval(
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: CachedNetworkImage(
                    imageUrl: item.avatarUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Icon(
                      item.activeIcon ?? item.icon,
                      color: widget.activeIconColor,
                      size: 24,
                    ),
                  ),
                ),
              )
            : Icon(
                item.activeIcon ?? item.icon,
                color: widget.activeIconColor,
                size: 24,
              ),
      ),
    );
  }
}

/// Computes the single continuous, mathematically gapless curved navigation bar path.
///
/// Guaranteed properties:
/// 1. Top-left and top-right corner radii are ALWAYS pristine 26px quarter circles (zero pop-out on leftmost/rightmost pages).
/// 2. Hump bounds are safely bounded within [cornerR, w - cornerR] without CSG boolean union artifacts.
/// 3. Zero green edge or border extending above the floating circle.
Path _buildCurvedBarPath(Size size, double activeCenterX) {
  final double w = size.width;
  final double h = size.height;
  const double cornerR = 26.0;
  const double yBase = 22.0; // Flat top baseline of the main pill body
  const double yPeak = 8.0;  // Crest of the upward green cradle
  const double maxHumpHalfW = 40.0;

  final double xc = activeCenterX;

  // Safe half-widths that dynamically anchor before the pill's corner arcs:
  final double wLeft = math.min(xc - cornerR, maxHumpHalfW).clamp(16.0, maxHumpHalfW);
  final double wRight = math.min((w - cornerR) - xc, maxHumpHalfW).clamp(16.0, maxHumpHalfW);

  final double x1 = xc - wLeft;
  final double x2 = xc + wRight;

  final path = Path();

  // 1. Start at bottom-left corner and trace clockwise
  path.moveTo(0, h - cornerR);

  // 2. Left vertical straight wall up to top-left corner
  path.lineTo(0, yBase + cornerR);

  // 3. Top-left rounded corner (ALWAYS pristine, mathematically immutable)
  path.arcToPoint(
    const Offset(cornerR, yBase),
    radius: const Radius.circular(cornerR),
    clockwise: true,
  );

  // 4. Flat top segment from left corner to x1
  if (x1 > cornerR) {
    path.lineTo(x1, yBase);
  }

  // 5. Smooth cubic S-curve rise to crest and descent to x2
  path.cubicTo(
    x1 + wLeft * 0.42, yBase,
    xc - wLeft * 0.38, yPeak,
    xc, yPeak,
  );
  path.cubicTo(
    xc + wRight * 0.38, yPeak,
    x2 - wRight * 0.42, yBase,
    x2, yBase,
  );

  // 6. Flat top segment from x2 to right corner
  if (x2 < w - cornerR) {
    path.lineTo(w - cornerR, yBase);
  }

  // 7. Top-right rounded corner (ALWAYS pristine, mathematically immutable)
  path.arcToPoint(
    Offset(w, yBase + cornerR),
    radius: const Radius.circular(cornerR),
    clockwise: true,
  );

  // 8. Right vertical straight wall down to bottom-right corner
  path.lineTo(w, h - cornerR);

  // 9. Bottom-right rounded corner
  path.arcToPoint(
    Offset(w - cornerR, h),
    radius: const Radius.circular(cornerR),
    clockwise: true,
  );

  // 10. Bottom horizontal straight edge
  path.lineTo(cornerR, h);

  // 11. Bottom-left rounded corner
  path.arcToPoint(
    Offset(0, h - cornerR),
    radius: const Radius.circular(cornerR),
    clockwise: true,
  );

  path.close();
  return path;
}

/// Clips children (like BackdropFilter) precisely to the curved bar path.
class _CurvedBarClipper extends CustomClipper<Path> {
  final Path path;
  const _CurvedBarClipper(this.path);

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(covariant _CurvedBarClipper oldClipper) => oldClipper.path != path;
}

/// Paints the translucent glassmorphic green gradient, drop shadow, and frosted specular rim.
class _CurvedNavBarPainter extends CustomPainter {
  final Path barPath;
  final Color primaryGreen;

  const _CurvedNavBarPainter({
    required this.barPath,
    required this.primaryGreen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Ambient drop shadow + colored glass caustics
    final ambientShadow = Paint()
      ..color = Colors.black.withAlpha(35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
    canvas.drawPath(barPath.shift(const Offset(0, 8)), ambientShadow);

    final causticGlow = Paint()
      ..color = primaryGreen.withAlpha(40)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawPath(barPath.shift(const Offset(0, 3)), causticGlow);

    // 2. Translucent Emerald Glass Tint (~38% to ~52% opacity for unmistakable see-through glass clarity)
    final glassTint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, size.height),
        [
          primaryGreen.withAlpha(95),             // ~37% opacity emerald green at top
          const Color(0xFF243628).withAlpha(135), // ~53% opacity deeper green at bottom
        ],
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(barPath, glassTint);

    // 3. Frosted Glass Diffusion Mist (gives the glass its physical sandblasted frosted texture)
    final frostMist = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, size.height),
        [
          Colors.white.withAlpha(65), // Bright frosted mist at top
          Colors.white.withAlpha(18), // Subtle diffusion at bottom
        ],
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(barPath, frostMist);

    // 4. Diagonal Glass Lens Glare (specular light sweeping across the glass surface)
    final lensGlare = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(size.width * 0.8, size.height),
        [
          Colors.white.withAlpha(75), // Top-left optical glare
          Colors.white.withAlpha(20),
          Colors.white.withAlpha(0),
        ],
        [0.0, 0.45, 1.0],
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(barPath, lensGlare);

    // 5. Signature Crystal Specular Rim (Crisp, bright frosted reflection border)
    final specularBorder = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, size.height),
        [
          Colors.white.withAlpha(210), // Brilliant crystal top glare reflection
          Colors.white.withAlpha(80),  // Vivid mid-specular rim
          Colors.white.withAlpha(30),  // Subtle bottom edge reflection
        ],
        [0.0, 0.40, 1.0],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawPath(barPath, specularBorder);
  }

  @override
  bool shouldRepaint(covariant _CurvedNavBarPainter oldDelegate) {
    return oldDelegate.barPath != barPath ||
        oldDelegate.primaryGreen != primaryGreen;
  }
}
