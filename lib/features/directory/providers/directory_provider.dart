import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/directory_repository.dart';
import '../models/species_model.dart';

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void update(String q) => state = q;
}

final speciesListProvider = AsyncNotifierProvider<SpeciesListNotifier, List<TreeSpecies>>(SpeciesListNotifier.new);

class SpeciesListNotifier extends AsyncNotifier<List<TreeSpecies>> {
  bool _hasMore = true;
  bool _isLoadingMore = false;
  static const int _limit = 20;

  bool get hasMore => _hasMore;

  @override
  Future<List<TreeSpecies>> build() async {
    final query = ref.watch(searchQueryProvider);
    _hasMore = true;
    final list = await ref.watch(directoryRepositoryProvider).fetchSpecies(search: query, limit: _limit, offset: 0);
    if (list.length < _limit) _hasMore = false;
    return list;
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;
    
    final currentData = state.value;
    if (currentData == null) return;

    _isLoadingMore = true;
    try {
      final query = ref.read(searchQueryProvider);
      final offset = currentData.length;
      final newList = await ref.read(directoryRepositoryProvider).fetchSpecies(
        search: query,
        limit: _limit,
        offset: offset,
      );

      if (newList.length < _limit) _hasMore = false;
      state = AsyncData([...currentData, ...newList]);
    } catch (e, st) {
      state = AsyncError(e, st);
    } finally {
      _isLoadingMore = false;
    }
  }
}

final speciesDetailProvider = FutureProvider.family<TreeSpecies, String>((ref, id) {
  return ref.watch(directoryRepositoryProvider).fetchSpeciesById(id);
});
