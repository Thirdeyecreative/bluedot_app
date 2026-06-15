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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final species = ref.watch(speciesListProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            title: Text('Botanical Directory', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: TextField(
                  controller: _searchController,
                  onChanged: (q) => ref.read(searchQueryProvider.notifier).update(q),
                  decoration: InputDecoration(
                    hintText: 'Search plants, e.g. Neem, Banyan...',
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
            ),
          ),
          species.when(
            data: (list) => list.isEmpty
                ? SliverFillRemaining(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off_rounded, size: 56, color: AppColors.sageGreen),
                        const SizedBox(height: 16),
                        const Text('No species found', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textMedium)),
                      ],
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    sliver: SliverGrid(
                      // Extent-based so tablets get more columns instead of
                      // oversized cards.
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.78,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _SpeciesCard(species: list[i])
                            .animate()
                            .fadeIn(delay: (50 * i).ms)
                            .scaleXY(begin: 0.95, end: 1, delay: (50 * i).ms),
                        childCount: list.length,
                      ),
                    ),
                  ),
            loading: () => const SliverFillRemaining(
              child: SkeletonGrid(count: 8, childAspectRatio: 0.78),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('Error: $e')),
            ),
          ),
        ],
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
            // Image
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: species.thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: species.thumbnailUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(color: AppColors.borderLight),
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
                        Text(
                          '${species.co2OffsetFactor.toStringAsFixed(1)} kg CO₂/yr',
                          style: const TextStyle(fontSize: 10, color: AppColors.forestGreen, fontWeight: FontWeight.w500),
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
