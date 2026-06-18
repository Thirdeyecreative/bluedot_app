import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/skeletons.dart';
import '../models/scan_result_model.dart';
import 'scan_shared_widgets.dart';

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
    if (result.isNotIdentified) return _buildNotIdentified(context);

    final pn = result.plantnetData;
    final species = result.species;
    // Prefer the real Tree Encyclopedia record (DB-backed) over the raw AI
    // guess wherever both are available.
    final displayScientificName = species?.scientificName ?? pn?.scientificName;
    final displayCommonName = species?.localName ?? pn?.commonName;
    final co2 = (species?.co2OffsetFactor != null && species!.co2OffsetFactor! > 0)
        ? species.co2OffsetFactor!
        : _estimateCo2(pn?.scientificName);

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
                          errorWidget: (_, _, _) => PlantPlaceholder(),
                        ),
                      ),
                    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1, end: 0)
                  else
                    Center(child: PlantPlaceholder())
                        .animate()
                        .fadeIn(delay: 150.ms),

                  const SizedBox(height: 20),

                  // ── Species identity card ──────────────────────────────
                  if (pn != null || species != null) ...[
                    Center(
                      child: Column(
                        children: [
                          if (displayScientificName != null)
                            Text(
                              displayScientificName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.slateBlue,
                              ),
                            ),
                          if (displayCommonName != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              displayCommonName,
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

                    // Confidence + Family + pending-review row
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        if (pn?.score != null)
                          PillTag(
                            icon: Icons.verified_rounded,
                            label: '${(pn!.score! * 100).toInt()}% Match',
                            color: AppColors.forestGreen,
                          ),
                        if (pn?.family != null)
                          PillTag(
                            icon: Icons.category_rounded,
                            label: pn!.family!,
                            color: AppColors.slateBlue,
                          ),
                        if (species?.isPendingReview == true)
                          PillTag(
                            icon: Icons.hourglass_top_rounded,
                            label: 'New species — pending review',
                            color: AppColors.warningAmber,
                          ),
                      ],
                    ).animate().fadeIn(delay: 250.ms),
                  ],

                  const SizedBox(height: 20),

                  // ── CO₂ impact card ────────────────────────────────────
                  Co2Card(species: displayScientificName, co2: co2)
                      .animate()
                      .fadeIn(delay: 300.ms)
                      .slideY(begin: 0.06, end: 0),

                  const SizedBox(height: 24),

                  // ── Status message ─────────────────────────────────────
                  Center(
                    child: Text(
                      result.isNewTag
                          ? '📍 New Tree Pinned on the Map!'
                          : '✅ Already Mapped Nearby — No New Pin Added',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      result.isNewTag
                          ? result.message
                          : '${result.message} This tree was tagged here before, so we verified your visit instead of creating a duplicate map pin.',
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

  /// Simplified sheet for a failed/low-confidence identification -- no
  /// points, no species card, no save/geotag CTA, just a clear retry path.
  Widget _buildNotIdentified(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.42,
      minChildSize: 0.32,
      maxChildSize: 0.6,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.backgroundCream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(24, 16, 24, 32 + MediaQuery.of(context).viewPadding.bottom),
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AppColors.borderMedium,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.slateBlue.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.search_off_rounded, color: AppColors.slateBlue, size: 36),
              ),
            ).animate().scaleXY(begin: 0.6, end: 1, curve: Curves.easeOutBack, duration: 500.ms),
            const SizedBox(height: 18),
            Text(
              "We couldn't identify this plant",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              result.message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMedium, fontSize: 13),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.camera_alt_rounded, size: 18),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  shape: const StadiumBorder(),
                  backgroundColor: AppColors.primaryBlue,
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
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
