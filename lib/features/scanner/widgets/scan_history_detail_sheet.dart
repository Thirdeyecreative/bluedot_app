import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/skeletons.dart';
import '../models/scan_result_model.dart';
import 'scan_shared_widgets.dart';

/// Read-only detail view for a past scan, opened from the Profile page's
/// Recent Scans list. Shows the same identity/CO2 info as the live scan
/// result, plus whether the species is still pending admin review.
class ScanHistoryDetailSheet extends StatelessWidget {
  final ScanHistoryItem item;
  const ScanHistoryDetailSheet({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final pn = item.plantnetData;
    final species = item.species;
    final displayScientificName = species?.scientificName ?? pn?.scientificName;
    final displayCommonName = species?.localName ?? pn?.commonName;
    final co2 = species?.co2OffsetFactor;
    final imageUrl = item.imageUrl ?? (item.imageUrls.isNotEmpty ? item.imageUrls.first : null);

    // Sized to fit its content rather than forced open to a fixed fraction
    // of the screen -- a DraggableScrollableSheet's minChildSize would leave
    // empty space below short content, which looks unfinished.
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.backgroundCream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 16, 24, 32 + MediaQuery.of(context).viewPadding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.borderMedium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              if (imageUrl != null)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 180,
                      width: 220,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const AppSkeleton(child: Bone(height: 180, width: 220)),
                      errorWidget: (_, _, _) => const PlantPlaceholder(),
                    ),
                  ),
                ).animate().fadeIn().slideY(begin: 0.1, end: 0)
              else
                const Center(child: PlantPlaceholder()).animate().fadeIn(),

              const SizedBox(height: 20),

              if (displayScientificName != null || displayCommonName != null) ...[
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
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: AppColors.textDark),
                        ),
                      ],
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 16),
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
                      PillTag(icon: Icons.category_rounded, label: pn!.family!, color: AppColors.slateBlue),
                    // The approval status you asked to surface here: whether
                    // this species is still awaiting admin review, or already
                    // live in the Tree Encyclopedia.
                    PillTag(
                      icon: species?.isPendingReview == true ? Icons.hourglass_top_rounded : Icons.check_circle_rounded,
                      label: species?.isPendingReview == true ? 'Pending review' : 'Approved',
                      color: species?.isPendingReview == true ? AppColors.warningAmber : AppColors.forestGreen,
                    ),
                  ],
                ).animate().fadeIn(delay: 150.ms),
              ],

              const SizedBox(height: 20),

              if (co2 != null && co2 > 0)
                Co2Card(species: displayScientificName, co2: co2).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 24),

              Center(
                child: Text(
                  item.taggedAt != null ? 'Tagged on ${_formatDate(item.taggedAt!)}' : 'Tagged',
                  style: const TextStyle(color: AppColors.textMedium, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) return iso;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
