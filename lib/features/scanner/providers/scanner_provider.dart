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

  Future<ScanResult?> scan({required File image, required double lat, required double lng}) async {
    state = null;
    final result = await ref.read(scannerRepositoryProvider).scanTree(image: image, lat: lat, lng: lng);
    state = result;
    return result;
  }
}

// Scan history
final scanHistoryProvider = FutureProvider<List<ScanHistoryItem>>((ref) {
  return ref.watch(scannerRepositoryProvider).fetchHistory();
});
