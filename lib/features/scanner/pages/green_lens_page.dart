import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/scanner_provider.dart';
import '../models/scan_result_model.dart';
import '../widgets/scan_result_sheet.dart';
import '../widgets/ai_analyzing_overlay.dart';
import '../../../core/widgets/in_app_camera_page.dart';
import '../../../core/services/api_client.dart';

/// Entry point for "The Green Lens": opens the same in-app multi-photo
/// camera used by Suggest Site, then runs the AI identification flow.
class GreenLensPage extends ConsumerStatefulWidget {
  const GreenLensPage({super.key});

  @override
  ConsumerState<GreenLensPage> createState() => _GreenLensPageState();
}

class _GreenLensPageState extends ConsumerState<GreenLensPage> {
  bool _analyzing = false;
  File? _backdrop;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCapture());
  }

  Future<void> _startCapture() async {
    final photos = await openInAppCamera(context, maxImages: 5, title: 'Scan a Tree');
    if (photos.isEmpty) {
      if (mounted) context.pop();
      return;
    }
    await _runScan(photos);
  }

  Future<void> _runScan(List<File> photos) async {
    setState(() {
      _analyzing = true;
      _backdrop = photos.first;
    });

    try {
      Position? position;
      try {
        await Permission.locationWhenInUse.request();
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 5)),
        );
      } catch (_) {
        // Use 0,0 as fallback -- backend will still process
      }

      final result = await ref.read(scanResultProvider.notifier).scan(
            images: photos,
            lat: position?.latitude ?? 0,
            lng: position?.longitude ?? 0,
          );
      if (!mounted) return;
      if (result != null) {
        context.pop();
        _showResultSheet(result);
      }
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'Scan failed. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.errorRed),
      );
      context.pop();
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  void _showResultSheet(ScanResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScanResultSheet(result: result),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_analyzing) {
      return AiAnalyzingOverlay(backdropImage: _backdrop);
    }
    // While the in-app camera is open (pushed as its own route) or after it
    // closes with no photos, this page itself has nothing to render.
    return const Scaffold(backgroundColor: Colors.black);
  }
}
