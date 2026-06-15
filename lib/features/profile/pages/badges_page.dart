import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/skeletons.dart';
import '../models/badge_model.dart';
import '../providers/profile_provider.dart';

class BadgesPage extends ConsumerWidget {
  const BadgesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(badgesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Badge Collection'),
        leading: const BackButton(),
      ),
      body: badges.when(
        data: (list) {
          final unlocked = list.where((b) => b.unlocked).toList();
          final locked = list.where((b) => !b.unlocked).toList();
          return CustomScrollView(
            slivers: [
              // Header banner
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryYellow, Color(0xFFD4A82F)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Text('🏅', style: TextStyle(fontSize: 36)),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${unlocked.length} / ${list.length} Unlocked',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                          ),
                          Text(
                            'Keep scanning to earn more!',
                            style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn().slideY(begin: 0.1, end: 0),
              ),

              if (unlocked.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Text('Unlocked', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 130,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _BadgeTile(badge: unlocked[i])
                          .animate()
                          .fadeIn(delay: (80 * i).ms)
                          .scaleXY(begin: 0.8, end: 1, delay: (80 * i).ms, curve: Curves.elasticOut),
                      childCount: unlocked.length,
                    ),
                  ),
                ),
              ],

              if (locked.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Text('Locked', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textMedium)),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 130,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Opacity(opacity: 0.4, child: _BadgeTile(badge: locked[i])),
                      childCount: locked.length,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
        loading: () => const SkeletonGrid(count: 9, crossAxisCount: 3, childAspectRatio: 0.85),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final Badge badge;
  const _BadgeTile({required this.badge});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showBadgeInfo(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: badge.unlocked ? AppColors.primaryYellow.withAlpha(20) : AppColors.borderLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: badge.unlocked ? AppColors.primaryYellow.withAlpha(120) : AppColors.borderLight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(badge.emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 6),
            Text(
              badge.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: badge.unlocked ? AppColors.textDark : AppColors.textLight,
              ),
            ),
            if (badge.unlocked) ...[
              const SizedBox(height: 4),
              Text(
                '+${badge.points} XP',
                style: const TextStyle(fontSize: 10, color: AppColors.primaryYellow, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showBadgeInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      // Root navigator so the sheet renders above the shell's floating nav bar.
      useRootNavigator: true,
      backgroundColor: AppColors.backgroundCream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
            28, 28, 28, 28 + MediaQuery.of(sheetContext).viewPadding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(badge.emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(badge.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
            if (badge.description != null) ...[
              const SizedBox(height: 8),
              Text(badge.description!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMedium)),
            ],
            const SizedBox(height: 16),
            if (badge.metric != null)
              Text(
                badge.unlocked ? 'Achieved!' : 'Reach ${badge.threshold} ${badge.metric} to unlock',
                style: TextStyle(
                  color: badge.unlocked ? AppColors.forestGreen : AppColors.textMedium,
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(height: 8),
            Text('+${badge.points} XP reward', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryYellow, fontSize: 16)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
