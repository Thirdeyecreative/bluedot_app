import 'dart:async';
import 'dart:ui' as ui;
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
import '../models/blog_model.dart';
import '../providers/home_provider.dart';
import '../widgets/promo_banner_carousel.dart';
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
                  // BlueDot Conservation Logo & Branding
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
                      )
                      .animate()
                      .fadeIn(duration: 350.ms)
                      .slideY(begin: 0.04, end: 0, curve: Curves.easeOut),
            ),

            // ── 3. Canopy Health Status Bar ────────────────────────────────
            SliverToBoxAdapter(
              child: const _CanopyHealthBar()
                  .animate()
                  .fadeIn(delay: 50.ms, duration: 350.ms)
                  .slideY(begin: 0.04, end: 0, curve: Curves.easeOut),
            ),

            // ── 4. "Protect The Canopy" Hero Card ──────────────────────────
            SliverToBoxAdapter(
              child: const _ProtectCanopyHeroCard()
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
                            height: 240,
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
                            height: 242,
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
// GREETING & ECO-INDEX ROW
// ─────────────────────────────────────────────────────────────────────────────

class _GreetingRow extends StatelessWidget {
  final String greeting;
  final String? userName;

  const _GreetingRow({required this.greeting, this.userName});

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.ecoIndexBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.ecoIndexBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.ecoIndexDot,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'ECO-INDEX 92%',
                  style: TextStyle(
                    color: AppColors.ecoIndexText,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CANOPY HEALTH STATUS BAR
// ─────────────────────────────────────────────────────────────────────────────

class _CanopyHealthBar extends StatelessWidget {
  final String status;
  final String zone;

  const _CanopyHealthBar({
    this.status = 'Optimal',
    this.zone = 'Cascadia Zone',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => context.push('/map'),
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.primaryBlue.withOpacity(0.06),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.025),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3EB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.eco_rounded,
                    color: Color(0xFF386641),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      text: 'Canopy Health: ',
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        TextSpan(
                          text: status,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2E5A36),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  zone,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMedium,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// "PROTECT THE CANOPY" HERO CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ProtectCanopyHeroCard extends StatelessWidget {
  const _ProtectCanopyHeroCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF5D7566), Color(0xFF384E40)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF384E40).withOpacity(0.28),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top pills
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'BlueDot Initiative 2025',
                    style: TextStyle(
                      color: Color(0xFF1B2B20),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryYellow,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '100,000 Acres',
                    style: TextStyle(
                      color: Color(0xFF2E2005),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            // Headline
            const Text(
              'Protect The Canopy',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            // Subtitle
            Text(
              'Preserving ancient old-growth ecosystems from fragmentation. Join our community-backed land trust.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.88),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            // Bottom row: CTA Button & Goal Badge
            Row(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.go('/action-hub?tab=0'),
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryYellow,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.14),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Learn More',
                            style: TextStyle(
                              color: Color(0xFF2E2005),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 15,
                            color: Color(0xFF2E2005),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.18),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'Goal: 68% secured',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIRECT ACTION / DAILY IMPACT (3-CARD ROW)
// ─────────────────────────────────────────────────────────────────────────────

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
                'Direct Action',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                'Daily Impact',
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
                  icon: Icons.park_rounded,
                  iconColor: const Color(0xFF386641),
                  iconBg: const Color(0xFFEAF3EB),
                  title: 'Plant a\nTree',
                  tag: 'Native',
                  tagColor: AppColors.primaryBlue,
                  onTap: () => context.go('/action-hub?tab=0'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DirectActionCard(
                  icon: Icons.travel_explore_rounded,
                  iconColor: const Color(0xFFD4931A),
                  iconBg: const Color(0xFFFEF4E2),
                  title: 'Log\nFind',
                  tag: 'Bio-census',
                  tagColor: AppColors.textMedium,
                  onTap: () => context.go('/directory'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DirectActionCard(
                  icon: Icons.volunteer_activism_rounded,
                  iconColor: AppColors.primaryBlue,
                  iconBg: const Color(0xFFEEF1FD),
                  title: 'Support\nWild',
                  tag: 'Micro-pledge',
                  tagColor: AppColors.textMedium,
                  onTap: () => context.go('/action-hub?tab=0'),
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
// INSTANT FLORA SCANNER (FIELD BIO-INTELLIGENCE)
// ─────────────────────────────────────────────────────────────────────────────

class _InstantFloraScannerCard extends StatelessWidget {
  const _InstantFloraScannerCard();

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
          splashColor: AppColors.primaryBlue.withOpacity(0.08),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Instant Flora Scanner',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'FIELD BIO-INTELLIGENCE',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ],
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
                            'AI-Powered',
                            style: TextStyle(
                              color: Color(0xFFB87814),
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
                // Viewfinder frame
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF4A5F52), Color(0xFF2C3E33)],
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Central dashed viewfinder reticle
                      CustomPaint(
                        size: const Size(100, 100),
                        painter: const _DashedRectPainter(
                          color: AppColors.primaryYellow,
                          strokeWidth: 2,
                          gap: 6,
                        ),
                      ),
                      // Bottom detected pill
                      Positioned(
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.18),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4C75E6),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Detected: Quercus Robur (Oak)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  const _DashedRectPainter({
    required this.color,
    this.strokeWidth = 2.0,
    this.gap = 6.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(16),
    );

    final Path path = Path()..addRRect(rrect);
    final Path dashPath = Path();

    for (final ui.PathMetric metric in path.computeMetrics()) {
      double distance = 0.0;
      bool draw = true;
      while (distance < metric.length) {
        final double length = draw ? gap * 1.5 : gap;
        if (draw) {
          dashPath.addPath(
            metric.extractPath(distance, distance + length),
            Offset.zero,
          );
        }
        distance += length;
        draw = !draw;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      gap != oldDelegate.gap;
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
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 5),
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
                  const SizedBox(height: 12),
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
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 10),
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
                  const SizedBox(height: 9),
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
