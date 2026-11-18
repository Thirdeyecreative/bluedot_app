import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/acoustic_service.dart';

/// Modal bottom sheet that measures ambient noise via the device microphone,
/// evaluates acoustic comfort, and displays urban tree canopy sound-dampening insights.
class AcousticMeterSheet extends StatefulWidget {
  const AcousticMeterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const AcousticMeterSheet(),
    );
  }

  @override
  State<AcousticMeterSheet> createState() => _AcousticMeterSheetState();
}

class _AcousticMeterSheetState extends State<AcousticMeterSheet>
    with SingleTickerProviderStateMixin {
  final AcousticService _service = AcousticService();

  bool _isMeasuring = false;
  double _liveDb = 45.0;
  AcousticReading? _result;
  String? _errorMessage;

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _startMeasurement() async {
    setState(() {
      _isMeasuring = true;
      _errorMessage = null;
      _result = null;
      _liveDb = 42.0;
    });

    try {
      final reading = await _service.sampleAmbientNoise(
        duration: const Duration(seconds: 3),
        onProgress: (db) {
          if (mounted) {
            setState(() {
              _liveDb = db;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _result = reading;
          _isMeasuring = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isMeasuring = false;
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.fromLTRB(22, 12, 22, 20 + bottomPadding),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sheet Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3EB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.graphic_eq_rounded,
                    color: Color(0xFF2E5A36),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Acoustic Tranquility Meter',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Ambient decibels & tree sound dampening',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMedium),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Main State Switcher
            if (_errorMessage != null)
              _buildErrorView()
            else if (_isMeasuring)
              _buildMeasuringView()
            else if (_result != null)
              _buildResultView(_result!)
            else
              _buildIdleView(),

            const SizedBox(height: 18),

            // Privacy & Transparency Footnote
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderLight.withOpacity(0.6)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.textMedium),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '100% On-Device & Private. Raw amplitude is measured in RAM and immediately deleted without saving any audio.',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textMedium,
                        height: 1.3,
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

  // ── IDLE VIEW ──────────────────────────────────────────────────────────────
  Widget _buildIdleView() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF16A34A).withOpacity(0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  color: Color(0xFF16A34A),
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Sample Local Ambient Noise',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF14532D),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Hold your phone steady for 3 seconds. The meter measures the sound pressure level (dB) and analyzes nearby green tranquility.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF166534),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _startMeasurement,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 22),
            label: const Text(
              'Measure Noise Level',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── MEASURING VIEW ─────────────────────────────────────────────────────────
  Widget _buildMeasuringView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          // Dynamic Wave Visualizer
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(9, (index) {
                  // Generate varying wave heights based on live dB and anim phase
                  final variance = (index % 3 == 0)
                      ? _animController.value
                      : (1.0 - _animController.value);
                  final normalizedDb = ((_liveDb - 35) / 55).clamp(0.15, 1.0);
                  final barHeight = 12.0 + (50.0 * normalizedDb * variance);

                  final barColor = _liveDb < 55
                      ? const Color(0xFF16A34A)
                      : (_liveDb < 70
                          ? const Color(0xFFD97706)
                          : const Color(0xFFDC2626));

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 5,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: barColor.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            '${_liveDb.toStringAsFixed(0)} dB',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Sampling acoustic surroundings...',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textMedium,
            ),
          ),
        ],
      ),
    );
  }

  // ── RESULT VIEW ────────────────────────────────────────────────────────────
  Widget _buildResultView(AcousticReading res) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Result Score Banner
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: res.backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: res.accentColor.withOpacity(0.35)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(res.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      Text(
                        res.tierTitle,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: res.accentColor,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: res.accentColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      '${res.decibels.toStringAsFixed(0)} dB',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: res.accentColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Decibel Spectrum Gauge
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 7,
                  child: Stack(
                    children: [
                      Row(
                        children: [
                          Expanded(flex: 20, child: Container(color: const Color(0xFF16A34A))),
                          Expanded(flex: 15, child: Container(color: const Color(0xFFD97706))),
                          Expanded(flex: 15, child: Container(color: const Color(0xFFEA580C))),
                          Expanded(flex: 20, child: Container(color: const Color(0xFFDC2626))),
                        ],
                      ),
                      Align(
                        alignment: Alignment(
                          ((res.decibels - 30) / (90 - 30) * 2 - 1).clamp(-1.0, 1.0),
                          0,
                        ),
                        child: Container(
                          width: 4,
                          height: 7,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('30 dB (Forest)', style: TextStyle(fontSize: 10.5, color: AppColors.textMedium)),
                  Text('90+ dB (Traffic)', style: TextStyle(fontSize: 10.5, color: AppColors.textMedium)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                res.description,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textDark,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Tree Canopy Buffer Educational Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3EB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFC7E2CA)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.park_rounded,
                color: Color(0xFF2E5A36),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tree Canopy Acoustic Buffer',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B3B22),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      res.treeBufferInsight,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2E5A36),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Retest button
        SizedBox(
          height: 46,
          child: OutlinedButton.icon(
            onPressed: _startMeasurement,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
              side: const BorderSide(color: AppColors.primaryGreen, width: 1.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 19),
            label: const Text(
              'Sample Noise Again',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── ERROR VIEW ─────────────────────────────────────────────────────────────
  Widget _buildErrorView() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        children: [
          const Icon(Icons.mic_off_rounded, color: Color(0xFFDC2626), size: 34),
          const SizedBox(height: 10),
          const Text(
            'Microphone Access Needed',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF991B1B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage ??
                'Please grant microphone permission in device settings to sample ambient sound levels.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFFB91C1C),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _startMeasurement,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Grant & Try Again'),
          ),
        ],
      ),
    );
  }
}
