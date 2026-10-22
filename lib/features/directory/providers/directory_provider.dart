import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/directory_repository.dart';
import '../models/species_model.dart';

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void update(String q) => state = q;
}

final isFetchingMoreProvider = NotifierProvider<IsFetchingMoreNotifier, bool>(IsFetchingMoreNotifier.new);

class IsFetchingMoreNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void update(bool val) => state = val;
}

final speciesListProvider = AsyncNotifierProvider<SpeciesListNotifier, List<TreeSpecies>>(SpeciesListNotifier.new);

class SpeciesListNotifier extends AsyncNotifier<List<TreeSpecies>> {
  bool _hasMore = true;
  bool _isLoadingMore = false;
  static const int _limit = 30;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  @override
  Future<List<TreeSpecies>> build() async {
    final query = ref.watch(searchQueryProvider).trim();
    final isSearching = query.isNotEmpty;

    // When searching, fetch all matching results in a single unpaginated API call
    if (isSearching) {
      _hasMore = false;
      final list = await ref.watch(directoryRepositoryProvider).fetchSpecies(
        search: query,
        limit: 500,
        offset: 0,
      );
      return list;
    }

    // When browsing the encyclopedia, paginate smoothly with limit = 30
    _hasMore = true;
    final list = await ref.watch(directoryRepositoryProvider).fetchSpecies(
      search: null,
      limit: _limit,
      offset: 0,
    );
    if (list.length < _limit) _hasMore = false;
    return list;
  }

  Future<void> loadMore() async {
    final query = ref.read(searchQueryProvider).trim();
    if (query.isNotEmpty || !_hasMore || _isLoadingMore) return;
    
    final currentData = state.value;
    if (currentData == null) return;

    _isLoadingMore = true;
    ref.read(isFetchingMoreProvider.notifier).update(true);

    try {
      final offset = currentData.length;
      final newList = await ref.read(directoryRepositoryProvider).fetchSpecies(
        search: null,
        limit: _limit,
        offset: offset,
      );

      if (newList.length < _limit) _hasMore = false;
      state = AsyncData([...currentData, ...newList]);
    } catch (_) {
      // Do not replace loaded data with AsyncError on pagination hitch
    } finally {
      _isLoadingMore = false;
      ref.read(isFetchingMoreProvider.notifier).update(false);
    }
  }
}

final speciesDetailProvider = FutureProvider.family<TreeSpecies, String>((ref, id) {
  return ref.watch(directoryRepositoryProvider).fetchSpeciesById(id);
});
