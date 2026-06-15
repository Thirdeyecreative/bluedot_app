import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/directory_repository.dart';
import '../models/species_model.dart';

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void update(String q) => state = q;
}

final speciesListProvider = FutureProvider<List<TreeSpecies>>((ref) {
  final query = ref.watch(searchQueryProvider);
  return ref.watch(directoryRepositoryProvider).fetchSpecies(search: query);
});

final speciesDetailProvider = FutureProvider.family<TreeSpecies, String>((ref, id) {
  return ref.watch(directoryRepositoryProvider).fetchSpeciesById(id);
});
