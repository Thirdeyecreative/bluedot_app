import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_config.dart';
import '../../../core/services/api_client.dart';

/// State indicating if the leaderboard is currently fetching the next page.
final isFetchingMoreLeaderboardProvider =
    NotifierProvider<IsFetchingMoreLeaderboardNotifier, bool>(
  IsFetchingMoreLeaderboardNotifier.new,
);

class IsFetchingMoreLeaderboardNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void update(bool val) => state = val;
}

/// Paginated leaderboard notifier with buttery-smooth incremental loading.
final leaderboardProvider =
    AsyncNotifierProvider<LeaderboardNotifier, List<Map<String, dynamic>>>(
  LeaderboardNotifier.new,
);

class LeaderboardNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  bool _hasMore = true;
  bool _isLoadingMore = false;
  int _nextOffset = 0;
  static const int _pageSize = 30;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    _hasMore = true;
    _isLoadingMore = false;
    _nextOffset = _pageSize;

    final api = ref.watch(apiClientProvider);
    final data = await api.get(
      ApiConfig.leaderboard,
      query: {
        'limit': '$_pageSize',
        'offset': '0',
      },
    ) as List<dynamic>;

    final list = data.cast<Map<String, dynamic>>();
    if (list.length < _pageSize) {
      _hasMore = false;
    }
    return list;
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;

    final currentData = state.value;
    if (currentData == null || currentData.isEmpty) return;

    _isLoadingMore = true;
    ref.read(isFetchingMoreLeaderboardProvider.notifier).update(true);

    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get(
        ApiConfig.leaderboard,
        query: {
          'limit': '$_pageSize',
          'offset': '$_nextOffset',
        },
      ) as List<dynamic>;

      _nextOffset += _pageSize;

      final newList = data.cast<Map<String, dynamic>>();
      if (newList.length < _pageSize) {
        _hasMore = false;
      }

      // Deduplicate by rank
      final existingRanks = currentData
          .map((e) => (e['rank'] as num?)?.toInt())
          .where((r) => r != null && r > 0)
          .toSet();

      final filteredNew = newList.where((e) {
        final r = (e['rank'] as num?)?.toInt();
        return r != null && !existingRanks.contains(r);
      }).toList();

      if (filteredNew.isEmpty && newList.isNotEmpty) {
        _hasMore = false;
      } else {
        final combined = [...currentData, ...filteredNew];
        // Sort by rank to ensure consistent ordering
        combined.sort((a, b) {
          final rA = (a['rank'] as num?)?.toInt() ?? 0;
          final rB = (b['rank'] as num?)?.toInt() ?? 0;
          return rA.compareTo(rB);
        });
        state = AsyncData(combined);
      }
    } catch (_) {
      // Graceful error handling: preserve currently displayed items on network hiccup
    } finally {
      _isLoadingMore = false;
      ref.read(isFetchingMoreLeaderboardProvider.notifier).update(false);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    ref.invalidateSelf();
  }
}
