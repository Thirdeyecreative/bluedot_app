import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPolicyConsent();
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
      backgroundColor: const Color(0xFFF9F7F2), // Refined warm organic background
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homeFeedProvider);
          ref.invalidate(blogsProvider);
          await Future.wait([
            ref.read(homeFeedProvider.future),
            ref.read(blogsProvider.future),
          ]);
        },
        color: AppColors.forestGreen,
        backgroundColor: Colors.white,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // ── 1. Modern Header & App Bar ─────────────────────────────────
            SliverAppBar(
              pinned: false,
              floating: true,
              snap: true,
              expandedHeight: 74,
              collapsedHeight: 74,
              backgroundColor: Colors.transparent,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              flexibleSpace: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryBlue,
                        Color(0xFF28367F),
                      ],
                    ),
                  ),
                ),
              ),
              titleSpacing: 16,
              title: Row(
                children: [
                  // Profile Avatar
                  GestureDetector(
                    onTap: () => context.go('/profile'),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryYellow,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: user?.avatarUrl != null
                            ? CachedNetworkImage(
                                imageUrl: user!.avatarUrl!,
                                width: 42,
                                height: 42,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: AppColors.primaryBlue,
                                  child: const Center(
                                    child: SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: AppColors.primaryBlue,
                                  child: const Icon(Icons.person, color: Colors.white, size: 24),
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
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Personalized Greeting
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${_getTimeGreeting()},',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              '🌱',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.fullName ?? 'Eco Warrior',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const _NotificationBell(),
                ],
              ),
            ),

            // ── 2. Green Lens Scanner (Dedicated Clean Action) ─────────────
            SliverToBoxAdapter(
              child: homeFeedAsync.maybeWhen(
                data: (feed) => _GreenLensCard(tagline: feed.tagline),
                orElse: () => const _GreenLensCard(),
              )
                  .animate()
                  .fadeIn(duration: 350.ms)
                  .slideY(begin: 0.04, end: 0, curve: Curves.easeOut),
            ),

            // ── 3. Quick Action Hub (4-Pillar Grid) ─────────────────────────
            SliverToBoxAdapter(
              child: const _HomeQuickActions()
                  .animate()
                  .fadeIn(delay: 100.ms, duration: 400.ms)
                  .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
            ),

            // ── 4. Promo Banners Carousel (Graceful Adaptive Layout) ──────
            if (homeFeedAsync.maybeWhen(
              data: (feed) => feed.banners.isNotEmpty,
              orElse: () => false,
            ))
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: PromoBannerCarousel(
                    banners: homeFeedAsync.asData!.value.banners,
                  )
                      .animate()
                      .fadeIn(duration: 350.ms)
                      .slideY(begin: 0.04, end: 0, curve: Curves.easeOut),
                ),
              ),

            // ── 5. Upcoming Events Section ─────────────────────────────────
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
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: feed.events.length,
                          itemBuilder: (_, i) => _HomeEventCard(event: feed.events[i]),
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 350.ms)
                          .slideX(begin: 0.04, end: 0, curve: Curves.easeOutCubic),
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
                        message: 'No active fundraising campaigns at the moment.',
                      )
                    : SizedBox(
                        height: 242,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: feed.campaigns.length,
                          itemBuilder: (_, i) => _HomeCampaignCard(campaign: feed.campaigns[i]),
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 350.ms)
                          .slideX(begin: 0.04, end: 0, curve: Curves.easeOutCubic),
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
// GREEN LENS SCANNER (CLEAN, FUNCTIONAL ACTION CARD)
// ─────────────────────────────────────────────────────────────────────────────

class _GreenLensCard extends StatelessWidget {
  final String? tagline;
  const _GreenLensCard({this.tagline});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => context.push('/scanner'),
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.forestGreen.withOpacity(0.08),
          highlightColor: AppColors.forestGreen.withOpacity(0.04),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Real Brand Asset / Circular Lens Button
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.forestGreen,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.forestGreen.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(9),
                  child: Image.asset(
                    AppAssets.greenLensButton,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Text info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Green Lens Scanner',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tagline?.isNotEmpty == true
                            ? tagline!
                            : 'Scan tree QR tags or photograph leaves & bark',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMedium,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Clean Action Trigger
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.forestGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.camera_alt_outlined, size: 14, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'Scan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
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

// ─────────────────────────────────────────────────────────────────────────────
// QUICK ACTION TILES (4-PILLAR SHORTCUTS)
// ─────────────────────────────────────────────────────────────────────────────

class _HomeQuickActions extends StatelessWidget {
  const _HomeQuickActions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _QuickActionTile(
            icon: Icons.map_rounded,
            label: 'Eco Garden',
            subLabel: 'Live Map',
            color: AppColors.forestGreen,
            onTap: () => context.push('/map'),
          ),
          _QuickActionTile(
            icon: Icons.leaderboard_rounded,
            label: 'Rankings',
            subLabel: 'Top Warriors',
            color: AppColors.primaryBlue,
            onTap: () => context.push('/profile/leaderboard'),
          ),
          _QuickActionTile(
            icon: Icons.add_location_alt_rounded,
            label: 'Suggest Site',
            subLabel: 'New Land',
            color: AppColors.terracotta,
            onTap: () => context.push('/action-hub/suggest-site'),
          ),
          _QuickActionTile(
            icon: Icons.park_rounded,
            label: 'Directory',
            subLabel: 'Species',
            color: AppColors.sageGreen,
            onTap: () => context.go('/directory'),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subLabel;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.subLabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            splashColor: color.withOpacity(0.12),
            highlightColor: color.withOpacity(0.06),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight.withOpacity(0.7)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.025),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                      fontSize: 12,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textLight,
                      fontSize: 9.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                      child: const Icon(Icons.park, color: AppColors.forestGreen, size: 36),
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
                      child: Icon(Icons.park, color: AppColors.forestGreen, size: 36),
                    ),
                  ),

                // Date Chip (Top-Left)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: event.isPlantationDrive
                          ? AppColors.forestGreen
                          : AppColors.primaryBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      event.isPlantationDrive ? 'Drive' : (event.eventStatus ?? 'Upcoming'),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                      child: const Icon(Icons.campaign, color: AppColors.primaryBlue, size: 36),
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
                      child: Icon(Icons.campaign, color: AppColors.primaryBlue, size: 36),
                    ),
                  ),

                // Goal Pill (Top-Right)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(17)),
                    child: CachedNetworkImage(
                      imageUrl: blog.thumbnailUrl!,
                      width: 104,
                      height: 104,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: AppColors.borderLight),
                      errorWidget: (_, _, _) => Container(
                        width: 104,
                        height: 104,
                        color: AppColors.primaryBlue.withOpacity(0.1),
                        child: const Icon(Icons.article_rounded, color: AppColors.primaryBlue),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 104,
                    height: 104,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEDF1F7),
                      borderRadius: BorderRadius.horizontal(left: Radius.circular(17)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo_library_rounded, size: 9, color: Colors.white),
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
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(
            Icons.notifications_outlined,
            color: Colors.white,
            size: 24,
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
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              decoration: BoxDecoration(
                color: AppColors.terracotta,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                unread > 9 ? '9+' : '$unread',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
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

  const _EmptySectionCard({
    required this.icon,
    required this.message,
  });

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
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]}';
  } catch (_) {
    return '';
  }
}

String _stripHtmlIfNeeded(String text) {
  final exp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
  return text.replaceAll(exp, '').replaceAll('**', '').trim();
}
