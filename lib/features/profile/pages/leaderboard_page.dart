import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/skeletons.dart';
import '../../auth/providers/auth_provider.dart';

import '../providers/leaderboard_provider.dart';

class LeaderboardPage extends ConsumerStatefulWidget {
  const LeaderboardPage({super.key});

  @override
  ConsumerState<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends ConsumerState<LeaderboardPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    // Preload next page 400px before reaching the end of the scroll
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 400) {
      ref.read(leaderboardProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leaderboardState = ref.watch(leaderboardProvider);
    final isFetchingMore = ref.watch(isFetchingMoreLeaderboardProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: leaderboardState.when(
        loading: () => AppSkeleton(
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [Bone(width: 150, height: 24)],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Bone(
                            width: 76,
                            height: 120,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                          ),
                          const SizedBox(width: 12),
                          Bone(
                            width: 90,
                            height: 160,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                          ),
                          const SizedBox(width: 12),
                          Bone(
                            width: 76,
                            height: 100,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(
                    color: AppColors.backgroundCream,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
                    itemCount: 6,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Bone(
                        width: double.infinity,
                        height: 70,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Failed to load leaderboard\n$err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => ref.read(leaderboardProvider.notifier).refresh(),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
        data: (leaderboardData) {
          // Identify current user entry (either flagged from API or local fallback)
          final userEntry = leaderboardData.firstWhere(
            (e) => e['is_current_user'] == true,
            orElse: () => {
              'rank': 0,
              'name': currentUser?.fullName ?? 'You',
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
                  orElse: () => null,
                )
              : null;
          final userPoints = (userEntry['points'] as num?)?.toInt() ?? 0;
          final abovePoints = (aboveUser?['points'] as num?)?.toInt() ?? 0;
          final pointsNeeded = aboveUser != null ? (abovePoints - userPoints) : 0;

          // Podium: Top 3 ranked users
          final podiumEntries = leaderboardData
              .where((e) => ((e['rank'] as num?)?.toInt() ?? 0) <= 3)
              .take(3)
              .toList();

          // Scrollable list: ONLY other users (rank > 3 and not the current user)
          final otherUsers = leaderboardData.where((e) {
            final r = (e['rank'] as num?)?.toInt() ?? 0;
            final isMe = e['is_current_user'] == true;
            return r > 3 && !isMe;
          }).toList();

          return Column(
            children: [
              // ── Blue header with top 3 podium ───────────────────────────
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
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Top 3 Podium ────────────────────────────────────
                      _Podium(entries: podiumEntries),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // ── Cream Container (Docked user pill + Other users scroll list) ──
              Expanded(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(
                    color: AppColors.backgroundCream,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Stack(
                    children: [
                      // Scrollable list of ONLY other users
                      Positioned.fill(
                        child: _LeaderList(
                          entries: otherUsers,
                          scrollController: _scrollController,
                          isFetchingMore: isFetchingMore,
                          bottomPadding: 110 + MediaQuery.of(context).padding.bottom,
                          onRefresh: () => ref.read(leaderboardProvider.notifier).refresh(),
                        ),
                      ),

                      // Pinned current user pill (stays docked inside the cream area)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _PinnedUserPill(
                          entry: userEntry,
                          pointsNeeded: pointsNeeded,
                          aboveName: aboveUser?['name'] as String?,
                        ),
                      ),
                    ],
                  ),
                ),
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
    if (entries.isEmpty) return const SizedBox(height: 140);

    final first = entries.firstWhere(
      (e) => (e['rank'] as num?)?.toInt() == 1,
      orElse: () => entries[0],
    );
    final second = entries.length > 1
        ? entries.firstWhere(
            (e) => (e['rank'] as num?)?.toInt() == 2,
            orElse: () => entries[1],
          )
        : null;
    final third = entries.length > 2
        ? entries.firstWhere(
            (e) => (e['rank'] as num?)?.toInt() == 3,
            orElse: () => entries[2],
          )
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 2nd place (left, medium height)
        if (second != null)
          _PodiumSlot(
            entry: second,
            height: 90,
            medalColor: const Color(0xFFB0B7C3),
            rank: 2,
            isCurrentUser: second['is_current_user'] == true,
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.25, end: 0, delay: 200.ms)
        else
          const SizedBox(width: 76),

        const SizedBox(width: 12),

        // 1st place (center, tallest)
        _PodiumSlot(
          entry: first,
          height: 120,
          medalColor: AppColors.primaryYellow,
          rank: 1,
          isCurrentUser: first['is_current_user'] == true,
        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.25, end: 0, delay: 100.ms),

        const SizedBox(width: 12),

        // 3rd place (right, shortest)
        if (third != null)
          _PodiumSlot(
            entry: third,
            height: 72,
            medalColor: const Color(0xFFCD7F32),
            rank: 3,
            isCurrentUser: third['is_current_user'] == true,
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.25, end: 0, delay: 300.ms)
        else
          const SizedBox(width: 76),
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

  const _PodiumSlot({
    required this.entry,
    required this.height,
    required this.medalColor,
    required this.rank,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final fullName = entry['name'] as String? ?? 'Anonymous';
    final name = fullName.split(' ').first;

    return Column(
      children: [
        // Avatar with medal outline
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: rank == 1 ? 68 : 56,
              height: rank == 1 ? 68 : 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [medalColor, medalColor.withAlpha(180)],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCurrentUser ? AppColors.primaryYellow : Colors.white,
                  width: isCurrentUser ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: medalColor.withAlpha(100),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: rank == 1 ? 26 : 20,
                  ),
                ),
              ),
            ),
            if (rank == 1)
              const Positioned(
                top: -8,
                right: -4,
                child: Text('👑', style: TextStyle(fontSize: 18)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: rank == 1 ? 90 : 76,
          child: Text(
            isCurrentUser ? '$name (You)' : name,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: isCurrentUser ? FontWeight.w800 : FontWeight.w600,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '${entry['points'] ?? 0} XP',
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

// ── Scrollable list of OTHER users (High Performance, 60/120 FPS) ─────────────

class _LeaderList extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  final ScrollController scrollController;
  final bool isFetchingMore;
  final double bottomPadding;
  final Future<void> Function() onRefresh;

  const _LeaderList({
    required this.entries,
    required this.scrollController,
    required this.isFetchingMore,
    required this.bottomPadding,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty && !isFetchingMore) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.emoji_events_outlined,
                size: 48,
                color: AppColors.textMedium.withAlpha(150),
              ),
              const SizedBox(height: 12),
              const Text(
                'Not enough other Rangers yet.\nShare BlueDot to grow your community!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textMedium,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryBlue,
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
        itemCount: entries.length + (isFetchingMore ? 1 : 0),
        itemBuilder: (context, i) {
          // Bottom loading indicator when fetching next page
          if (i == entries.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                  ),
                ),
              ),
            );
          }

          final e = entries[i];
          final rank = (e['rank'] as num?)?.toInt() ?? (i + 4);

          // Fast direct rendering without per-item animation controllers
          return _LeaderRow(
            key: ValueKey('leader_rank_$rank'),
            entry: e,
          );
        },
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  final Map<String, dynamic> entry;

  const _LeaderRow({
    super.key,
    required this.entry,
  });

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
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#$rank',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textMedium,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.slateBlue.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AppColors.slateBlue,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  level,
                  style: const TextStyle(
                    color: AppColors.textMedium,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$points XP',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.eco_rounded, size: 12, color: AppColors.forestGreen),
                  const SizedBox(width: 3),
                  Text(
                    '$trees trees',
                    style: const TextStyle(
                      color: AppColors.textMedium,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Pinned Current User Pill (Docked inside the Cream Container) ──────────────

class _PinnedUserPill extends StatelessWidget {
  final Map<String, dynamic> entry;
  final int pointsNeeded;
  final String? aboveName;

  const _PinnedUserPill({
    required this.entry,
    required this.pointsNeeded,
    this.aboveName,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final rank = (entry['rank'] as num?)?.toInt() ?? 0;
    final name = entry['name'] as String? ?? 'You';
    final points = (entry['points'] as num?)?.toInt() ?? 0;
    final trees = (entry['trees'] as num?)?.toInt() ?? 0;
    final level = entry['level'] as String? ?? 'Seedling';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundCream,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(14),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        bottomInset > 0 ? bottomInset + 8 : 16,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryBlue, Color(0xFF283584)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withAlpha(50),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(35),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withAlpha(80),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  rank > 0 ? '#$rank' : '-',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '$name (You)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryYellow.withAlpha(45),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.primaryYellow.withAlpha(140),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          level,
                          style: const TextStyle(
                            color: AppColors.primaryYellow,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (aboveName != null && pointsNeeded > 0)
                    Text(
                      'Earn $pointsNeeded more XP to pass $aboveName',
                      style: TextStyle(
                        color: Colors.white.withAlpha(200),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else if (rank == 0)
                    Text(
                      'Tag trees to climb the leaderboard!',
                      style: TextStyle(
                        color: Colors.white.withAlpha(200),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  else
                    Text(
                      '$trees trees tagged',
                      style: TextStyle(
                        color: Colors.white.withAlpha(200),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$points XP',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      color: AppColors.primaryYellow,
                      size: 16,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '$trees trees',
                      style: TextStyle(
                        color: Colors.white.withAlpha(190),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
