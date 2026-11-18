import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_config.dart';
import '../../../core/services/api_client.dart';
import '../models/scan_result_model.dart';

final scannerRepositoryProvider = Provider<ScannerRepository>((ref) {
  return ScannerRepository(ref.watch(apiClientProvider));
});

class MapTreesResult {
  final List<ScanHistoryItem> trees;
  final int totalCount;
  final int userTreesCount;

  const MapTreesResult({
    required this.trees,
    required this.totalCount,
    this.userTreesCount = 0,
  });
}

class ScannerRepository {
  final ApiClient _api;
  ScannerRepository(this._api);

  Future<ScanResult> scanTree({
    required List<File> images,
    required double lat,
    required double lng,
  }) async {
    final json = await _api.multipartPost(
      ApiConfig.scan,
      fields: {
        'lat': lat.toString(),
        'lng': lng.toString(),
      },
      files: images,
      fileField: 'images',
      // Multiple full-res photo uploads plus AI identification (with a
      // PlantNet -> Vertex AI fallback) routinely take longer than the
      // default 30s used for quick JSON calls.
      timeout: const Duration(seconds: 75),
    );
    return ScanResult.fromJson(json as Map<String, dynamic>);
  }

  Future<List<ScanHistoryItem>> fetchHistory() async {
    final json = await _api.get(ApiConfig.scanHistory);
    final data = (json as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => ScanHistoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches trees within a bounding box, along with platform-wide total tree counts.
  Future<MapTreesResult> fetchMapTreesWithStats({
    double? minLat,
    double? minLng,
    double? maxLat,
    double? maxLng,
    String? userId,
  }) async {
    final queryParams = <String, String>{};
    if (minLat != null && minLng != null && maxLat != null && maxLng != null) {
      queryParams['min_lat'] = minLat.toString();
      queryParams['min_lng'] = minLng.toString();
      queryParams['max_lat'] = maxLat.toString();
      queryParams['max_lng'] = maxLng.toString();
    }
    if (userId != null && userId.isNotEmpty) {
      queryParams['user_id'] = userId;
    }

    final json = await _api.get(
      ApiConfig.mapData,
      requireAuth: false,
      query: queryParams.isNotEmpty ? queryParams : null,
    );

    final raw = json as Map<String, dynamic>;
    final data = raw['data'] as List<dynamic>? ?? [];
    final totalCount = (raw['total_count'] as num?)?.toInt() ??
        (raw['count'] as num?)?.toInt() ??
        data.length;
    final userTreesCount = (raw['user_trees_count'] as num?)?.toInt() ?? 0;

    final trees = data
        .map((e) => ScanHistoryItem.fromJson(e as Map<String, dynamic>))
        .where((item) => item.hasLocation)
        .toList();

    return MapTreesResult(
      trees: trees,
      totalCount: totalCount,
      userTreesCount: userTreesCount,
    );
  }

  /// All community-tagged trees within a bounding box, for the map view.
  Future<List<ScanHistoryItem>> fetchMapTrees({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
  }) async {
    final result = await fetchMapTreesWithStats(
      minLat: minLat,
      minLng: minLng,
      maxLat: maxLat,
      maxLng: maxLng,
    );
    return result.trees;
  }
}
