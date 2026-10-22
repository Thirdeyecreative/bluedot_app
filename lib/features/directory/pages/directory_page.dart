import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/skeletons.dart';
import '../models/species_model.dart';
import '../providers/directory_provider.dart';

class DirectoryPage extends ConsumerStatefulWidget {
  const DirectoryPage({super.key});

  @override
  ConsumerState<DirectoryPage> createState() => _DirectoryPageState();
}

class _DirectoryPageState extends ConsumerState<DirectoryPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    // Lookahead of 600px so next page preloads seamlessly before reaching the bottom
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 600) {
      ref.read(speciesListProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    // 300ms debounce feels immediate and snappy
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        ref.read(searchQueryProvider.notifier).update(query);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speciesAsync = ref.watch(speciesListProvider);
    final isFetchingMore = ref.watch(isFetchingMoreProvider);
    final searchQuery = ref.watch(searchQueryProvider).trim();
    final list = speciesAsync.value;
    final isInitialLoading = speciesAsync.isLoading && list == null;
    final isSearchingBackground = speciesAsync.isLoading && list != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/home');
      },
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(speciesListProvider);
            await Future.delayed(const Duration(milliseconds: 400));
          },
          color: AppColors.primaryBlue,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverAppBar(
                floating: true,
                snap: true,
                leadingWidth: 64,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
                  child: GestureDetector(
                    onTap: () => context.go('/home'),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primaryYellow,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 8)],
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: AppColors.textDark, size: 20),
                    ),
                  ),
                ),
                title: Text(
                  'Botanical Directory',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(66),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Search 1,000+ plants (e.g. Pine, Oak, Rose, Ficus...)',
                            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textLight),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      ref.read(searchQueryProvider.notifier).update('');
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      if (isSearchingBackground)
                        const LinearProgressIndicator(
                          minHeight: 2,
                          backgroundColor: Colors.transparent,
                          color: AppColors.primaryBlue,
                        )
                      else
                        const SizedBox(height: 2),
                    ],
                  ),
                ),
              ),

              // Active search results info banner
              if (searchQuery.isNotEmpty && list != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${list.length} species found for "$searchQuery"',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            _searchController.clear();
                            ref.read(searchQueryProvider.notifier).update('');
                          },
                          child: const Text('Clear', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),

              // Main Species Content Grid
              if (isInitialLoading)
                const SliverFillRemaining(
                  child: SkeletonGrid(count: 8, childAspectRatio: 0.78),
                )
              else if (list == null || list.isEmpty)
                SliverFillRemaining(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off_rounded, size: 56, color: AppColors.sageGreen),
                      const SizedBox(height: 16),
                      Text(
                        searchQuery.isNotEmpty
                            ? 'No species found matching "$searchQuery"'
                            : 'No species found',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textMedium),
                      ),
                    ],
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final card = _SpeciesCard(species: list[i]);
                        // Instant, lag-free rendering: only apply subtle stagger for the first fold (first 8)
                        // All scrolled items render instantly with 0ms artificial delay
                        if (i < 8) {
                          return card
                              .animate()
                              .fadeIn(duration: 200.ms, delay: (20 * i).ms)
                              .scaleXY(begin: 0.98, end: 1.0, duration: 200.ms, delay: (20 * i).ms);
                        }
                        return card;
                      },
                      childCount: list.length,
                      addAutomaticKeepAlives: true,
                      addRepaintBoundaries: true,
                    ),
                  ),
                ),

              // Bottom Loader for infinite pagination
              if (isFetchingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 120),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primaryBlue),
                      ),
                    ),
                  ),
                )
              else
                const SliverToBoxAdapter(
                  child: SizedBox(height: 120),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeciesCard extends StatelessWidget {
  final TreeSpecies species;
  const _SpeciesCard({required this.species});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/directory/species/${species.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with optimized raster memory cache
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: species.thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: species.thumbnailUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        memCacheWidth: 350,
                        maxWidthDiskCache: 500,
                        fadeInDuration: const Duration(milliseconds: 150),
                        fadeOutDuration: const Duration(milliseconds: 80),
                        placeholder: (_, _) => Container(color: AppColors.primaryBlue.withAlpha(10)),
                        errorWidget: (_, _, _) => _PlaceholderImage(),
                      )
                    : _PlaceholderImage(),
              ),
            ),
            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      species.localName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      species.scientificName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 11, color: AppColors.textMedium),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.cloud_done_rounded, size: 12, color: AppColors.forestGreen),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${species.co2OffsetFactor.toStringAsFixed(1)} kg CO₂/yr',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10, color: AppColors.forestGreen, fontWeight: FontWeight.w500),
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

class _PlaceholderImage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.primaryBlue.withAlpha(15),
        child: const Center(child: Icon(Icons.eco_rounded, color: AppColors.primaryBlue, size: 40)),
      );
}

