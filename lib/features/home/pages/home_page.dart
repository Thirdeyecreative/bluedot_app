import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/skeletons.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/blog_model.dart';
import '../providers/home_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scroll = ScrollController();

  // Picked once per page open so the tagline drops from a random corner
  // but doesn't flip sides on rebuilds.
  final _taglineFromLeft = Random().nextBool();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final blogs = ref.watch(blogsProvider);
    // Clamped so short screens still fit the scan button and tall/tablet
    // screens don't get an oversized hero.
    final heroHeight =
        (MediaQuery.of(context).size.height * 0.45 - 100).clamp(240.0, 420.0);

    // Alternating slots exit left / right as they approach the blue area.
    Widget vortex(int slot, Widget child) => _VortexItem(
          controller: _scroll,
          heroHeight: heroHeight,
          direction: slot.isEven ? -1 : 1,
          child: child,
        );

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      body: Stack(
        children: [
          // Content scrolls UNDER the pinned hero; items get "sucked into"
          // the blue section as they approach it (see _VortexItem).
          Positioned.fill(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: EdgeInsets.only(top: heroHeight + 16, bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick actions: Eco Garden + Leaderboard
                  vortex(0, const _HomeQuickActions()),

                  // Blog Section
                  vortex(
                    3,
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Stories & Updates', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          TextButton(onPressed: () {}, child: const Text('See all')),
                        ],
                      ),
                    ),
                  ),
                  blogs.when(
                    data: (list) => _BlogGrid(
                      blogs: list,
                      itemWrapper: (i, child) => vortex(4 + i, child),
                    ),
                    loading: () => const SkeletonCardList(
                      count: 3,
                      height: 100,
                      padding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    error: (_, _) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Could not load stories', textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Pinned blue camera hero with semicircular bottom edge
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: heroHeight,
            child: _ScannerHero(user: user, taglineFromLeft: _taglineFromLeft),
          ),
        ],
      ),
    );
  }
}

/// Wraps a content block and feeds it to the Green Lens as it scrolls near:
/// the card swoops toward the camera button on a curved orbit (handedness
/// alternates per slot), tilts back in 3D perspective, spins and shrinks to
/// a point at the lens — absorbed by the black hole.
class _VortexItem extends StatefulWidget {
  final ScrollController controller;
  final double heroHeight;

  /// -1 orbits in from the left, 1 from the right.
  final int direction;
  final Widget child;

  const _VortexItem({
    required this.controller,
    required this.heroHeight,
    required this.direction,
    required this.child,
  });

  @override
  State<_VortexItem> createState() => _VortexItemState();
}

class _VortexItemState extends State<_VortexItem> {
  double? _restingTop;
  double _itemHeight = 0;

  void _measure() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    // Position the item would have at scroll offset 0.
    final top = box.localToGlobal(Offset.zero).dy + widget.controller.offset;
    if (_restingTop == null || (top - _restingTop!).abs() > 0.5) {
      setState(() {
        _restingTop = top;
        _itemHeight = box.size.height;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-measure after every (rare) outer rebuild — sections above this one
    // change height when async data replaces their loading skeletons.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final screenWidth = MediaQuery.of(context).size.width;
    return AnimatedBuilder(
      animation: widget.controller,
      child: widget.child,
      builder: (context, child) {
        if (_restingTop == null) return child!;
        final screenY = _restingTop! - widget.controller.offset;
        // Fully absorbed by the time the card reaches the hero's corner line
        // (where the arc meets the screen edges).
        // Zone kept short enough that resting content (top = heroHeight + 16)
        // sits below it untouched — the pull only starts once you scroll.
        final cornerY = widget.heroHeight * _HeroArcClipper.chordFraction;
        final progress =
            ((cornerY + 100.0 - screenY) / 100.0).clamp(0.0, 1.0);
        if (progress == 0) return child!;

        // The Green Lens centre — the mouth of the black hole.
        final lens = Offset(screenWidth / 2, widget.heroHeight * 0.52);
        final itemCenter = Offset(screenWidth / 2, screenY + _itemHeight / 2);

        final pull = Curves.easeInCubic.transform(progress);
        // Straight-line pull to the lens + a sideways orbital swing that
        // peaks mid-flight, giving a curved swoop into the hole.
        final dx = (lens.dx - itemCenter.dx) * pull +
            widget.direction * sin(pi * progress) * 130;
        final dy = (lens.dy - itemCenter.dy) * pull;

        final shrink = 1 - 0.95 * pull;
        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0012) // perspective for the 3D dive
          ..translateByDouble(dx, dy, 0, 1)
          ..rotateZ(widget.direction * 1.4 * pull) // spiral spin
          ..rotateX(1.1 * pull) // card tips backward into the lens
          ..scaleByDouble(shrink, shrink, shrink, 1); // shrinks to a point

        return Opacity(
          // Stays vivid through the swoop, vanishes right at the lens.
          opacity: (1 - progress * progress).clamp(0.0, 1.0),
          child: Transform(
            transform: matrix,
            alignment: Alignment.center,
            child: child,
          ),
        );
      },
    );
  }
}

// ── Scanner Hero — pinned Primary Blue header with semicircular bottom edge ──

class _ScannerHero extends ConsumerWidget {
  final dynamic user;
  final bool taglineFromLeft;
  const _ScannerHero({required this.user, required this.taglineFromLeft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagline = ref.watch(scanTaglineProvider).value ?? 'Every Scan Plants a Story.';
    return ClipPath(
      clipper: _HeroArcClipper(),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryBlue, Color(0xFF2D3A8C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Tagline drawn along the circular border; swings in from a
            // corner like a damped pendulum (see _ArcTagline).
            Positioned.fill(
              child: IgnorePointer(
                child: _ArcTagline(fromLeft: taglineFromLeft, text: tagline),
              ),
            ),
            SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
              child: Row(
                children: [
                  const Icon(Icons.eco_rounded, color: AppColors.primaryYellow, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'BlueDot',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  if (user != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt_rounded, color: AppColors.primaryYellow, size: 16),
                          const SizedBox(width: 4),
                          Text('${user.totalPoints} XP', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                        ],
                      ),
                    ),
                  const _NotificationBell(),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, -10),
                  child: GestureDetector(
                    onTap: () => context.push('/scanner'),
                    // Scales the button down instead of clipping when the
                    // hero is short (small devices / landscape).
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _PulsingScanButton(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tagline that swings along the hero's circular border like a damped
/// pendulum: released from the corner where the arc meets the screen edge,
/// it glides along the curve through the bottom and oscillates to rest.
class _ArcTagline extends StatefulWidget {
  final bool fromLeft;
  final String text;
  const _ArcTagline({required this.fromLeft, required this.text});

  @override
  State<_ArcTagline> createState() => _ArcTaglineState();
}

class _ArcTaglineState extends State<_ArcTagline> with TickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  // ── Gravity pendulum (devices with an accelerometer only) ────────────
  late final Ticker _ticker = createTicker(_onTick);
  StreamSubscription<AccelerometerEvent>? _accelSub;
  final ValueNotifier<double> _sensorSwing = ValueNotifier(0);
  double _target = 0; // equilibrium angle from current gravity direction
  double _angle = 0; // simulated pendulum angle
  double _vel = 0;
  double _lpX = 0, _lpY = 9.8; // low-pass filtered accelerometer
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Hold briefly after opening so the user notices the fall.
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _ctrl.forward();
    });
    // Tilt-to-swing: silently unavailable on devices without the sensor.
    debugPrint('🧭 [ArcTagline] Subscribing to accelerometer for tilt-swing…');
    try {
      _accelSub = accelerometerEventStream(
        samplingPeriod: SensorInterval.uiInterval,
      ).listen(
        _onAccel,
        onError: (e) {
          debugPrint('❌ [ArcTagline] Tilt sensor NOT available on this '
              'device — text stays static. ($e)');
          _accelSub?.cancel();
          _accelSub = null;
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('❌ [ArcTagline] Tilt sensor NOT available on this '
          'device — text stays static. ($e)');
      _accelSub = null;
    }
  }

  bool _loggedFirstEvent = false;
  double _lastRaw = 0;
  int _turns = 0; // full revolutions accumulated by unwrapping the roll

  void _onAccel(AccelerometerEvent e) {
    if (!_loggedFirstEvent) {
      _loggedFirstEvent = true;
      debugPrint('✅ [ArcTagline] Tilt sensor ACTIVE — first reading: '
          'x=${e.x.toStringAsFixed(2)}, y=${e.y.toStringAsFixed(2)}, '
          'z=${e.z.toStringAsFixed(2)} 🎉');
    }
    _lpX = _lpX * 0.8 + e.x * 0.2;
    _lpY = _lpY * 0.8 + e.y * 0.2;
    // Roll of the phone -> where "down" now is along the arc.
    final raw = atan2(_lpX, _lpY.abs().clamp(0.5, 20.0));
    // Unwrap across the ±π seam so a full physical rotation carries the
    // text 360° around the circle instead of snapping back the short way.
    final delta = raw - _lastRaw;
    if (delta > pi) {
      _turns -= 1;
    } else if (delta < -pi) {
      _turns += 1;
    }
    _lastRaw = raw;
    _target = raw + _turns * 2 * pi;
    if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 0.016
        : ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.001, 0.05);
    _lastTick = elapsed;
    // Underdamped spring = a pendulum that overshoots and settles.
    const omega = 5.5, zeta = 0.18;
    final acc = -omega * omega * (_angle - _target) - 2 * zeta * omega * _vel;
    _vel += acc * dt;
    _angle += _vel * dt;
    _sensorSwing.value = _angle;
    // Settled — stop ticking until the next tilt.
    if ((_angle - _target).abs() < 0.001 && _vel.abs() < 0.001) {
      // Shed whole revolutions so the numbers stay bounded.
      final wraps = (_target / (2 * pi)).round();
      if (wraps != 0) {
        _target -= wraps * 2 * pi;
        _angle -= wraps * 2 * pi;
        _turns -= wraps;
        _sensorSwing.value = _angle;
      }
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _ticker.dispose();
    _ctrl.dispose();
    _sensorSwing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_ctrl, _sensorSwing]),
      builder: (_, _) => CustomPaint(
        painter: _ArcTextPainter(
          progress: _ctrl.value,
          fromLeft: widget.fromLeft,
          sensorSwing: _sensorSwing.value,
          text: widget.text,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _ArcTextPainter extends CustomPainter {
  final double progress;
  final bool fromLeft;

  /// Extra swing angle from the device-tilt pendulum (radians).
  final double sensorSwing;

  final String text;

  _ArcTextPainter({
    required this.progress,
    required this.fromLeft,
    required this.text,
    this.sensorSwing = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Same circle as _HeroArcClipper.
    final chordY = size.height * _HeroArcClipper.chordFraction;
    final depth = size.height - chordY;
    final halfW = size.width / 2;
    final radius = (depth * depth + halfW * halfW) / (2 * depth);
    final center = Offset(halfW, size.height - radius);
    final textRadius = radius - 20; // baseline sits just inside the border

    final opacity = (progress / 0.06).clamp(0.0, 1.0);
    final style = TextStyle(
      color: AppColors.primaryYellow.withAlpha((255 * opacity).round()),
      fontSize: 17,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
    );

    // Lay out each glyph to know its arc length. Split by Unicode runes, not
    // UTF-16 code units -- code-unit splitting cuts surrogate-pair emoji in
    // half, producing a lone surrogate that Flutter rejects as malformed
    // UTF-16 on every repaint.
    final glyphs = <TextPainter>[];
    double totalWidth = 0;
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      final tp = TextPainter(
        text: TextSpan(text: ch, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      glyphs.add(tp);
      totalWidth += tp.width;
    }
    final totalAngle = totalWidth / textRadius;

    // Damped pendulum released from the corner of the arc.
    final cornerAngle = atan2(chordY - center.dy, -halfW); // left corner
    final swingRoom = (cornerAngle - pi / 2) - totalAngle / 2;
    final amplitude = max(swingRoom, 0.0);
    final sign = fromLeft ? 1.0 : -1.0;
    final entranceSwing =
        sign * amplitude * exp(-3.5 * progress) * cos(2 * pi * 2 * progress);
    // Gravity pendulum is unclamped: strong tilts carry the text past the
    // screen edges, and a full rotation takes it 360° around the circle.
    final swing = entranceSwing + sensorSwing;

    // Paint glyphs along the arc, reading left -> right.
    double angle = pi / 2 + swing + totalAngle / 2;
    for (final tp in glyphs) {
      final charAngle = angle - (tp.width / 2) / textRadius;
      final pos = center +
          Offset(cos(charAngle), sin(charAngle)) * textRadius;
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(charAngle - pi / 2); // upright relative to the curve
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
      angle -= tp.width / textRadius;
    }
  }

  @override
  bool shouldRepaint(_ArcTextPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.fromLeft != fromLeft ||
      oldDelegate.sensorSwing != sensorSwing ||
      oldDelegate.text != text;
}

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
          onPressed: () => context.push('/notifications'),
        ),
        if (unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 18),
              decoration: BoxDecoration(
                color: AppColors.terracotta,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primaryBlue, width: 1.5),
              ),
              child: Text(
                unread > 9 ? '9+' : '$unread',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }
}

/// Clips the hero so its bottom edge bulges downward in a true circular arc.
class _HeroArcClipper extends CustomClipper<Path> {
  /// Fraction of the hero height where the arc meets the side edges —
  /// also the line where the content suck-in effect completes.
  static const double chordFraction = 0.60;

  @override
  Path getClip(Size size) {
    final chordY = size.height * chordFraction;
    final depth = size.height - chordY; // arc dips to the full hero height
    final halfW = size.width / 2;
    // Radius of the circle passing through both chord ends and the lowest point
    final radius = (depth * depth + halfW * halfW) / (2 * depth);
    final path = Path()
      ..lineTo(0, chordY)
      ..arcToPoint(
        Offset(size.width, chordY),
        radius: Radius.circular(radius),
        clockwise: false,
      )
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _PulsingScanButton extends StatelessWidget {
  const _PulsingScanButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      height: 170,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Expanding radar rings — alpha animated via border color (an Opacity
          // layer over a stroke-only shape triggers Impeller validation errors)
          for (int i = 0; i < 3; i++)
            const SizedBox(width: 170, height: 170)
                .animate(onPlay: (c) => c.repeat())
                .custom(
                  delay: (i * 700).ms,
                  duration: 2200.ms,
                  curve: Curves.easeOut,
                  builder: (_, value, _) => Transform.scale(
                    scale: 0.55 + 0.45 * value,
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

          // Soft glow behind the artwork — alpha animated via shadow color
          const SizedBox(width: 124, height: 124)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .custom(
                duration: 1800.ms,
                curve: Curves.easeInOut,
                builder: (_, value, _) => Transform.scale(
                  scale: 1 + 0.06 * value,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryYellow.withAlpha((130 * value).round()),
                          blurRadius: 30,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

          // The Green Lens artwork — zoomed out inside the white circle
          ClipOval(
            child: Container(
              width: 124,
              height: 124,
              color: Colors.white,
              padding: const EdgeInsets.all(16),
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

class _HomeQuickActions extends StatelessWidget {
  const _HomeQuickActions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _QuickActionPill(
              icon: Icons.map_rounded,
              label: 'Eco Garden',
              sublabel: 'View your trees',
              color: AppColors.forestGreen,
              onTap: () => context.push('/map'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionPill(
              icon: Icons.leaderboard_rounded,
              label: 'Leaderboard',
              sublabel: 'See your rank',
              color: AppColors.primaryBlue,
              onTap: () => context.push('/profile/leaderboard'),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }
}

class _QuickActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionPill({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color.withAlpha(15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withAlpha(50)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13)),
                    Text(sublabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMedium, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _BlogGrid extends StatelessWidget {
  final List<BlogPost> blogs;
  final Widget Function(int, Widget) itemWrapper;
  const _BlogGrid({required this.blogs, required this.itemWrapper});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: blogs.length.clamp(0, 6),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => itemWrapper(
        i,
        _BlogCard(blog: blogs[i])
            .animate()
            .fadeIn(delay: (100 * i).ms)
            .slideY(begin: 0.1, end: 0, delay: (100 * i).ms),
      ),
    );
  }
}

class _BlogCard extends StatelessWidget {
  final BlogPost blog;
  const _BlogCard({required this.blog});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/home/blog/${blog.slug}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            if (blog.thumbnailUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
                child: CachedNetworkImage(
                  imageUrl: blog.thumbnailUrl!,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(color: AppColors.borderLight),
                  errorWidget: (_, _, _) => Container(
                    color: AppColors.primaryBlue.withAlpha(20),
                    child: const Icon(Icons.article_rounded, color: AppColors.slateBlue),
                  ),
                ),
              )
            else
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Color(0xFFECF0FF),
                  borderRadius: BorderRadius.horizontal(left: Radius.circular(15)),
                ),
                child: const Icon(Icons.article_rounded, color: AppColors.primaryBlue, size: 32),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      blog.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    if (blog.excerpt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        blog.excerpt!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textMedium),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 12, color: AppColors.textLight),
                        const SizedBox(width: 4),
                        Text(blog.author ?? 'BlueDot', style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                        const Spacer(),
                        const Icon(Icons.remove_red_eye_outlined, size: 12, color: AppColors.textLight),
                        const SizedBox(width: 4),
                        Text('${blog.views}', style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

