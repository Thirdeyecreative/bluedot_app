import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Small rounded tag used across scan result/detail sheets (match %, family,
/// pending-review, etc.).
class PillTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const PillTag({super.key, required this.icon, required this.label, required this.color});

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

class Co2Card extends StatelessWidget {
  final String? species;
  final double co2;
  const Co2Card({super.key, this.species, required this.co2});

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

class PlantPlaceholder extends StatelessWidget {
  const PlantPlaceholder({super.key});

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
