import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/scanner_provider.dart';
import '../models/scan_result_model.dart';
import '../widgets/scan_result_sheet.dart';

class GreenLensPage extends ConsumerStatefulWidget {
  const GreenLensPage({super.key});

  @override
  ConsumerState<GreenLensPage> createState() => _GreenLensPageState();
}

class _GreenLensPageState extends ConsumerState<GreenLensPage>
    with TickerProviderStateMixin {
  CameraController? _controller;
  late AnimationController _pulseController;
  late AnimationController _scanLineController;
  bool _isCapturing = false;
  bool _permissionDenied = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      setState(() => _permissionDenied = true);
      return;
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _errorMessage = 'No camera found on this device.');
        return;
      }
      _controller = CameraController(cameras.first, ResolutionPreset.high, enableAudio: false);
      await _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  Future<void> _capture() async {
    if (_isCapturing || _controller == null || !_controller!.value.isInitialized) return;
    setState(() => _isCapturing = true);

    try {
      // Get location
      Position? position;
      try {
        await Permission.locationWhenInUse.request();
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 5)),
        );
      } catch (_) {
        // Use 0,0 as fallback — backend will still process
      }

      final xFile = await _controller!.takePicture();
      final file = File(xFile.path);
      final result = await ref.read(scanResultProvider.notifier).scan(
            image: file,
            lat: position?.latitude ?? 0,
            lng: position?.longitude ?? 0,
          );
      if (mounted && result != null) {
        _showResultSheet(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan failed: ${e.toString()}'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
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
  void dispose() {
    _pulseController.dispose();
    _scanLineController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return _PermissionDeniedView(onOpenSettings: openAppSettings);
    }
    if (_errorMessage != null) {
      return _ErrorView(message: _errorMessage!);
    }
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryYellow)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Live Camera Preview
          CameraPreview(_controller!),

          // Dark vignette overlay
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [Colors.transparent, Color(0x99000000)],
              ),
            ),
          ),

          // Scanning Reticle
          Center(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (_, child) => Transform.scale(
                scale: 1.0 + (_pulseController.value * 0.04),
                child: child,
              ),
              child: SizedBox(
                width: 240,
                height: 240,
                child: CustomPaint(
                  painter: _ReticlePainter(
                    color: AppColors.scannerReticle,
                    scanProgress: _scanLineController.value,
                  ),
                ),
              ),
            ),
          ),

          // Scan line animation inside reticle
          Center(
            child: SizedBox(
              width: 240,
              height: 240,
              child: AnimatedBuilder(
                animation: _scanLineController,
                builder: (_, _) => CustomPaint(
                  painter: _ScanLinePainter(progress: _scanLineController.value),
                ),
              ),
            ),
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _CircleIconButton(
                    icon: Icons.close_rounded,
                    onTap: () => context.pop(),
                  ),
                  const Spacer(),
                  const Text(
                    'The Green Lens',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  _CircleIconButton(
                    icon: Icons.flash_on_rounded,
                    onTap: () {
                      final flash = _controller!.value.flashMode == FlashMode.off
                          ? FlashMode.torch
                          : FlashMode.off;
                      _controller!.setFlashMode(flash);
                    },
                  ),
                ],
              ),
            ),
          ),

          // Hint text
          Positioned(
            bottom: 200,
            left: 0,
            right: 0,
            child: Text(
              'Point at any plant to identify',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withAlpha(200),
                fontSize: 14,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.2,
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(duration: 800.ms),
          ),

          // Capture button
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _isCapturing ? null : _capture,
                child: AnimatedContainer(
                  duration: 200.ms,
                  width: _isCapturing ? 64 : 80,
                  height: _isCapturing ? 64 : 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    color: _isCapturing ? AppColors.primaryYellow : Colors.transparent,
                  ),
                  child: Center(
                    child: _isCapturing
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Container(
                            width: 62,
                            height: 62,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryYellow,
                              shape: BoxShape.circle,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reticle Painter ──────────────────────────────────────────────────────────

class _ReticlePainter extends CustomPainter {
  final Color color;
  final double scanProgress;
  _ReticlePainter({required this.color, required this.scanProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final r = 20.0;
    final l = 50.0;
    final w = size.width;
    final h = size.height;

    // Top-left corner
    canvas.drawLine(Offset(0, r), Offset(0, r + l), paint);
    canvas.drawArc(Rect.fromLTWH(0, 0, r * 2, r * 2), math.pi, math.pi / 2, false, paint);
    canvas.drawLine(Offset(r, 0), Offset(r + l, 0), paint);

    // Top-right corner
    canvas.drawLine(Offset(w - r - l, 0), Offset(w - r, 0), paint);
    canvas.drawArc(Rect.fromLTWH(w - r * 2, 0, r * 2, r * 2), -math.pi / 2, math.pi / 2, false, paint);
    canvas.drawLine(Offset(w, r), Offset(w, r + l), paint);

    // Bottom-left corner
    canvas.drawLine(Offset(0, h - r - l), Offset(0, h - r), paint);
    canvas.drawArc(Rect.fromLTWH(0, h - r * 2, r * 2, r * 2), math.pi / 2, math.pi / 2, false, paint);
    canvas.drawLine(Offset(r, h), Offset(r + l, h), paint);

    // Bottom-right corner
    canvas.drawLine(Offset(w - r - l, h), Offset(w - r, h), paint);
    canvas.drawArc(Rect.fromLTWH(w - r * 2, h - r * 2, r * 2, r * 2), 0, math.pi / 2, false, paint);
    canvas.drawLine(Offset(w, h - r - l), Offset(w, h - r), paint);
  }

  @override
  bool shouldRepaint(_ReticlePainter old) => old.color != color;
}

// ── Scan Line Painter ─────────────────────────────────────────────────────────

class _ScanLinePainter extends CustomPainter {
  final double progress;
  _ScanLinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    final gradient = LinearGradient(
      colors: [Colors.transparent, AppColors.primaryYellow.withAlpha(180), Colors.transparent],
    );
    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, y - 1, size.width, 2))
      ..strokeWidth = 2;
    canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), paint);
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => old.progress != progress;
}

// ── Permission / Error views ──────────────────────────────────────────────────

class _PermissionDeniedView extends StatelessWidget {
  final VoidCallback onOpenSettings;
  const _PermissionDeniedView({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt_outlined, size: 64, color: AppColors.slateBlue),
              const SizedBox(height: 20),
              Text('Camera Access Required',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              const Text(
                'The Green Lens needs camera access to identify plants. Please enable it in Settings.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMedium),
              ),
              const SizedBox(height: 32),
              ElevatedButton(onPressed: onOpenSettings, child: const Text('Open Settings')),
              const SizedBox(height: 12),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back')),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.errorRed),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back')),
            ],
          ),
        ),
      );
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(100),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      );
}
