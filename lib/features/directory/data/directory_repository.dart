import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/demo/demo_data.dart';
import '../models/species_model.dart';

final directoryRepositoryProvider = Provider<DirectoryRepository>((ref) {
  return DirectoryRepository();
});

class DirectoryRepository {
  Future<void> _demoDelay() => Future<void>.delayed(const Duration(milliseconds: 250));

  Future<List<TreeSpecies>> fetchSpecies({String? search}) async {
    await _demoDelay();
    final query = search?.trim().toLowerCase() ?? '';
    if (query.isEmpty) return DemoData.species;
    return DemoData.species
        .where(
          (species) =>
              species.localName.toLowerCase().contains(query) ||
              species.scientificName.toLowerCase().contains(query) ||
              (species.family?.toLowerCase().contains(query) ?? false),
        )
        .toList();
  }

  Future<TreeSpecies> fetchSpeciesById(String id) async {
    await _demoDelay();
    return DemoData.species.firstWhere(
      (species) => species.id == id,
      orElse: () => DemoData.species.first,
    );
  }
}
