import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/skeletons.dart';
import '../providers/directory_provider.dart';

class SpeciesDetailPage extends ConsumerWidget {
  final String speciesId;
  const SpeciesDetailPage({super.key, required this.speciesId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final species = ref.watch(speciesDetailProvider(speciesId));

    return Scaffold(
      body: species.when(
        data: (s) => CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: s.thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: s.thumbnailUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(color: AppColors.borderLight),
                        errorWidget: (_, _, _) => _DefaultPlant(),
                      )
                    : _DefaultPlant(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + scientific
                    Text(s.localName, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700))
                        .animate().fadeIn().slideY(begin: 0.1, end: 0),
                    Text(s.scientificName, style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 16, color: AppColors.textMedium))
                        .animate().fadeIn(delay: 80.ms),

                    const SizedBox(height: 24),

                    // Stats grid
                    Row(
                      children: [
                        _SpeciesStat(icon: Icons.cloud_done_rounded, label: 'CO₂/year', value: '${s.co2OffsetFactor.toStringAsFixed(1)} kg', color: AppColors.forestGreen),
                        _SpeciesStat(icon: Icons.access_time_rounded, label: 'Growth Time', value: '${s.growthTimeYears} yrs', color: AppColors.slateBlue),
                        if (s.family != null)
                          _SpeciesStat(icon: Icons.category_rounded, label: 'Family', value: s.family!, color: AppColors.terracotta),
                      ],
                    ).animate().fadeIn(delay: 150.ms),

                    if (s.nativeRegion != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 16, color: AppColors.textMedium),
                          const SizedBox(width: 6),
                          Text('Native to ${s.nativeRegion!}', style: const TextStyle(color: AppColors.textMedium, fontSize: 14)),
                        ],
                      ),
                    ],

                    const Divider(height: 36),

                    if (s.description != null) ...[
                      Text('About', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      Text(s.description!, style: const TextStyle(color: AppColors.textMedium, height: 1.7, fontSize: 15)),
                      const SizedBox(height: 24),
                    ],

                    // CO2 impact callout
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.forestGreen.withAlpha(30), AppColors.sageGreen.withAlpha(20)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.forestGreen.withAlpha(60)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.eco_rounded, color: AppColors.forestGreen, size: 36),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Lifetime Impact', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.forestGreen)),
                                Text(
                                  'A single ${s.localName} tree absorbs ~${(s.co2OffsetFactor * s.growthTimeYears).toStringAsFixed(0)} kg of CO₂ over ${s.growthTimeYears} years.',
                                  style: const TextStyle(color: AppColors.textDark, fontSize: 13, height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 200.ms),

                    const SizedBox(height: 130), // clears the floating nav bar
                  ],
                ),
              ),
            ),
          ],
        ),
        loading: () => const SkeletonDetailPage(heroHeight: 280),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _DefaultPlant extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.forestGreen, AppColors.sageGreen], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: const Center(child: Icon(Icons.eco_rounded, color: Colors.white, size: 80)),
      );
}

class _SpeciesStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _SpeciesStat({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13)),
              Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMedium)),
            ],
          ),
        ),
      );
}
