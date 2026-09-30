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

  Future<List<TreeSpecies>> fetchSpecies({String? search, int limit = 20, int offset = 0}) async {
    final queryParams = {
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };
    
    // We append the query string to the URL manually or assume the API client handles it.
    // If _api.get doesn't take query params, we build the string.
    final queryString = Uri(queryParameters: queryParams).query;
    final url = '${ApiConfig.directoryData}?$queryString';

    final response = await _api.get(url, requireAuth: false);
    final data = response['data'] as List<dynamic>;
    
    return data.map((json) => TreeSpecies.fromJson(json)).toList();
  }

  Future<TreeSpecies> fetchSpeciesById(String id) async {
    final response = await _api.get('${ApiConfig.directoryData}/$id', requireAuth: false);
    return TreeSpecies.fromJson(response);
  }
}
