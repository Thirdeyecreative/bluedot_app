import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/demo/demo_data.dart';
import '../models/scan_result_model.dart';

final scannerRepositoryProvider = Provider<ScannerRepository>((ref) {
  return ScannerRepository();
});

class ScannerRepository {
  Future<ScanResult> scanTree({
    required File image,
    required double lat,
    required double lng,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return DemoData.scanResult;
  }

  Future<List<ScanHistoryItem>> fetchHistory() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return DemoData.scanHistory;
  }
}
