import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/skeletons.dart';
import '../../action_hub/models/event_model.dart';
import '../models/campaign_model.dart';
import '../models/banner_model.dart';
import '../models/blog_model.dart';
import '../providers/home_provider.dart';
import '../widgets/promo_banner_carousel.dart';
import '../widgets/acoustic_meter_sheet.dart';
import '../../auth/providers/auth_provider.dart';
import '../../legal/services/legal_service.dart';
import '../../legal/widgets/policy_update_sheet.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/utils/route_dispatcher.dart';

/// The primary discovery dashboard for BlueDot.
///
/// Features a polished, modern ecological aesthetic with:
/// - Hero Header with personalized time-based greeting & notification counter
/// - Prominent Green Lens AI Tree Scanner Card (Hero feature)
/// - 4-Pillar Tactile Quick Actions (Eco Garden, Leaderboard, Suggest Site, Directory)
/// - Dynamic Promo Carousel
/// - Upcoming Plantation Drives & Community Events
/// - Crowdfunding & Active Environmental Campaigns
/// - Ecological Stories, Research & Educational Updates
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scroll = ScrollController();
  StreamSubscription<Map<String, dynamic>>? _foregroundPushSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPolicyConsent();
      ref
          .read(pushNotificationServiceProvider)
          .initialize(requestPermission: true);
      ref
          .read(pushNotificationServiceProvider)
          .processPendingNotification(context);

      _foregroundPushSub = ref
          .read(pushNotificationServiceProvider)
          .foregroundEvents
          .listen((data) {
            if (!mounted) return;
            ref.read(notificationsProvider.notifier).refresh();
            final title = data['title']?.toString() ?? 'BlueDot Notification';
            final body = data['body']?.toString() ?? '';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.textDark,
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (body.isNotEmpty)
                      Text(
                        body,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Colors.white70,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'View',
                  textColor: AppColors.primaryYellow,
                  onPressed: () {
                    RouteDispatcher.dispatch(
                      context,
                      route: data['route']?.toString(),
                      type: data['type']?.toString(),
                      data: data,
                    );
                  },
                ),
              ),
            );
          });
    });
  }

  Future<void> _checkPolicyConsent() async {
    final status = await ref.read(legalServiceProvider).checkConsentStatus();
    if (status.requiresConsent && mounted) {
      PolicyUpdateSheet.show(context, status.pendingDocuments);
    }
  }

  @override
  void dispose() {
    _foregroundPushSub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final homeFeedAsync = ref.watch(homeFeedProvider);
    final blogs = ref.watch(blogsProvider);

    return Scaffold(
      backgroundColor:
          AppColors.backgroundCream, // Refined clean organic background
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homeFeedProvider);
          ref.invalidate(blogsProvider);
          await Future.wait([
            ref.read(homeFeedProvider.future),
            ref.read(blogsProvider.future),
          ]);
        },
        color: AppColors.primaryBlue,
        backgroundColor: Colors.white,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // ── 1. Clean Modern Brand Top Bar (Rich Blue) ─────────────────
            SliverAppBar(
              pinned: true,
              floating: false,
              backgroundColor: AppColors.primaryBlue,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              elevation: 0,
              scrolledUnderElevation: 2,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              flexibleSpace: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primaryBlue, Color(0xFF28367F)],
                    ),
                  ),
                ),
              ),
              titleSpacing: 18,
              title: Row(
                children: [
                  // BlueDot Conservation logo and branding.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        AppAssets.bluedotIcon,
                        width: 34,
                        height: 34,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.eco_rounded,
                            color: AppColors.primaryBlue,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'BlueDot',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            'CONSERVATION',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.8,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  const _NotificationBell(isDarkHeader: true),
                  const SizedBox(width: 6),
                  // User Avatar
                  GestureDetector(
                    onTap: () => context.go('/profile'),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryYellow,
                          width: 1.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: user?.avatarUrl != null
                            ? CachedNetworkImage(
                                imageUrl: user!.avatarUrl!,
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: AppColors.primaryBlue,
                                  child: const Center(
                                    child: SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white70,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: AppColors.primaryBlue,
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              )
                            : Container(
                                color: AppColors.primaryYellow,
                                alignment: Alignment.center,
                                child: Text(
                                  (user?.fullName?.isNotEmpty ?? false)
                                      ? user!.fullName![0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── 2. Greeting & Status Row ───────────────────────────────────
            SliverToBoxAdapter(
              child:
                  _GreetingRow(
                        greeting: _getTimeGreeting(),
                        userName: user?.fullName,
                        xpPoints: user?.totalPoints ?? 0,
                      )
                      .animate()
                      .fadeIn(duration: 350.ms)
                      .slideY(begin: 0.04, end: 0, curve: Curves.easeOut),
            ),

            // ── 3. Local Eco Vitals Section (AQI, UV, Thermal & Noise) ────
            SliverToBoxAdapter(
              child: const _EcoVitalsSection()
                  .animate()
                  .fadeIn(delay: 50.ms, duration: 350.ms)
                  .slideY(begin: 0.04, end: 0, curve: Curves.easeOut),
            ),

            // ── 4. Published Home Hero ──────────────────────────
            SliverToBoxAdapter(
              child:
                  switch (homeFeedAsync) {
                        AsyncData(:final value) when value.hero != null =>
                          _HomeHeroCard(banner: value.hero!),
                        AsyncError() => Center(
                          child: TextButton(
                            onPressed: () => ref.invalidate(homeFeedProvider),
                            child: const Text('Could not load Home. Retry'),
                          ),
                        ),
                        _ => const SizedBox.shrink(),
                      }
                  .animate()
                  .fadeIn(delay: 100.ms, duration: 400.ms)
                  .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
            ),

            // ── 5. Direct Action / Daily Impact (3-Card Row) ───────────────
            SliverToBoxAdapter(
              child: const _DirectActionsRow()
                  .animate()
                  .fadeIn(delay: 150.ms, duration: 400.ms)
                  .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
            ),

            // ── 6. Instant Flora Scanner (Field Bio-Intelligence) ──────────
            SliverToBoxAdapter(
              child: const _InstantFloraScannerCard()
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 400.ms)
                  .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
            ),

            // ── 7. Promo Banners Carousel (Graceful Adaptive Layout) ──────
            if (homeFeedAsync.maybeWhen(
              data: (feed) => feed.banners.isNotEmpty,
              orElse: () => false,
            ))
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child:
                      PromoBannerCarousel(
                            banners: homeFeedAsync.asData!.value.banners,
                          )
                          .animate()
                          .fadeIn(duration: 350.ms)
                          .slideY(begin: 0.04, end: 0, curve: Curves.easeOut),
                ),
              ),

            // ── 8. Upcoming Events Section ─────────────────────────────────
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Upcoming Drives',
                icon: Icons.event_available_rounded,
                actionLabel: 'View all',
                onAction: () => context.go('/action-hub?tab=1'),
              ),
            ),
            SliverToBoxAdapter(
              child: homeFeedAsync.when(
                data: (feed) => feed.events.isEmpty
                    ? const _EmptySectionCard(
                        icon: Icons.park_outlined,
                        message: 'No upcoming plantation drives scheduled yet.',
                      )
                    : SizedBox(
                            height: 226,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: feed.events.length,
                              itemBuilder: (_, i) =>
                                  _HomeEventCard(event: feed.events[i]),
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 350.ms)
                          .slideX(
                            begin: 0.04,
                            end: 0,
                            curve: Curves.easeOutCubic,
                          ),
                loading: () => const SkeletonCardList(
                  count: 2,
                  height: 220,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                ),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),

            // ── 6. Active Campaigns Section ────────────────────────────────
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Active Campaigns',
                icon: Icons.volunteer_activism_rounded,
                actionLabel: 'View all',
                onAction: () => context.go('/action-hub?tab=0'),
              ),
            ),
            SliverToBoxAdapter(
              child: homeFeedAsync.when(
                data: (feed) => feed.campaigns.isEmpty
                    ? const _EmptySectionCard(
                        icon: Icons.campaign_outlined,
                        message:
                            'No active fundraising campaigns at the moment.',
                      )
                    : SizedBox(
                            height: 216,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: feed.campaigns.length,
                              itemBuilder: (_, i) => _HomeCampaignCard(
                                campaign: feed.campaigns[i],
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 350.ms)
                          .slideX(
                            begin: 0.04,
                            end: 0,
                            curve: Curves.easeOutCubic,
                          ),
                loading: () => const SkeletonCardList(
                  count: 2,
                  height: 220,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                ),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),

            // ── 7. Stories & Updates Section ───────────────────────────────
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Stories & Eco Updates',
                icon: Icons.auto_stories_rounded,
                actionLabel: 'See all',
                onAction: () => context.push('/home/blogs'),
              ),
            ),
            SliverToBoxAdapter(
              child: blogs.when(
                data: (list) => list.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.fromLTRB(24, 0, 24, 120),
                        child: _EmptySectionCard(
                          icon: Icons.article_outlined,
                          message: 'No stories published yet.',
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 120),
                        child: _BlogGrid(blogs: list),
                      ),
                loading: () => const SkeletonCardList(
                  count: 3,
                  height: 100,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                ),
                error: (_, _) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Could not load stories. Pull to refresh.',
                      style: TextStyle(color: AppColors.textMedium),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GREETING & XP POINTS ROW
// ─────────────────────────────────────────────────────────────────────────────

class _GreetingRow extends StatelessWidget {
  final String greeting;
  final String? userName;
  final int xpPoints;

  const _GreetingRow({
    required this.greeting,
    this.userName,
    this.xpPoints = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      '$greeting,',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('🌱', style: TextStyle(fontSize: 18)),
                  ],
                ),
                Text(
                  userName?.isNotEmpty == true ? userName! : 'Elena',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    letterSpacing: -0.6,
                    height: 1.15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                const Text(
                  "Let's nurture our living planet together today.",
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMedium,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Live XP Points Pill (Tap navigates to Leaderboard)
          GestureDetector(
            onTap: () => context.push('/profile/leaderboard'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFFDE68A),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    color: Color(0xFFD97706),
                    size: 15,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_formatXpNumber(xpPoints)} XP',
                    style: const TextStyle(
                      color: Color(0xFF92400E),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOCAL ECO VITALS SECTION (AQI, UV, THERMAL COMFORT & NOISE)
// ─────────────────────────────────────────────────────────────────────────────

class _EcoVitalsSection extends ConsumerWidget {
  const _EcoVitalsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readings = ref.watch(cityAqiProvider);
    final vitals = readings.asData?.value;
    if (vitals == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Local Eco Vitals',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    readings.isLoading
                        ? 'Loading local readings…'
                        : 'Local readings are unavailable.',
                  ),
                ),
                if (!readings.isLoading)
                  TextButton(
                    onPressed: () => ref.invalidate(cityAqiProvider),
                    child: const Text('Retry'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _noiseCard(context),
          ],
        ),
      );
    }

    // Color & icon for AQI
    final Color aqiColor;
    final Color aqiBg;
    if (vitals.aqi <= 50) {
      aqiColor = const Color(0xFF16A34A);
      aqiBg = const Color(0xFFDCFCE7);
    } else if (vitals.aqi <= 100) {
      aqiColor = const Color(0xFFD97706);
      aqiBg = const Color(0xFFFEF3C7);
    } else if (vitals.aqi <= 150) {
      aqiColor = const Color(0xFFEA580C);
      aqiBg = const Color(0xFFFFEDD5);
    } else {
      aqiColor = const Color(0xFFDC2626);
      aqiBg = const Color(0xFFFEE2E2);
    }

    // Color for UV
    final Color uvColor;
    final Color uvBg;
    if (vitals.uvIndex < 3) {
      uvColor = const Color(0xFF16A34A);
      uvBg = const Color(0xFFDCFCE7);
    } else if (vitals.uvIndex < 6) {
      uvColor = const Color(0xFFD97706);
      uvBg = const Color(0xFFFEF3C7);
    } else if (vitals.uvIndex < 8) {
      uvColor = const Color(0xFFEA580C);
      uvBg = const Color(0xFFFFEDD5);
    } else {
      uvColor = const Color(0xFFDC2626);
      uvBg = const Color(0xFFFEE2E2);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.sensors_rounded,
                    size: 18,
                    color: AppColors.forestGreen,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Local Eco Vitals',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3EB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC7E2CA)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF16A34A),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      vitals.city,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B3B22),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 2x2 Vitals Grid
          Row(
            children: [
              // 1. Air Quality (AQI)
              Expanded(
                child: _VitalCard(
                  onTap: () => _showAqiDetail(context, vitals),
                  icon: Icons.air_rounded,
                  iconColor: aqiColor,
                  iconBg: aqiBg,
                  label: 'Air Quality',
                  metric: 'AQI ${vitals.aqi}',
                  badgeText: vitals.status,
                  badgeColor: aqiColor,
                  badgeBg: aqiBg,
                  subtext: vitals.pm25 != null
                      ? 'PM2.5: ${vitals.pm25!.toStringAsFixed(1)}'
                      : 'PM2.5 unavailable',
                ),
              ),
              const SizedBox(width: 10),
              // 2. Solar UV Index
              Expanded(
                child: _VitalCard(
                  onTap: () => _showUvDetail(context, vitals),
                  icon: Icons.wb_sunny_rounded,
                  iconColor: uvColor,
                  iconBg: uvBg,
                  label: 'Solar UV',
                  metric: 'UV ${vitals.uvIndex.toStringAsFixed(1)}',
                  badgeText: vitals.uvStatus,
                  badgeColor: uvColor,
                  badgeBg: uvBg,
                  subtext: 'Canopy shade',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // 3. Thermal Comfort & Humidity
              Expanded(
                child: _VitalCard(
                  onTap: () => _showThermalDetail(context, vitals),
                  icon: Icons.thermostat_rounded,
                  iconColor: const Color(0xFF0284C7),
                  iconBg: const Color(0xFFE0F2FE),
                  label: 'Comfort',
                  metric: '${vitals.temperature.round()}°C',
                  badgeText: 'Feels ${vitals.feelsLike.round()}°',
                  badgeColor: const Color(0xFF0284C7),
                  badgeBg: const Color(0xFFE0F2FE),
                  subtext: '${vitals.humidity}% • ${vitals.comfortStatus}',
                ),
              ),
              const SizedBox(width: 10),
              // 4. Acoustic Tranquility (Phone Mic Noise Meter)
              Expanded(child: _noiseCard(context)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _noiseCard(BuildContext context) => _VitalCard(
    onTap: () => AcousticMeterSheet.show(context),
    icon: Icons.graphic_eq_rounded,
    iconColor: const Color(0xFF059669),
    iconBg: const Color(0xFFECFDF5),
    label: 'Noise & Calm',
    metric: 'Decibels',
    badgeText: 'Sample',
    badgeColor: const Color(0xFF059669),
    badgeBg: const Color(0xFFECFDF5),
    subtext: 'Tap to measure dB',
  );

  void _showAqiDetail(BuildContext context, CityAqiData aqi) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AqiDetailSheet(aqi: aqi),
    );
  }

  void _showUvDetail(BuildContext context, CityAqiData vitals) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _UvDetailSheet(vitals: vitals),
    );
  }

  void _showThermalDetail(BuildContext context, CityAqiData vitals) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ThermalDetailSheet(vitals: vitals),
    );
  }
}

/// Compact tactile card for each environmental vital.
class _VitalCard extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String metric;
  final String badgeText;
  final Color badgeColor;
  final Color badgeBg;
  final String subtext;

  const _VitalCard({
    required this.onTap,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.metric,
    required this.badgeText,
    required this.badgeColor,
    required this.badgeBg,
    required this.subtext,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: iconColor.withOpacity(0.08),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(icon, color: iconColor, size: 16),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                metric,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtext,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textMedium,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Backward compatibility alias for _CityAqiBar
class _CityAqiBar extends StatelessWidget {
  const _CityAqiBar();

  @override
  Widget build(BuildContext context) {
    return const _EcoVitalsSection();
  }
}

class _AqiDetailSheet extends StatelessWidget {
  final CityAqiData aqi;
  const _AqiDetailSheet({required this.aqi});

  @override
  Widget build(BuildContext context) {
    final Color badgeColor;
    if (aqi.aqi <= 50) {
      badgeColor = const Color(0xFF16A34A);
    } else if (aqi.aqi <= 100) {
      badgeColor = const Color(0xFFD97706);
    } else if (aqi.aqi <= 150) {
      badgeColor = const Color(0xFFEA580C);
    } else {
      badgeColor = const Color(0xFFDC2626);
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        22,
        14,
        22,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.12),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.air_rounded, color: badgeColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Air Quality Index (AQI)',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Live reading for ${aqi.city}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeColor.withOpacity(0.3)),
                ),
                child: Text(
                  '${aqi.aqi} AQI',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.backgroundCream,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.textMedium),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    aqi.recommendation,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textDark,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (aqi.pm25 != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.grain_rounded, size: 16, color: AppColors.textMedium),
                const SizedBox(width: 6),
                Text(
                  'PM2.5: ${aqi.pm25!.toStringAsFixed(1)} µg/m³',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMedium,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          // Educational impact card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3EB),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.park_rounded, color: Color(0xFF2E5A36), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Urban tree canopies act as living filters, absorbing particulate pollutants and generating oxygen. Tag and plant trees to heal the air!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1B3B22),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/map');
              },
              icon: const Icon(Icons.explore_rounded, size: 18),
              label: const Text('Explore Canopy Tree Map'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SOLAR UV INDEX & CANOPY SHADE MODAL SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _UvDetailSheet extends StatelessWidget {
  final CityAqiData vitals;
  const _UvDetailSheet({required this.vitals});

  @override
  Widget build(BuildContext context) {
    final Color uvColor;
    if (vitals.uvIndex < 3) {
      uvColor = const Color(0xFF16A34A);
    } else if (vitals.uvIndex < 6) {
      uvColor = const Color(0xFFD97706);
    } else if (vitals.uvIndex < 8) {
      uvColor = const Color(0xFFEA580C);
    } else {
      uvColor = const Color(0xFFDC2626);
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        22,
        14,
        22,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.12),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: uvColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.wb_sunny_rounded, color: uvColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Solar UV Index',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Live solar radiation in ${vitals.city}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: uvColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: uvColor.withOpacity(0.3)),
                ),
                child: Text(
                  'UV ${vitals.uvIndex.toStringAsFixed(1)} • ${vitals.uvStatus}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: uvColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.backgroundCream,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.textMedium),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    vitals.uvAdvisory,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textDark,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Tree Canopy UV Shield Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3EB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFC7E2CA)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.park_rounded, color: Color(0xFF2E5A36), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tree Canopies: Living UV Sunscreen',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B3B22),
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Dense urban tree leaves absorb up to 90% of harmful UV-A & UV-B radiation. Walking and living under green canopy corridors protects your skin naturally!',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF2E5A36),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/map');
              },
              icon: const Icon(Icons.explore_rounded, size: 18),
              label: const Text('Find Shaded Tree Canopies on Map'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THERMAL COMFORT & HUMIDITY MODAL SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _ThermalDetailSheet extends StatelessWidget {
  final CityAqiData vitals;
  const _ThermalDetailSheet({required this.vitals});

  @override
  Widget build(BuildContext context) {
    const Color themeColor = Color(0xFF0284C7);

    return Container(
      padding: EdgeInsets.fromLTRB(
        22,
        14,
        22,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.12),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.thermostat_rounded, color: themeColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thermal Comfort & Climate',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Temperature & humidity',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: themeColor.withOpacity(0.3)),
                ),
                child: Text(
                  '${vitals.temperature.round()}°C',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: themeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Comfort Metrics Grid
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.backgroundCream,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('Feels Like', style: TextStyle(fontSize: 11.5, color: AppColors.textMedium)),
                    const SizedBox(height: 2),
                    Text('${vitals.feelsLike.round()}°C', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                  ],
                ),
                Container(width: 1, height: 32, color: AppColors.borderLight),
                Column(
                  children: [
                    const Text('Humidity', style: TextStyle(fontSize: 11.5, color: AppColors.textMedium)),
                    const SizedBox(height: 2),
                    Text('${vitals.humidity}%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                  ],
                ),
                Container(width: 1, height: 32, color: AppColors.borderLight),
                Column(
                  children: [
                    const Text('Status', style: TextStyle(fontSize: 11.5, color: AppColors.textMedium)),
                    const SizedBox(height: 2),
                    Text(vitals.comfortStatus, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: themeColor)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Heat Island & Tree Cooling Impact Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3EB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFC7E2CA)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.park_rounded, color: Color(0xFF2E5A36), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Urban Heat Island Mitigation',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B3B22),
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Through direct shade and leaf evapotranspiration, mature urban tree canopies lower localized ambient heat by 2°C to 8°C and cool asphalt surfaces by up to 12°C!',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF2E5A36),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/map');
              },
              icon: const Icon(Icons.explore_rounded, size: 18),
              label: const Text('Explore Urban Canopy Map'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// "PROTECT THE CANOPY" HERO CARD
// ─────────────────────────────────────────────────────────────────────────────

class _HomeHeroCard extends StatelessWidget {
  const _HomeHeroCard({required this.banner});

  final AppBanner banner;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (banner.title?.isNotEmpty ?? false)
          Text(banner.title!, style: Theme.of(context).textTheme.titleLarge),
        if (banner.subtitle?.isNotEmpty ?? false) Text(banner.subtitle!),
        const SizedBox(height: 8),
        PromoBannerCarousel(banners: [banner]),
      ],
    );
  }
}

class _DirectActionsRow extends StatelessWidget {
  const _DirectActionsRow();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Direct Access',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                'Quick Explore',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMedium,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _DirectActionCard(
                  icon: Icons.leaderboard_rounded,
                  iconColor: AppColors.primaryBlue,
                  iconBg: const Color(0xFFEEF1FD),
                  title: 'Leaderboard',
                  tag: 'Rankings',
                  tagColor: AppColors.primaryBlue,
                  onTap: () => context.push('/profile/leaderboard'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DirectActionCard(
                  icon: Icons.map_rounded,
                  iconColor: const Color(0xFF386641),
                  iconBg: const Color(0xFFEAF3EB),
                  title: 'Map View',
                  tag: 'Eco Garden',
                  tagColor: const Color(0xFF386641),
                  onTap: () => context.push('/map'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DirectActionCard(
                  icon: Icons.add_location_alt_rounded,
                  iconColor: const Color(0xFFC76D4D),
                  iconBg: const Color(0xFFFDF0EC),
                  title: 'Suggest Site',
                  tag: 'New Land',
                  tagColor: const Color(0xFFC76D4D),
                  onTap: () => context.push('/action-hub/suggest-site'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DirectActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String tag;
  final Color tagColor;
  final VoidCallback onTap;

  const _DirectActionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.tag,
    required this.tagColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: iconColor.withOpacity(0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.025),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 23),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                  fontSize: 12.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tag,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: tagColor,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INSTANT FLORA SCANNER CARD
// ─────────────────────────────────────────────────────────────────────────────

class _InstantFloraScannerCard extends StatelessWidget {
  const _InstantFloraScannerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => context.push('/scanner'),
          borderRadius: BorderRadius.circular(20),
          splashColor: AppColors.primaryGreen.withOpacity(0.08),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header row (Clean title without subtitle text)
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Instant Flora Scanner',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.ecoIndexBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.ecoIndexBorder),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            color: Color(0xFFC2851B),
                            size: 14,
                          ),
                          SizedBox(width: 3),
                          Text(
                            '+50 XP',
                            style: TextStyle(
                              color: AppColors.ecoIndexText,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 2. Botanical Viewfinder Frame (Real botanical backdrop + BlueDot Yellow reticle)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: Stack(
                      alignment: Alignment.center,
                      fit: StackFit.expand,
                      children: [
                        // Real botanical plant backdrop (lush monstera leaf)
                        CachedNetworkImage(
                          imageUrl:
                              'https://images.unsplash.com/photo-1518531933037-91b2f5f229cc?auto=format&fit=crop&w=800&q=80',
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppColors.forestGreen,
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.forestGreen,
                          ),
                        ),

                        // Natural dark gradient vignette for contrast
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.15),
                                Colors.black.withOpacity(0.55),
                              ],
                            ),
                          ),
                        ),

                        // DSLR viewfinder corner reticle in BlueDot yellow
                        const CustomPaint(
                          size: Size.infinite,
                          painter: _ViewfinderCornerPainter(
                            color: AppColors.scannerReticle,
                            strokeWidth: 2.5,
                            length: 22.0,
                          ),
                        ),

                        // Center focus reticle box
                        Center(
                          child: Container(
                            width: 86,
                            height: 86,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color:
                                    AppColors.scannerReticle.withOpacity(0.65),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),

                        // Bottom camera action pill
                        Positioned(
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.20),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.center_focus_strong_rounded,
                                  color: AppColors.primaryYellow,
                                  size: 15,
                                ),
                                SizedBox(width: 7),
                                Text(
                                  'Tap to scan & identify any plant',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewfinderCornerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double length;

  const _ViewfinderCornerPainter({
    required this.color,
    this.strokeWidth = 2.5,
    this.length = 22.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const double inset = 16.0;

    // Top-Left
    canvas.drawLine(
      Offset(inset, inset + length),
      const Offset(inset, inset),
      paint,
    );
    canvas.drawLine(
      const Offset(inset, inset),
      Offset(inset + length, inset),
      paint,
    );

    // Top-Right
    canvas.drawLine(
      Offset(size.width - inset - length, inset),
      Offset(size.width - inset, inset),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(size.width - inset, inset + length),
      paint,
    );

    // Bottom-Left
    canvas.drawLine(
      Offset(inset, size.height - inset - length),
      Offset(inset, size.height - inset),
      paint,
    );
    canvas.drawLine(
      Offset(inset, size.height - inset),
      Offset(inset + length, size.height - inset),
      paint,
    );

    // Bottom-Right
    canvas.drawLine(
      Offset(size.width - inset - length, size.height - inset),
      Offset(size.width - inset, size.height - inset),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - inset, size.height - inset - length),
      Offset(size.width - inset, size.height - inset),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ViewfinderCornerPainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      length != oldDelegate.length;
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: AppColors.forestGreen),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 10),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EVENT CARD
// ─────────────────────────────────────────────────────────────────────────────

class _HomeEventCard extends StatelessWidget {
  final PlantationEvent event;
  const _HomeEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/action-hub/event/${event.id}'),
      child: Container(
        width: 270,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderLight.withOpacity(0.7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with floating chips
            Stack(
              children: [
                if (event.thumbnailUrl != null)
                  CachedNetworkImage(
                    imageUrl: event.thumbnailUrl!,
                    height: 118,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(
                      height: 118,
                      color: AppColors.borderLight.withOpacity(0.5),
                    ),
                    errorWidget: (_, _, _) => Container(
                      height: 118,
                      color: AppColors.forestGreen.withOpacity(0.12),
                      child: const Icon(
                        Icons.park,
                        color: AppColors.forestGreen,
                        size: 36,
                      ),
                    ),
                  )
                else
                  Container(
                    height: 118,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.forestGreen.withOpacity(0.2),
                          AppColors.forestGreen.withOpacity(0.08),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.park,
                        color: AppColors.forestGreen,
                        size: 36,
                      ),
                    ),
                  ),

                // Date Chip (Top-Left)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.68),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_month_rounded,
                          color: AppColors.primaryYellow,
                          size: 11,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          event.formattedDate,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Status Tag (Top-Right)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: event.isPlantationDrive
                          ? AppColors.forestGreen
                          : AppColors.primaryBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      event.isPlantationDrive
                          ? 'Drive'
                          : (event.eventStatus ?? 'Upcoming'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Card Body
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: AppColors.textDark,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (event.description != null && event.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      _cleanDescription(event.description),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMedium,
                        fontWeight: FontWeight.w400,
                        height: 1.25,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  // Location
                  Row(
                    children: [
                      const Icon(
                        Icons.place_rounded,
                        size: 13,
                        color: AppColors.terracotta,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.siteName ?? 'Eco Plantation Site',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMedium,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Footer with spots & duration
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${event.spotsLeft ?? 'Open'} spots left',
                          style: const TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (event.formattedDuration != null)
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 11,
                              color: AppColors.textLight,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              event.formattedDuration!,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.textLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// CAMPAIGN CARD
// ─────────────────────────────────────────────────────────────────────────────

class _HomeCampaignCard extends StatelessWidget {
  final Campaign campaign;
  const _HomeCampaignCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final pct = campaign.progressPercent;
    return GestureDetector(
      onTap: () => context.push('/action-hub/campaign/${campaign.id}'),
      child: Container(
        width: 270,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderLight.withOpacity(0.7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Stack(
              children: [
                if (campaign.thumbnailUrl != null)
                  CachedNetworkImage(
                    imageUrl: campaign.thumbnailUrl!,
                    height: 118,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(
                      height: 118,
                      color: AppColors.borderLight.withOpacity(0.5),
                    ),
                    errorWidget: (_, _, _) => Container(
                      height: 118,
                      color: AppColors.primaryBlue.withOpacity(0.12),
                      child: const Icon(
                        Icons.campaign,
                        color: AppColors.primaryBlue,
                        size: 36,
                      ),
                    ),
                  )
                else
                  Container(
                    height: 118,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryBlue.withOpacity(0.18),
                          AppColors.primaryBlue.withOpacity(0.06),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.campaign,
                        color: AppColors.primaryBlue,
                        size: 36,
                      ),
                    ),
                  ),

                // Goal Pill (Top-Right)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryYellow,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'Goal: ₹${(campaign.targetAmount / 1000).toStringAsFixed(0)}k',
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Card Body
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    campaign.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: AppColors.textDark,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (campaign.description != null && campaign.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      _cleanDescription(campaign.description),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMedium,
                        fontWeight: FontWeight.w400,
                        height: 1.25,
                      ),
                    ),
                  ],
                  const SizedBox(height: 7),
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0, 1),
                      backgroundColor: AppColors.borderLight,
                      color: AppColors.forestGreen,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 7),
                  // Financial Stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '₹${campaign.currentAmountRaised.toInt()}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                            const TextSpan(
                              text: ' raised',
                              style: TextStyle(
                                color: AppColors.textMedium,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.forestGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${(pct * 100).toInt()}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: AppColors.forestGreen,
                          ),
                        ),
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// BLOGS GRID
// ─────────────────────────────────────────────────────────────────────────────

class _BlogGrid extends StatelessWidget {
  final List<BlogPost> blogs;
  const _BlogGrid({required this.blogs});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: blogs.length.clamp(0, 3),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _BlogCard(blog: blogs[i])
          .animate()
          .fadeIn(delay: (70 * i).ms, duration: 350.ms)
          .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderLight.withOpacity(0.7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.025),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // Thumbnail
            Stack(
              children: [
                if (blog.thumbnailUrl != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(17),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: blog.thumbnailUrl!,
                      width: 104,
                      height: 104,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: AppColors.borderLight),
                      errorWidget: (_, _, _) => Container(
                        width: 104,
                        height: 104,
                        color: AppColors.primaryBlue.withOpacity(0.1),
                        child: const Icon(
                          Icons.article_rounded,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 104,
                    height: 104,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEDF1F7),
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(17),
                      ),
                    ),
                    child: const Icon(
                      Icons.article_rounded,
                      color: AppColors.primaryBlue,
                      size: 32,
                    ),
                  ),

                if (blog.mediaUrls.length > 1)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.photo_library_rounded,
                            size: 9,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${blog.mediaUrls.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      blog.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: AppColors.textDark,
                        height: 1.25,
                      ),
                    ),
                    if (blog.excerpt != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        _stripHtmlIfNeeded(blog.excerpt!),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMedium,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          size: 12,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            blog.author ?? 'BlueDot',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (blog.publishedAt != null)
                          Text(
                            _formatDateShort(blog.publishedAt!),
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textLight,
                            ),
                          ),
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

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION BELL WITH BADGE
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationBell extends ConsumerWidget {
  final bool isDarkHeader;
  const _NotificationBell({this.isDarkHeader = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(
            Icons.notifications_none_rounded,
            color: isDarkHeader ? Colors.white : AppColors.textDark,
            size: 26,
          ),
          tooltip: 'Notifications',
          onPressed: () => context.push('/notifications'),
        ),
        if (unread > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: AppColors.primaryYellow,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDarkHeader ? AppColors.primaryBlue : Colors.white,
                  width: 1.5,
                ),
              ),
              child: Text(
                unread > 9 ? '9+' : '$unread',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF2E2005),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          )
        else
          Positioned(
            right: 12,
            top: 10,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.primaryYellow,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDarkHeader ? AppColors.primaryBlue : Colors.white,
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY SECTION FALLBACK
// ─────────────────────────────────────────────────────────────────────────────

class _EmptySectionCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptySectionCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight.withOpacity(0.6)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: AppColors.textLight.withOpacity(0.6)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMedium,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STRING FORMATTERS
// ─────────────────────────────────────────────────────────────────────────────

String _formatDateShort(String iso) {
  try {
    final dt = DateTime.parse(iso);
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  } catch (_) {
    return '';
  }
}

String _stripHtmlIfNeeded(String text) {
  final exp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
  return text.replaceAll(exp, '').replaceAll('**', '').trim();
}

String _cleanDescription(String? text) {
  if (text == null || text.trim().isEmpty) return '';
  final noHtml = _stripHtmlIfNeeded(text)
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return noHtml;
}

String _formatXpNumber(int points) {
  if (points <= 0) return '0';
  return points.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
}
