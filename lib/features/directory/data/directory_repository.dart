import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../../../core/config/api_config.dart';
import '../models/species_model.dart';

final directoryRepositoryProvider = Provider<DirectoryRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return DirectoryRepository(api);
});

class DirectoryRepository {
  final ApiClient _api;
  DirectoryRepository(this._api);

  Future<List<TreeSpecies>> fetchSpecies({String? search}) async {
    final response = await _api.get(ApiConfig.directoryData, requireAuth: false);
    final data = response['data'] as List<dynamic>;
    
    final speciesList = data.map((json) => TreeSpecies.fromJson(json)).toList();

    final query = search?.trim().toLowerCase() ?? '';
    if (query.isEmpty) return speciesList;

    return speciesList
        .where(
          (species) =>
              species.localName.toLowerCase().contains(query) ||
              species.scientificName.toLowerCase().contains(query) ||
              (species.family?.toLowerCase().contains(query) ?? false),
        )
        .toList();
  }

  Future<TreeSpecies> fetchSpeciesById(String id) async {
    final speciesList = await fetchSpecies();
    return speciesList.firstWhere(
      (species) => species.id == id,
      orElse: () => throw Exception('Species not found'),
    );
  }
}
