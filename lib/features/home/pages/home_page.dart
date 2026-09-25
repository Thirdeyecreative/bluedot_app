import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/skeletons.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/blog_model.dart';
import '../providers/home_provider.dart';
import '../widgets/promo_banner_carousel.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final blogs = ref.watch(blogsProvider);
    final banners = ref.watch(bannersProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          // 1. Compact App Bar Header
          SliverAppBar(
            pinned: false,
            floating: true,
            snap: true,
            expandedHeight: 70,
            collapsedHeight: 70,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            flexibleSpace: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.primaryBlue,
                ),
              ),
            ),
            title: Row(
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
                const SizedBox(width: 8),
                const _NotificationBell(),
              ],
            ),
          ),

          // 2. Promo Banners
          SliverToBoxAdapter(
            child: banners.when(
              data: (list) => list.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: PromoBannerCarousel(banners: list)
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
                    ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ),

          // 3. Quick Actions
          const SliverToBoxAdapter(
            child: _HomeQuickActions(),
          ),

          // 4. Stories & Updates Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Stories & Updates', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  TextButton(onPressed: () {}, child: const Text('See all')),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
          ),

          // 5. Blog Grid
          SliverToBoxAdapter(
            child: blogs.when(
              data: (list) => Padding(
                padding: const EdgeInsets.only(bottom: 120), // Padding for bottom nav & FAB
                child: _BlogGrid(blogs: list),
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
          ),
        ],
      ),
    );
  }
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

class _HomeQuickActions extends StatelessWidget {
  const _HomeQuickActions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _QuickActionButton(
            icon: Icons.map_rounded,
            label: 'Eco Garden',
            color: AppColors.forestGreen,
            onTap: () => context.push('/map'),
          ),
          _QuickActionButton(
            icon: Icons.leaderboard_rounded,
            label: 'Leaderboard',
            color: AppColors.primaryBlue,
            onTap: () => context.push('/profile/leaderboard'),
          ),
          _QuickActionButton(
            icon: Icons.add_location_alt_rounded,
            label: 'Suggest Site',
            color: AppColors.terracotta,
            onTap: () => context.push('/action-hub/suggest-site'),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 86, // Fixed width so text wraps cleanly if needed
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: color.withAlpha(30), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                  border: Border.all(color: color.withAlpha(30), width: 1.5),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark, fontSize: 13, height: 1.2),
              ),
            ],
          ),
        ),
      );
}

class _BlogGrid extends StatelessWidget {
  final List<BlogPost> blogs;
  const _BlogGrid({required this.blogs});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: blogs.length.clamp(0, 6),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _BlogCard(blog: blogs[i])
          .animate()
          .fadeIn(delay: (100 * i).ms, duration: 400.ms)
          .slideY(begin: 0.1, end: 0, delay: (100 * i).ms, curve: Curves.easeOut),
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
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4)),
          ],
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
                        _stripHtmlIfNeeded(blog.excerpt!),
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

String _stripHtmlIfNeeded(String text) {
  final exp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
  return text.replaceAll(exp, '').replaceAll('**', '').trim();
}

