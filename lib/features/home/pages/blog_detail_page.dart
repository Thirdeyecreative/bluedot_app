import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_html_view.dart';
import '../../../core/widgets/skeletons.dart';
import '../providers/home_provider.dart';

class BlogDetailPage extends ConsumerWidget {
  final String slug;
  const BlogDetailPage({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blog = ref.watch(blogDetailProvider(slug));

    return Scaffold(
      backgroundColor: Colors.white,
      body: blog.when(
        data: (post) => CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.black.withAlpha(100),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: _BlogMediaHeader(mediaUrls: post.mediaUrls),
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
                          style: const TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    Text(
                      post.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            color: AppColors.textDark,
                          ),
                    ).animate().fadeIn().slideY(begin: 0.1, end: 0),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.textLight),
                        const SizedBox(width: 6),
                        Text(
                          post.author ?? 'BlueDot Team',
                          style: const TextStyle(color: AppColors.textMedium, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        if (post.publishedAt != null) ...[
                          const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.textLight),
                          const SizedBox(width: 5),
                          Text(
                            _formatDate(post.publishedAt!),
                            style: const TextStyle(color: AppColors.textLight, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                    const Divider(height: 32),

                    // If multiple images exist, show a photo gallery strip
                    if (post.mediaUrls.length > 1) ...[
                      Row(
                        children: [
                          const Icon(Icons.photo_library_outlined, size: 16, color: AppColors.primaryBlue),
                          const SizedBox(width: 6),
                          Text(
                            'Gallery (${post.mediaUrls.length} photos)',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'Tap to preview',
                            style: TextStyle(fontSize: 11, color: AppColors.textLight),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 90,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: post.mediaUrls.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, idx) => GestureDetector(
                            onTap: () => _openPhotoViewer(context, post.mediaUrls, idx),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: post.mediaUrls[idx],
                                width: 120,
                                height: 90,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => Container(width: 120, color: AppColors.borderLight),
                                errorWidget: (_, _, _) => Container(
                                  width: 120,
                                  color: AppColors.primaryBlue.withAlpha(20),
                                  child: const Icon(Icons.broken_image_rounded, color: AppColors.slateBlue),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    if (post.bodyText != null)
                      AppHtmlView(html: post.bodyText).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 130), // clears floating nav bar
                  ],
                ),
              ),
            ),
          ],
        ),
        loading: () => const SkeletonDetailPage(heroHeight: 280),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.errorRed),
              const SizedBox(height: 16),
              Text(e.toString()),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(blogDetailProvider(slug)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPhotoViewer(BuildContext context, List<String> urls, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => _FullScreenPhotoViewer(urls: urls, initialIndex: initialIndex),
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

class _BlogMediaHeader extends StatefulWidget {
  final List<String> mediaUrls;
  const _BlogMediaHeader({required this.mediaUrls});

  @override
  State<_BlogMediaHeader> createState() => _BlogMediaHeaderState();
}

class _BlogMediaHeaderState extends State<_BlogMediaHeader> {
  final _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaUrls.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryBlue, Color(0xFF2D3A8C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Icon(Icons.article_rounded, color: Colors.white54, size: 48),
        ),
      );
    }

    if (widget.mediaUrls.length == 1) {
      return CachedNetworkImage(
        imageUrl: widget.mediaUrls.first,
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(color: AppColors.borderLight),
        errorWidget: (_, _, _) => Container(color: AppColors.primaryBlue.withAlpha(30)),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: widget.mediaUrls.length,
          onPageChanged: (i) => setState(() => _currentIndex = i),
          itemBuilder: (context, i) {
            return CachedNetworkImage(
              imageUrl: widget.mediaUrls[i],
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(color: AppColors.borderLight),
              errorWidget: (_, _, _) => Container(
                color: AppColors.primaryBlue.withAlpha(30),
                child: const Icon(Icons.broken_image_rounded, color: AppColors.slateBlue),
              ),
            );
          },
        ),

        // Bottom gradient for indicator readability
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 60,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withAlpha(130)],
              ),
            ),
          ),
        ),

        // Dots & Counter Indicator
        Positioned(
          bottom: 12,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Dots
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  widget.mediaUrls.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentIndex == i ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _currentIndex == i ? Colors.white : Colors.white.withAlpha(120),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),

              // 1 / N pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(140),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentIndex + 1}/${widget.mediaUrls.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FullScreenPhotoViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const _FullScreenPhotoViewer({required this.urls, required this.initialIndex});

  @override
  State<_FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<_FullScreenPhotoViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (ctx, i) {
              return Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: CachedNetworkImage(
                    imageUrl: widget.urls[i],
                    fit: BoxFit.contain,
                    placeholder: (_, _) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (_, _, _) => const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_index + 1} / ${widget.urls.length}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
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
