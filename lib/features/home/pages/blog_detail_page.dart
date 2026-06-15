import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/skeletons.dart';
import '../providers/home_provider.dart';

class BlogDetailPage extends ConsumerWidget {
  final String slug;
  const BlogDetailPage({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blog = ref.watch(blogDetailProvider(slug));

    return Scaffold(
      body: blog.when(
        data: (post) => CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 260,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: post.thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: post.thumbnailUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(color: AppColors.borderLight),
                        errorWidget: (_, _, _) => Container(color: AppColors.primaryBlue.withAlpha(30)),
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primaryBlue, Color(0xFF2D3A8C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (post.linkedCampaignName != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          post.linkedCampaignName!,
                          style: const TextStyle(color: AppColors.primaryBlue, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    Text(
                      post.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.2),
                    ).animate().fadeIn().slideY(begin: 0.1, end: 0),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.textLight),
                        const SizedBox(width: 6),
                        Text(
                          post.author ?? 'BlueDot Team',
                          style: const TextStyle(color: AppColors.textMedium, fontSize: 13),
                        ),
                        const Spacer(),
                        if (post.publishedAt != null)
                          Text(
                            _formatDate(post.publishedAt!),
                            style: const TextStyle(color: AppColors.textLight, fontSize: 12),
                          ),
                      ],
                    ),
                    const Divider(height: 32),
                    if (post.bodyText != null)
                      Text(
                        post.bodyText!.replaceAll(RegExp(r'<[^>]*>'), ''), // strip HTML tags
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7, color: AppColors.textDark),
                      ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 130), // clears the floating nav bar
                  ],
                ),
              ),
            ),
          ],
        ),
        loading: () => const SkeletonDetailPage(heroHeight: 260),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.errorRed),
              const SizedBox(height: 16),
              Text(e.toString()),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}
