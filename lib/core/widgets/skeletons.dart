import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../constants/app_colors.dart';

export 'package:skeletonizer/skeletonizer.dart' show Bone, Skeletonizer;

/// App-wide skeleton loading primitives.
///
/// Every page that loads async data shows one of these (shaped like the
/// real content) instead of a bare spinner, so loading feels faster.
/// Spinners are reserved for in-button action feedback only.
class AppSkeleton extends StatelessWidget {
  final Widget child;
  const AppSkeleton({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer.zone(
      effect: ShimmerEffect(
        baseColor: AppColors.borderLight,
        highlightColor: Colors.white,
      ),
      child: child,
    );
  }
}

/// Vertical list of rounded card placeholders (feeds, event lists, blogs).
class SkeletonCardList extends StatelessWidget {
  final int count;
  final double height;
  final EdgeInsetsGeometry padding;

  const SkeletonCardList({
    super.key,
    this.count = 4,
    this.height = 110,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: Padding(
        padding: padding,
        child: Column(
          children: [
            for (int i = 0; i < count; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == count - 1 ? 0 : 12),
                child: Bone(
                  width: double.infinity,
                  height: height,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal strip of card placeholders (campaign carousels).
class SkeletonRowCards extends StatelessWidget {
  final int count;
  final double height;
  final double width;

  const SkeletonRowCards({
    super.key,
    this.count = 3,
    this.height = 140,
    this.width = 260,
  });

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: SizedBox(
        height: height,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, _) => Bone(
            width: width,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

/// Grid of square-ish card placeholders (directory, badges).
class SkeletonGrid extends StatelessWidget {
  final int count;
  final int crossAxisCount;
  final double childAspectRatio;
  final EdgeInsetsGeometry padding;

  const SkeletonGrid({
    super.key,
    this.count = 6,
    this.crossAxisCount = 2,
    this.childAspectRatio = 0.8,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: GridView.count(
        padding: padding,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        children: [
          for (int i = 0; i < count; i++)
            Bone(borderRadius: BorderRadius.circular(16)),
        ],
      ),
    );
  }
}

/// Detail-page placeholder: hero image block + heading + body lines
/// (blog detail, species detail, event detail).
class SkeletonDetailPage extends StatelessWidget {
  final double heroHeight;

  const SkeletonDetailPage({super.key, this.heroHeight = 240});

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Bone(width: double.infinity, height: heroHeight),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Bone(width: 220, height: 24, borderRadius: BorderRadius.circular(6)),
                  const SizedBox(height: 12),
                  Bone(width: 140, height: 14, borderRadius: BorderRadius.circular(6)),
                  const SizedBox(height: 24),
                  for (int i = 0; i < 6; i++) ...[
                    Bone(
                      width: i == 5 ? 180 : double.infinity,
                      height: 14,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
