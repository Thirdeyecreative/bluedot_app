import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';

/// A full-screen, "AI is thinking" style loading state shown while the scan
/// request is in flight. Purely cosmetic -- masks normal network latency
/// behind a sequence of progressively-reassuring status lines so the wait
/// never reads as a stuck spinner.
class AiAnalyzingOverlay extends StatefulWidget {
  final File? backdropImage;

  const AiAnalyzingOverlay({super.key, this.backdropImage});

  @override
  State<AiAnalyzingOverlay> createState() => _AiAnalyzingOverlayState();
}

class _AiAnalyzingOverlayState extends State<AiAnalyzingOverlay> with TickerProviderStateMixin {
  static const _phrases = [
    'Scanning leaf structure…',
    'Matching species database…',
    'Cross-checking PlantNet & AI…',
    'Almost there…',
  ];

  late final AnimationController _ringController;
  int _phraseIndex = 0;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _cyclePhrases();
  }

  Future<void> _cyclePhrases() async {
    while (mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      if (!mounted) return;
      setState(() => _phraseIndex = (_phraseIndex + 1) % _phrases.length);
    }
  }

  @override
  void dispose() {
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.backdropImage != null)
            Image.file(widget.backdropImage!, fit: BoxFit.cover)
          else
            Container(color: AppColors.primaryBlue.withAlpha(40)),
          // Dark blur so the UI reads clearly over any backdrop photo.
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(color: Colors.black.withAlpha(150)),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      RotationTransition(
                        turns: _ringController,
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: [
                                Colors.transparent,
                                AppColors.primaryYellow,
                                AppColors.sageGreen,
                                Colors.transparent,
                              ],
                              stops: [0.0, 0.35, 0.7, 1.0],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 112,
                        height: 112,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black),
                      ),
                      const Icon(Icons.eco_rounded, color: AppColors.primaryYellow, size: 48)
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scaleXY(begin: 0.85, end: 1.05, duration: 900.ms, curve: Curves.easeInOut),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Text(
                    _phrases[_phraseIndex],
                    key: ValueKey(_phraseIndex),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Identifying your tree with AI',
                  style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
