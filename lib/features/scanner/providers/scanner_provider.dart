import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/scanner_repository.dart';
import '../models/scan_result_model.dart';

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

// Bangalore bounding box (~30km around the city center) used to scope the
// Eco Garden map to trees tagged in and around Bangalore.
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
  return trees.where((t) => t.species?.isPendingReview != true).toList();
});
