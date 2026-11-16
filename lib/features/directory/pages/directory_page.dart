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

  void _onSelectLocation(String loc) {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    ref.read(locationFilterProvider.notifier).update(loc);
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
    final activeLocation = ref.watch(locationFilterProvider);
    final list = speciesAsync.value;
    final isInitialLoading = speciesAsync.isLoading && list == null;
    final isSearchingBackground = speciesAsync.isLoading && list != null;

    final indianList = list?.where((s) => s.isIndian).toList() ?? [];
    final othersList = list?.where((s) => !s.isIndian).toList() ?? [];

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
                  preferredSize: const Size.fromHeight(114),
                  child: Column(
                    children: [
                      // 1. Search Bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Search 1,000+ plants (e.g. Neem, Peepal, Rose...)',
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
                            contentPadding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                        ),
                      ),

                      // 2. Location Area Filter Tabs (Default: Indian)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _LocationFilterChip(
                                label: 'Indian Species (A–Z)',
                                isSelected: activeLocation == 'Indian',
                                emoji: '🇮🇳',
                                isDefaultBadge: true,
                                onTap: () => _onSelectLocation('Indian'),
                              ),
                              const SizedBox(width: 8),
                              _LocationFilterChip(
                                label: 'All Together (Indian First)',
                                isSelected: activeLocation == 'All',
                                icon: Icons.forest_rounded,
                                onTap: () => _onSelectLocation('All'),
                              ),
                              const SizedBox(width: 8),
                              _LocationFilterChip(
                                label: 'Other Species (A–Z)',
                                isSelected: activeLocation == 'Others',
                                emoji: '🌍',
                                onTap: () => _onSelectLocation('Others'),
                              ),
                            ],
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                            : 'No species found in this section',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textMedium),
                      ),
                    ],
                  ),
                )
              else ...[
                // ── Part 1: Indian Native Plants & Trees (Alphabetical A-Z) ──────
                if (indianList.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _SectionHeader(
                      emoji: '🇮🇳',
                      title: activeLocation == 'All'
                          ? 'Indian Native Species (Part 1)'
                          : 'Indian Native Plants & Trees',
                      subtitle: 'Native to the Indian subcontinent & Himalayas (A–Z)',
                      badgeCount: indianList.length,
                      badgeColor: AppColors.forestGreen,
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.78,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _SpeciesCard(
                          species: indianList[i],
                          animateEntrance: i < 8,
                          index: i,
                        ),
                        childCount: indianList.length,
                        addAutomaticKeepAlives: true,
                        addRepaintBoundaries: true,
                      ),
                    ),
                  ),
                ],

                // ── Part 2: Other Worldwide Plants & Trees (Alphabetical A-Z) ────
                if (othersList.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _SectionHeader(
                      emoji: '🌍',
                      title: activeLocation == 'All'
                          ? 'Other Global Species (Part 2)'
                          : 'Other Global Plants & Trees',
                      subtitle: 'Worldwide, tropical & exotic varieties (A–Z)',
                      badgeCount: othersList.length,
                      badgeColor: AppColors.slateBlue,
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.78,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _SpeciesCard(
                          species: othersList[i],
                          animateEntrance: indianList.isEmpty && i < 8,
                          index: i,
                        ),
                        childCount: othersList.length,
                        addAutomaticKeepAlives: true,
                        addRepaintBoundaries: true,
                      ),
                    ),
                  ),
                ],
              ],

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

// ── Location Filter Chip Widget ─────────────────────────────────────────────

class _LocationFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final IconData? icon;
  final String? emoji;
  final bool isDefaultBadge;
  final VoidCallback onTap;

  const _LocationFilterChip({
    required this.label,
    required this.isSelected,
    this.icon,
    this.emoji,
    this.isDefaultBadge = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : AppColors.borderLight,
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryBlue.withAlpha(45),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
            ] else if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.white : AppColors.textMedium,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section Header Widget ───────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final int badgeCount;
  final Color badgeColor;

  const _SectionHeader({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.badgeCount,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: badgeColor.withAlpha(80), width: 0.8),
                ),
                child: Text(
                  '$badgeCount species',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMedium,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Species Card Widget ─────────────────────────────────────────────────────

class _SpeciesCard extends StatelessWidget {
  final TreeSpecies species;
  final bool animateEntrance;
  final int index;

  const _SpeciesCard({
    required this.species,
    this.animateEntrance = false,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final card = GestureDetector(
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
            // Image with Indian Native Badge
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
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
                  if (species.isIndian)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.forestGreen,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(40),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🇮🇳', style: TextStyle(fontSize: 9)),
                            SizedBox(width: 3),
                            Text(
                              'Native',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
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

    if (animateEntrance) {
      return card
          .animate()
          .fadeIn(duration: 200.ms, delay: (20 * index).ms)
          .scaleXY(begin: 0.98, end: 1.0, duration: 200.ms, delay: (20 * index).ms);
    }
    return card;
  }
}

class _PlaceholderImage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.primaryBlue.withAlpha(15),
        child: const Center(child: Icon(Icons.eco_rounded, color: AppColors.primaryBlue, size: 40)),
      );
}
