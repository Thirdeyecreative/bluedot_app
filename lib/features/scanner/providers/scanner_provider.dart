import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/scanner_repository.dart';
import '../models/scan_result_model.dart';

export '../data/scanner_repository.dart';

// Holds the result of the latest scan (null = nothing scanned yet)
final scanResultProvider = NotifierProvider<ScanResultNotifier, ScanResult?>(ScanResultNotifier.new);

class ScanResultNotifier extends Notifier<ScanResult?> {
  @override
  ScanResult? build() => null;

  void clear() => state = null;

  Future<ScanResult?> scan({required List<File> images, required double lat, required double lng}) async {
    state = null;
    final result = await ref.read(scannerRepositoryProvider).scanTree(images: images, lat: lat, lng: lng);
    state = result;
    return result;
  }
}

// Scan history
final scanHistoryProvider = FutureProvider<List<ScanHistoryItem>>((ref) {
  return ref.watch(scannerRepositoryProvider).fetchHistory();
});

// Geo-bounding box parameter model for targeted map queries
class GeoBoundingBox {
  final double minLat;
  final double minLng;
  final double maxLat;
  final double maxLng;

  const GeoBoundingBox({
    required this.minLat,
    required this.minLng,
    required this.maxLat,
    required this.maxLng,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoBoundingBox &&
          runtimeType == other.runtimeType &&
          minLat == other.minLat &&
          minLng == other.minLng &&
          maxLat == other.maxLat &&
          maxLng == other.maxLng;

  @override
  int get hashCode =>
      minLat.hashCode ^ minLng.hashCode ^ maxLat.hashCode ^ maxLng.hashCode;
}

// Targeted nearby trees provider scoped by dynamic viewport or user proximity
final nearbyTreesProvider =
    FutureProvider.family<List<ScanHistoryItem>, GeoBoundingBox>((ref, bbox) async {
  final trees = await ref.watch(scannerRepositoryProvider).fetchMapTrees(
        minLat: bbox.minLat,
        minLng: bbox.minLng,
        maxLat: bbox.maxLat,
        maxLng: bbox.maxLng,
      );
  return trees.toList();
});

// Bangalore bounding box (~30km around the city center) used as a safe fallback
const bangaloreCenterLat = 12.9716;
const bangaloreCenterLng = 77.5946;
const _bangaloreBoxDegrees = 0.3;

final mapTreesProvider = FutureProvider<List<ScanHistoryItem>>((ref) async {
  final trees = await ref.watch(scannerRepositoryProvider).fetchMapTrees(
        minLat: bangaloreCenterLat - _bangaloreBoxDegrees,
        minLng: bangaloreCenterLng - _bangaloreBoxDegrees,
        maxLat: bangaloreCenterLat + _bangaloreBoxDegrees,
        maxLng: bangaloreCenterLng + _bangaloreBoxDegrees,
      );
  // Species still awaiting admin review aren't confirmed yet -- keep them
  // off the public map until approved.
  return trees.toList();
});
