import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/skeletons.dart';
import '../models/scan_result_model.dart';

class ScanResultSheet extends StatefulWidget {
  final ScanResult result;
  final VoidCallback? onSaved;

  const ScanResultSheet({super.key, required this.result, this.onSaved});

  @override
  State<ScanResultSheet> createState() => _ScanResultSheetState();
}

class _ScanResultSheetState extends State<ScanResultSheet> {
  bool _autoScrolled = false;

  ScanResult get result => widget.result;
  VoidCallback? get onSaved => widget.onSaved;

  /// Once the sheet has settled in, nudge it 60px upward automatically so
  /// more of the result is visible without the user dragging.
  void _autoScrollUp(ScrollController controller) {
    if (_autoScrolled) return;
    _autoScrolled = true;
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted || !controller.hasClients) return;
      controller.animateTo(
        60,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final pn = result.plantnetData;
    final co2 = _estimateCo2(pn?.scientificName);

    // Taller surface: anchored at the bottom, extending up the screen —
    // 20px shy of the 0.85 mark, consistent across device heights.
    final screenHeight = MediaQuery.of(context).size.height;
    final initialSize = (0.85 - 20 / screenHeight).clamp(0.5, 0.95);

    return DraggableScrollableSheet(
      initialChildSize: initialSize,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _autoScrollUp(controller));
        return Container(
        decoration: const BoxDecoration(
          color: AppColors.backgroundCream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 0),
              decoration: BoxDecoration(
                color: AppColors.borderMedium,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Expanded(
              child: ListView(
                controller: controller,
                // Clears the system gesture/nav inset so the Save button
                // is never hidden behind it.
                padding: EdgeInsets.fromLTRB(
                    24, 16, 24, 40 + MediaQuery.of(context).viewPadding.bottom),
                children: [
                  // ── Points badge ───────────────────────────────────────
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: result.isNewTag ? AppColors.primaryBlue : AppColors.forestGreen,
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [
                          BoxShadow(
                            color: (result.isNewTag ? AppColors.primaryBlue : AppColors.forestGreen).withAlpha(60),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded, color: AppColors.primaryYellow, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            '+${result.pointsAwarded} Impact Points',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      .animate()
                      .scaleXY(begin: 0.4, end: 1, curve: Curves.elasticOut, duration: 700.ms)
                      .fadeIn(duration: 300.ms),

                  const SizedBox(height: 20),

                  // ── Plant image thumbnail ──────────────────────────────
                  if (result.assetUrl != null)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: CachedNetworkImage(
                          imageUrl: result.assetUrl!,
                          height: 180,
                          width: 220,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => const AppSkeleton(
                            child: Bone(height: 180, width: 220),
                          ),
                          errorWidget: (_, _, _) => _PlantPlaceholder(),
                        ),
                      ),
                    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1, end: 0)
                  else
                    Center(child: _PlantPlaceholder())
                        .animate()
                        .fadeIn(delay: 150.ms),

                  const SizedBox(height: 20),

                  // ── Species identity card ──────────────────────────────
                  if (pn != null) ...[
                    Center(
                      child: Column(
                        children: [
                          if (pn.scientificName != null)
                            Text(
                              pn.scientificName!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.slateBlue,
                              ),
                            ),
                          if (pn.commonName != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              pn.commonName!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ).animate().fadeIn(delay: 200.ms),

                    const SizedBox(height: 16),

                    // Confidence + Family row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (pn.score != null)
                          _PillTag(
                            icon: Icons.verified_rounded,
                            label: '${(pn.score! * 100).toInt()}% Match',
                            color: AppColors.forestGreen,
                          ),
                        if (pn.family != null) ...[
                          const SizedBox(width: 10),
                          _PillTag(
                            icon: Icons.category_rounded,
                            label: pn.family!,
                            color: AppColors.slateBlue,
                          ),
                        ],
                      ],
                    ).animate().fadeIn(delay: 250.ms),
                  ],

                  const SizedBox(height: 20),

                  // ── CO₂ impact card ────────────────────────────────────
                  _Co2Card(species: pn?.scientificName, co2: co2)
                      .animate()
                      .fadeIn(delay: 300.ms)
                      .slideY(begin: 0.06, end: 0),

                  const SizedBox(height: 24),

                  // ── Status message ─────────────────────────────────────
                  Center(
                    child: Text(
                      result.isNewTag ? '🌱 New Tree Added to Database!' : '✅ Existing Tree Verified!',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      result.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMedium, fontSize: 13),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── CTA button ─────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        onSaved?.call();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.add_location_alt_rounded, size: 20),
                      label: const Text('Save to My Collection & Geotag'),
                      style: ElevatedButton.styleFrom(
                        shape: const StadiumBorder(),
                        backgroundColor: AppColors.primaryBlue,
                        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 12),

                  // Total XP
                  Center(
                    child: Text(
                      'Total XP: ${result.totalPoints}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryBlue,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        );
      },
    );
  }

  double _estimateCo2(String? scientificName) {
    // Average annual CO₂ absorption per species
    const map = {
      'azadirachta indica': 21.77,
      'ficus religiosa': 28.0,
      'ficus benghalensis': 31.2,
      'mangifera indica': 19.5,
      'bambusa bambos': 62.0,
      'terminalia arjuna': 26.1,
      'syzygium cumini': 24.7,
      'cassia fistula': 16.8,
    };
    final key = scientificName?.toLowerCase() ?? '';
    return map[key] ?? 20.0;
  }
}

// ── Supporting Widgets ────────────────────────────────────────────────────────

class _PlantPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 160,
        width: 200,
        decoration: BoxDecoration(
          color: AppColors.forestGreen.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.forestGreen.withAlpha(40)),
        ),
        child: const Center(
          child: Icon(Icons.eco_rounded, color: AppColors.forestGreen, size: 64),
        ),
      );
}

class _PillTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _PillTag({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      );
}

class _Co2Card extends StatelessWidget {
  final String? species;
  final double co2;
  const _Co2Card({this.species, required this.co2});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.forestGreen.withAlpha(30), AppColors.sageGreen.withAlpha(15)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.forestGreen.withAlpha(50)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.forestGreen.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_done_rounded, color: AppColors.forestGreen, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Estimated CO₂ Offset',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.forestGreen,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '~${co2.toStringAsFixed(1)} kg / year',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                  Text(
                    'Over 20 years: ~${(co2 * 20).toStringAsFixed(0)} kg absorbed',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMedium),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
