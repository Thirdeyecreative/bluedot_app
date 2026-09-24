import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

import '../providers/leaderboard_provider.dart';

class LeaderboardPage extends ConsumerWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardState = ref.watch(leaderboardProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: leaderboardState.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white))),
        data: (leaderboardData) {
          // Use the `is_current_user` flag from the API — not fragile name matching
          final userEntry = leaderboardData.firstWhere(
            (e) => e['is_current_user'] == true,
            orElse: () => {
              'rank': 0, 'name': currentUser?.fullName ?? 'You',
              'city': currentUser?.city ?? 'Unknown',
              'points': currentUser?.totalPoints ?? 0,
              'trees': currentUser?.treesTagged ?? 0,
              'level': currentUser?.levelTitle ?? 'Seedling',
              'is_current_user': true,
            },
          );
          final userRank = (userEntry['rank'] as num?)?.toInt() ?? 0;
          final aboveUser = userRank > 1
              ? leaderboardData.cast<Map<String, dynamic>?>().firstWhere(
                  (e) => (e?['rank'] as num?)?.toInt() == userRank - 1,
                  orElse: () => leaderboardData.isNotEmpty ? leaderboardData.first : null,
                )
              : null;
          final userPoints = (userEntry['points'] as num?)?.toInt() ?? 0;
          final abovePoints = (aboveUser?['points'] as num?)?.toInt() ?? 0;
          final pointsNeeded = aboveUser != null ? (abovePoints - userPoints) : 0;

          return Column(
            children: [
              // ── Blue header ─────────────────────────────────────────────
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Expanded(
                            child: Text(
                              'Leaderboard',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── Podium (top 3) ──────────────────────────────────
                      _Podium(entries: leaderboardData.take(3).toList()),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // ── Scrollable list (rank 4+) ────────────────────────────────
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.backgroundCream,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: _LeaderList(entries: leaderboardData.skip(3).toList()),
                ),
              ),

              // ── Sticky current user banner ──────────────────────────────
              _CurrentUserBanner(
                entry: userEntry,
                pointsNeeded: pointsNeeded,
                aboveName: aboveUser?['name'] as String?,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Podium ────────────────────────────────────────────────────────────────────

class _Podium extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  const _Podium({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.length < 3) return const SizedBox();
    final first = entries[0];
    final second = entries[1];
    final third = entries[2];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 2nd place (left, shorter)
        _PodiumSlot(entry: second, height: 90, medalColor: const Color(0xFFB0B7C3), rank: 2, isCurrentUser: second['is_current_user'] == true)
            .animate().fadeIn(delay: 200.ms).slideY(begin: 0.3, end: 0, delay: 200.ms),
        const SizedBox(width: 12),
        // 1st place (center, tallest)
        _PodiumSlot(entry: first, height: 120, medalColor: AppColors.primaryYellow, rank: 1, isCurrentUser: first['is_current_user'] == true)
            .animate().fadeIn(delay: 100.ms).slideY(begin: 0.3, end: 0, delay: 100.ms),
        const SizedBox(width: 12),
        // 3rd place (right, shortest)
        _PodiumSlot(entry: third, height: 72, medalColor: const Color(0xFFCD7F32), rank: 3, isCurrentUser: third['is_current_user'] == true)
            .animate().fadeIn(delay: 300.ms).slideY(begin: 0.3, end: 0, delay: 300.ms),
      ],
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  final Map<String, dynamic> entry;
  final double height;
  final Color medalColor;
  final int rank;
  final bool isCurrentUser;
  const _PodiumSlot({required this.entry, required this.height, required this.medalColor, required this.rank, required this.isCurrentUser});

  @override
  Widget build(BuildContext context) {
    final name = (entry['name'] as String).split(' ').first;
    return Column(
      children: [
        // Avatar
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: rank == 1 ? 68 : 56,
              height: rank == 1 ? 68 : 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [medalColor, medalColor.withAlpha(180)]),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [BoxShadow(color: medalColor.withAlpha(100), blurRadius: 12)],
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: rank == 1 ? 26 : 20),
                ),
              ),
            ),
            if (rank == 1)
              const Positioned(top: -8, right: -4, child: Text('👑', style: TextStyle(fontSize: 18))),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isCurrentUser ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12,
          ),
        ),
        Text(
          '${entry['points']} XP',
          style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 10),
        ),
        const SizedBox(height: 8),
        // Podium block
        Container(
          width: rank == 1 ? 90 : 76,
          height: height,
          decoration: BoxDecoration(
            color: medalColor.withAlpha(rank == 1 ? 230 : 180),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Center(
            child: Text(
              '$rank',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: rank == 1 ? 28 : 22,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Scrollable list ───────────────────────────────────────────────────────────

class _LeaderList extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  const _LeaderList({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Not enough data for your city yet.\nBe the first Ranger here!', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMedium)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final e = entries[i];
        final isMe = e['is_current_user'] == true;
        return _LeaderRow(entry: e, isCurrentUser: isMe)
            .animate()
            .fadeIn(delay: (60 * i).ms)
            .slideX(begin: 0.05, end: 0, delay: (60 * i).ms);
      },
    );
  }
}

class _LeaderRow extends StatelessWidget {
  final Map<String, dynamic> entry;
  final bool isCurrentUser;
  const _LeaderRow({required this.entry, required this.isCurrentUser});

  @override
  Widget build(BuildContext context) {
    final rank = (entry['rank'] as num?)?.toInt() ?? 0;
    final name = entry['name'] as String? ?? 'Anonymous';
    final level = entry['level'] as String? ?? '';
    final points = (entry['points'] as num?)?.toInt() ?? 0;
    final trees = (entry['trees'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isCurrentUser ? AppColors.primaryBlue.withAlpha(15) : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isCurrentUser ? AppColors.primaryBlue.withAlpha(80) : AppColors.borderLight),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#$rank',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isCurrentUser ? AppColors.primaryBlue : AppColors.textMedium,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCurrentUser ? AppColors.primaryBlue : AppColors.slateBlue.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(color: isCurrentUser ? Colors.white : AppColors.slateBlue, fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrentUser ? '$name (You)' : name,
                  style: TextStyle(fontWeight: FontWeight.w700, color: isCurrentUser ? AppColors.primaryBlue : AppColors.textDark),
                ),
                Text(level, style: const TextStyle(color: AppColors.textMedium, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$points XP', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryBlue, fontSize: 14)),
              Row(
                children: [
                  const Icon(Icons.eco_rounded, size: 11, color: AppColors.forestGreen),
                  const SizedBox(width: 3),
                  Text('$trees trees', style: const TextStyle(color: AppColors.textMedium, fontSize: 11)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sticky banner ─────────────────────────────────────────────────────────────

class _CurrentUserBanner extends StatelessWidget {
  final Map<String, dynamic> entry;
  final int pointsNeeded;
  final String? aboveName;
  const _CurrentUserBanner({required this.entry, required this.pointsNeeded, this.aboveName});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceCard,
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.primaryBlue, Color(0xFF2D3A8C)]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  '#${entry['rank']}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your rank: #${entry['rank']} · ${entry['points']} XP',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  if (aboveName != null && pointsNeeded > 0)
                    Text(
                      'Earn $pointsNeeded more XP to overtake $aboveName',
                      style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 12),
                    ),
                ],
              ),
            ),
            const Icon(Icons.bolt_rounded, color: AppColors.primaryYellow, size: 22),
          ],
        ),
      ),
    );
  }
}
