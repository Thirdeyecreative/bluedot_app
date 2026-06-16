import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_feedback.dart';
import '../providers/action_provider.dart';

class EventCheckinPage extends ConsumerStatefulWidget {
  final String eventId;
  const EventCheckinPage({super.key, required this.eventId});

  @override
  ConsumerState<EventCheckinPage> createState() => _EventCheckinPageState();
}

class _EventCheckinPageState extends ConsumerState<EventCheckinPage> with WidgetsBindingObserver {
  late final MobileScannerController _scanner;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanner = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_scanner.value.isInitialized) return;
    switch (state) {
      case AppLifecycleState.paused:
        _scanner.stop();
      case AppLifecycleState.resumed:
        _scanner.start();
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    // Expected: bluedot://event/{event_id}/checkin?token={token}
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'bluedot' || uri.host != 'event') return;

    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) return;

    setState(() => _processing = true);
    await _scanner.stop();

    try {
      await ref.read(checkInProvider.notifier).checkIn(widget.eventId, token);
      if (!mounted) return;

      final result = ref.read(checkInProvider);
      await result.when(
        data: (r) async {
          if (r == null) return;
          if (r.xpAwarded == 0) {
            // Already checked in
            AppFeedback.showSuccess(context, r.message);
          } else {
            await AppFeedback.showThankYou(
              context,
              title: 'Checked In! ✅',
              message: 'Welcome ${r.role == "Volunteer" ? "Volunteer" : ""}! You\'re all set.',
              xpLabel: '+${r.xpAwarded} XP',
            );
          }
          if (mounted) context.pop();
        },
        loading: () async {},
        error: (e, _) async {
          if (mounted) AppFeedback.showError(context, e);
        },
      );
    } catch (e) {
      if (mounted) AppFeedback.showError(context, e);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan Event QR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded),
            onPressed: () => _scanner.toggleTorch(),
            tooltip: 'Toggle flash',
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Camera preview ─────────────────────────────────────────────
          MobileScanner(
            controller: _scanner,
            onDetect: _onDetect,
          ),

          // ── Scan frame overlay ─────────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primaryBlue, width: 3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _processing
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : null,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    'Point at the QR displayed by your event coordinator',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 300.ms),
        ],
      ),
    );
  }
}
