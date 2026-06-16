import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/skeletons.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../scanner/providers/scanner_provider.dart';
import '../models/badge_model.dart';
import '../providers/profile_provider.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final badges = ref.watch(badgesProvider);
    final history = ref.watch(scanHistoryProvider);

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off_rounded, size: 56, color: AppColors.textLight),
              const SizedBox(height: 16),
              const Text('Not logged in'),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () => context.go('/login'), child: const Text('Login')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('My Profile'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit Profile',
                onPressed: () => context.push('/profile/edit'),
              ),
              IconButton(
                icon: const Icon(Icons.map_rounded),
                tooltip: 'My Eco Garden',
                onPressed: () => context.push('/map'),
              ),
              IconButton(
                icon: const Icon(Icons.settings_rounded),
                tooltip: 'Settings',
                onPressed: () => context.push('/profile/settings'),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _ProfileHeader(user: user),
                _ImpactStats(user: user),
                _QuickActions(),
                _BadgesSection(badges: badges, onSeeAll: () => context.push('/profile/badges')),
                _ScansHistory(history: history),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final AppUser user;
  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryBlue, Color(0xFF2D3A8C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withAlpha(70),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar with level progress ring
          CircularPercentIndicator(
            radius: 50,
            lineWidth: 5,
            percent: user.levelProgress.clamp(0.0, 1.0),
            progressColor: AppColors.primaryYellow,
            backgroundColor: Colors.white.withAlpha(40),
            circularStrokeCap: CircularStrokeCap.round,
            center: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withAlpha(50), width: 2),
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 40),
            ),
          ).animate().fadeIn().scaleXY(begin: 0.8, end: 1, curve: Curves.elasticOut),
          const SizedBox(height: 14),
          Text(
            user.fullName ?? user.phone,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryYellow.withAlpha(40),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primaryYellow.withAlpha(100)),
            ),
            child: Text(
              '${user.levelTitle}  ·  Level ${user.level}',
              style: const TextStyle(color: AppColors.primaryYellow, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${user.pointsInCurrentLevel} / ${user.pointsForNextLevel} XP to Level ${user.level + 1}',
            style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ImpactStats extends StatelessWidget {
  final AppUser user;
  const _ImpactStats({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My Impact', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ImpactTile(icon: Icons.bolt_rounded, label: 'Total XP', value: '${user.totalPoints}', color: AppColors.primaryYellow),
              _ImpactTile(icon: Icons.park_rounded, label: 'Trees Tagged', value: '${user.treesTagged}', color: AppColors.forestGreen),
              _ImpactTile(icon: Icons.favorite_rounded, label: 'Donated', value: '₹${(user.totalDonated / 1000).toStringAsFixed(1)}k', color: AppColors.terracotta),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.leaderboard_rounded,
                label: 'Leaderboard',
                sublabel: 'See your rank',
                color: AppColors.primaryBlue,
                onTap: () => context.push('/profile/leaderboard'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.workspace_premium_rounded,
                label: 'Certificates',
                sublabel: 'Your contributions',
                color: AppColors.terracotta,
                onTap: () => context.push('/profile/certificates'),
              ),
            ),
          ],
        ),
      );
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionCard({required this.icon, required this.label, required this.sublabel, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color.withAlpha(15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withAlpha(50)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13)),
                  Text(sublabel, style: const TextStyle(color: AppColors.textMedium, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      );
}

class _ImpactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _ImpactTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withAlpha(20), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 16)),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMedium)),
        ],
      );
}

class _BadgesSection extends StatelessWidget {
  final AsyncValue<List<Badge>> badges;
  final VoidCallback onSeeAll;
  const _BadgesSection({required this.badges, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Badges', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              TextButton(onPressed: onSeeAll, child: const Text('See all')),
            ],
          ),
        ),
        badges.when(
          data: (list) => SizedBox(
            height: 100,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: list.take(8).length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _BadgeChip(badge: list[i]),
            ),
          ),
          loading: () => const SkeletonRowCards(count: 4, height: 100, width: 90),
          error: (_, _) => const SizedBox(),
        ),
      ],
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final Badge badge;
  const _BadgeChip({required this.badge});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: badge.unlocked ? 1.0 : 0.4,
      duration: 300.ms,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: badge.unlocked ? AppColors.primaryYellow.withAlpha(20) : AppColors.borderLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: badge.unlocked ? AppColors.primaryYellow.withAlpha(80) : AppColors.borderLight),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(badge.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              badge.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: badge.unlocked ? AppColors.textDark : AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScansHistory extends StatelessWidget {
  final AsyncValue<dynamic> history;
  const _ScansHistory({required this.history});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text('Recent Scans', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ),
        history.when(
          data: (list) {
            final items = list as List;
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.camera_alt_outlined, size: 40, color: AppColors.textLight),
                      SizedBox(height: 8),
                      Text('No scans yet! Use the Green Lens to identify plants.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMedium)),
                    ],
                  ),
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.take(5).length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final item = items[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      if (item.imageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(item.imageUrl!, width: 52, height: 52, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(width: 52, height: 52)),
                        )
                      else
                        Container(width: 52, height: 52, decoration: BoxDecoration(color: AppColors.forestGreen.withAlpha(20), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.eco_rounded, color: AppColors.forestGreen)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.plantnetSummary?['scientific_name'] as String? ?? 'Unknown species', style: const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(item.taggedAt ?? '', style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.verified_rounded, color: AppColors.forestGreen, size: 18),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const SkeletonCardList(count: 3, height: 72),
          error: (_, _) => const SizedBox(),
        ),
      ],
    );
  }
}
