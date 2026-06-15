import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/demo/demo_data.dart';
import '../../auth/providers/auth_provider.dart';

// Extended leaderboard for demo purposes
const _fullLeaderboard = [
  {'rank': 1, 'name': 'Aarav Mehta', 'city': 'Mumbai', 'points': 4280, 'trees': 63, 'level': 'Guardian'},
  {'rank': 2, 'name': 'Nisha Rao', 'city': 'Pune', 'points': 3860, 'trees': 55, 'level': 'Ranger'},
  {'rank': 3, 'name': 'Avishkar', 'city': 'Mumbai', 'points': 1320, 'trees': 18, 'level': 'Sapling'},
  {'rank': 4, 'name': 'Priya Malhotra', 'city': 'Delhi', 'points': 980, 'trees': 14, 'level': 'Sapling'},
  {'rank': 5, 'name': 'Rahul Singh', 'city': 'Bangalore', 'points': 760, 'trees': 11, 'level': 'Sapling'},
  {'rank': 6, 'name': 'Ananya Iyer', 'city': 'Chennai', 'points': 540, 'trees': 8, 'level': 'Seedling'},
  {'rank': 7, 'name': 'Dev Patel', 'city': 'Surat', 'points': 420, 'trees': 6, 'level': 'Seedling'},
  {'rank': 8, 'name': 'Kavya Reddy', 'city': 'Hyderabad', 'points': 310, 'trees': 5, 'level': 'Seedling'},
  {'rank': 9, 'name': 'Aditya Sharma', 'city': 'Jaipur', 'points': 210, 'trees': 3, 'level': 'Seedling'},
  {'rank': 10, 'name': 'Meera Das', 'city': 'Kolkata', 'points': 150, 'trees': 2, 'level': 'Seedling'},
];

class LeaderboardPage extends ConsumerStatefulWidget {
  const LeaderboardPage({super.key});

  @override
  ConsumerState<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends ConsumerState<LeaderboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final currentName = currentUser?.fullName ?? DemoData.user.fullName ?? 'You';

    // Find current user in leaderboard
    final userEntry = _fullLeaderboard.firstWhere(
      (e) => (e['name'] as String) == currentName,
      orElse: () => {'rank': 99, 'name': currentName, 'city': 'Unknown', 'points': currentUser?.totalPoints ?? 0, 'trees': currentUser?.treesTagged ?? 0, 'level': currentUser?.levelTitle ?? 'Seedling'},
    );
    final userRank = userEntry['rank'] as int;
    final aboveUser = userRank > 1
        ? _fullLeaderboard.firstWhere((e) => (e['rank'] as int) == userRank - 1, orElse: () => _fullLeaderboard.first)
        : null;
    final pointsNeeded = aboveUser != null ? ((aboveUser['points'] as int) - (userEntry['points'] as int)) : 0;

    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: Column(
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
                  const SizedBox(height: 16),

                  // Tab switcher
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tab,
                      indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: AppColors.primaryBlue,
                      unselectedLabelColor: Colors.white.withAlpha(180),
                      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      dividerColor: Colors.transparent,
                      tabs: const [Tab(text: 'Global Impact'), Tab(text: 'My City')],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Podium (top 3) ──────────────────────────────────
                  _Podium(entries: _fullLeaderboard.take(3).toList(), currentName: currentName),
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
              child: TabBarView(
                controller: _tab,
                children: [
                  _LeaderList(entries: _fullLeaderboard.skip(3).toList(), currentName: currentName),
                  _LeaderList(entries: _fullLeaderboard.where((e) => e['city'] == 'Mumbai').skip(1).toList(), currentName: currentName),
                ],
              ),
            ),
          ),

          // ── Sticky current user banner ──────────────────────────────
          _CurrentUserBanner(
            entry: userEntry,
            pointsNeeded: pointsNeeded,
            aboveName: aboveUser?['name'] as String?,
          ),
        ],
      ),
    );
  }
}

// ── Podium ────────────────────────────────────────────────────────────────────

class _Podium extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  final String currentName;
  const _Podium({required this.entries, required this.currentName});

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
        _PodiumSlot(entry: second, height: 90, medalColor: const Color(0xFFB0B7C3), rank: 2, isCurrentUser: (second['name'] as String) == currentName)
            .animate().fadeIn(delay: 200.ms).slideY(begin: 0.3, end: 0, delay: 200.ms),
        const SizedBox(width: 12),
        // 1st place (center, tallest)
        _PodiumSlot(entry: first, height: 120, medalColor: AppColors.primaryYellow, rank: 1, isCurrentUser: (first['name'] as String) == currentName)
            .animate().fadeIn(delay: 100.ms).slideY(begin: 0.3, end: 0, delay: 100.ms),
        const SizedBox(width: 12),
        // 3rd place (right, shortest)
        _PodiumSlot(entry: third, height: 72, medalColor: const Color(0xFFCD7F32), rank: 3, isCurrentUser: (third['name'] as String) == currentName)
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
  final String currentName;
  const _LeaderList({required this.entries, required this.currentName});

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
        final isMe = (e['name'] as String) == currentName;
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
    final rank = entry['rank'] as int;
    final name = entry['name'] as String;
    final level = entry['level'] as String? ?? '';
    final points = entry['points'] as int;
    final trees = entry['trees'] as int;

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
