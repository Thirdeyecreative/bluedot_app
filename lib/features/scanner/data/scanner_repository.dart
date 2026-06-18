import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_config.dart';
import '../../../core/services/api_client.dart';
import '../models/scan_result_model.dart';

final scannerRepositoryProvider = Provider<ScannerRepository>((ref) {
  return ScannerRepository(ref.watch(apiClientProvider));
});

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

  /// All community-tagged trees within a bounding box, for the map view.
  Future<List<ScanHistoryItem>> fetchMapTrees({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
  }) async {
    final json = await _api.get(
      ApiConfig.mapData,
      requireAuth: false,
      query: {
        'min_lat': minLat.toString(),
        'min_lng': minLng.toString(),
        'max_lat': maxLat.toString(),
        'max_lng': maxLng.toString(),
      },
    );
    final data = (json as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => ScanHistoryItem.fromJson(e as Map<String, dynamic>))
        .where((item) => item.hasLocation)
        .toList();
  }
}
