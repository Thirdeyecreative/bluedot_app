import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/app_colors.dart';

/// A reusable, fully in-app camera. Lets the user capture one or more photos
/// in a single session and returns them as `List<File>` via `Navigator.pop`.
///
/// Use [openInAppCamera] rather than constructing this directly.
class InAppCameraPage extends StatefulWidget {
  final int maxImages;
  final String title;

  const InAppCameraPage({super.key, this.maxImages = 5, this.title = 'Capture Photos'});

  @override
  State<InAppCameraPage> createState() => _InAppCameraPageState();
}

/// Opens the in-app camera and returns the captured photos (empty if cancelled).
Future<List<File>> openInAppCamera(
  BuildContext context, {
  int maxImages = 5,
  String title = 'Capture Photos',
}) async {
  final result = await Navigator.of(context).push<List<File>>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => InAppCameraPage(maxImages: maxImages, title: title),
    ),
  );
  return result ?? const <File>[];
}

class _InAppCameraPageState extends State<InAppCameraPage> with WidgetsBindingObserver {
  CameraController? _controller;
  final List<File> _captured = [];
  bool _permissionDenied = false;
  bool _capturing = false;
  String? _error;
  FlashMode _flash = FlashMode.off;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      c.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (mounted) setState(() => _permissionDenied = true);
      return;
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _error = 'No camera found on this device.');
        return;
      }
      final controller = CameraController(cameras.first, ResolutionPreset.high, enableAudio: false);
      await controller.initialize();
      await controller.setFlashMode(_flash);
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not start the camera. Please try again.');
    }
  }

  Future<void> _toggleFlash() async {
    final c = _controller;
    if (c == null) return;
    final next = _flash == FlashMode.off ? FlashMode.torch : FlashMode.off;
    await c.setFlashMode(next);
    if (mounted) setState(() => _flash = next);
  }

  Future<void> _capture() async {
    final c = _controller;
    if (_capturing || c == null || !c.value.isInitialized) return;
    if (_captured.length >= widget.maxImages) return;
    setState(() => _capturing = true);
    try {
      final shot = await c.takePicture();
      _captured.add(File(shot.path));
    } catch (_) {
      // Ignore a single failed frame; the user can tap again.
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _done() => Navigator.of(context).pop(List<File>.from(_captured));

  @override
  Widget build(BuildContext context) {
    final atMax = _captured.length >= widget.maxImages;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _permissionDenied
            ? _DeniedView(onOpenSettings: openAppSettings)
            : _error != null
                ? _ErrorView(message: _error!)
                : _controller == null || !_controller!.value.isInitialized
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primaryYellow))
                    : Column(
                        children: [
                          // Top bar
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                                  onPressed: () => Navigator.of(context).pop(<File>[]),
                                ),
                                Expanded(
                                  child: Text(
                                    widget.title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    _flash == FlashMode.torch ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                                    color: Colors.white,
                                  ),
                                  onPressed: _toggleFlash,
                                ),
                              ],
                            ),
                          ),
                          // Live preview
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CameraPreview(_controller!),
                                  if (atMax)
                                    Container(
                                      color: Colors.black54,
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Maximum ${widget.maxImages} photos reached',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          // Captured thumbnails
                          if (_captured.isNotEmpty)
                            SizedBox(
                              height: 76,
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                scrollDirection: Axis.horizontal,
                                itemCount: _captured.length,
                                separatorBuilder: (_, _) => const SizedBox(width: 8),
                                itemBuilder: (_, i) => Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.file(_captured[i], width: 56, height: 56, fit: BoxFit.cover),
                                    ),
                                    Positioned(
                                      top: -6,
                                      right: -6,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.cancel_rounded, color: Colors.white, size: 20),
                                        onPressed: () => setState(() => _captured.removeAt(i)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Controls
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 64,
                                  child: Text(
                                    '${_captured.length}/${widget.maxImages}',
                                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Expanded(
                                  child: Center(
                                    child: GestureDetector(
                                      onTap: atMax ? null : _capture,
                                      child: Container(
                                        width: 72,
                                        height: 72,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: atMax ? Colors.white24 : Colors.white,
                                          border: Border.all(color: AppColors.primaryYellow, width: 4),
                                        ),
                                        child: _capturing
                                            ? const Padding(
                                                padding: EdgeInsets.all(20),
                                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
                                              )
                                            : Icon(Icons.camera_alt_rounded, color: atMax ? Colors.white54 : AppColors.primaryBlue),
                                      ),
                                    ).animate(target: _capturing ? 1 : 0).scaleXY(end: 0.92, duration: 120.ms),
                                  ),
                                ),
                                SizedBox(
                                  width: 64,
                                  child: TextButton(
                                    onPressed: _captured.isEmpty ? null : _done,
                                    child: Text(
                                      'Done',
                                      style: TextStyle(
                                        color: _captured.isEmpty ? Colors.white38 : AppColors.primaryYellow,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}

class _DeniedView extends StatelessWidget {
  final Future<bool> Function() onOpenSettings;
  const _DeniedView({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_rounded, color: Colors.white54, size: 56),
              const SizedBox(height: 16),
              const Text(
                'Camera access is needed to take photos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () => onOpenSettings(), child: const Text('Open Settings')),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(<File>[]),
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white54, size: 56),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15)),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.of(context).pop(<File>[]),
                child: const Text('Close', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      );
}
