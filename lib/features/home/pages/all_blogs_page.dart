import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/skeletons.dart';
import '../data/home_repository.dart';
import '../models/blog_model.dart';

final blogsListProvider =
    FutureProvider.autoDispose.family<List<BlogPost>, String>((ref, query) {
  return ref.watch(homeRepositoryProvider).fetchBlogs(
        limit: 30,
        search: query.isEmpty ? null : query,
      );
});

class AllBlogsPage extends ConsumerStatefulWidget {
  const AllBlogsPage({super.key});

  @override
  ConsumerState<AllBlogsPage> createState() => _AllBlogsPageState();
}

class _AllBlogsPageState extends ConsumerState<AllBlogsPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blogsAsync = ref.watch(blogsListProvider(_query));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Stories & Updates',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(blogsListProvider(_query));
          await ref.read(blogsListProvider(_query).future);
        },
        color: AppColors.primaryBlue,
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _query = val.trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search stories...',
                    hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMedium, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textMedium),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _query = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),

            // Blog List
            Expanded(
              child: blogsAsync.when(
                data: (blogs) {
                  if (blogs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.article_outlined, size: 56, color: AppColors.textLight.withAlpha(128)),
                          const SizedBox(height: 12),
                          const Text(
                            'No stories found',
                            style: TextStyle(
                              color: AppColors.textMedium,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Try adjusting your search query',
                            style: TextStyle(color: AppColors.textLight, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: blogs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (_, i) => _BlogListItem(blog: blogs[i])
                        .animate()
                        .fadeIn(delay: (60 * i).ms, duration: 350.ms)
                        .slideY(begin: 0.08, end: 0, delay: (60 * i).ms, curve: Curves.easeOut),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SkeletonCardList(count: 5, height: 110),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.errorRed),
                      const SizedBox(height: 12),
                      const Text(
                        'Unable to load stories',
                        style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(blogsListProvider(_query)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Try Again'),
                      ),
                    ],
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

class _BlogListItem extends StatelessWidget {
  final BlogPost blog;
  const _BlogListItem({required this.blog});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/home/blog/${blog.slug}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight.withAlpha(180)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                if (blog.thumbnailUrl != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
                    child: CachedNetworkImage(
                      imageUrl: blog.thumbnailUrl!,
                      width: 105,
                      height: 105,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: AppColors.borderLight),
                      errorWidget: (_, _, _) => Container(
                        width: 105,
                        height: 105,
                        color: AppColors.primaryBlue.withAlpha(20),
                        child: const Icon(Icons.article_rounded, color: AppColors.slateBlue),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 105,
                    height: 105,
                    decoration: const BoxDecoration(
                      color: Color(0xFFECF0FF),
                      borderRadius: BorderRadius.horizontal(left: Radius.circular(15)),
                    ),
                    child: const Icon(Icons.article_rounded, color: AppColors.primaryBlue, size: 32),
                  ),
                if (blog.mediaUrls.length > 1)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(160),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo_library_rounded, size: 10, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            '${blog.mediaUrls.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      blog.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textDark,
                        height: 1.25,
                      ),
                    ),
                    if (blog.excerpt != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        _stripHtml(blog.excerpt!),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textMedium, height: 1.3),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 12, color: AppColors.textLight),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            blog.author ?? 'BlueDot',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                          ),
                        ),
                        if (blog.publishedAt != null)
                          Text(
                            _formatDate(blog.publishedAt!),
                            style: const TextStyle(fontSize: 11, color: AppColors.textLight),
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

  String _stripHtml(String text) {
    return text.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('**', '').trim();
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return '';
    }
  }
}
