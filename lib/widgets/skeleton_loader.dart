import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Bloc skeleton unitaire (coins arrondis).
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius,
      ),
    );
  }
}

/// Skeleton complet d'une page catalogue :
/// rangée de chips + grille de cartes, avec effet shimmer.
class SkeletonGrid extends StatelessWidget {
  final int columns;
  final double aspectRatio;
  final bool withChips;

  const SkeletonGrid({
    super.key,
    required this.columns,
    this.aspectRatio = 2 / 3,
    this.withChips = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF23233A) : Colors.grey.shade300,
      highlightColor:
          isDark ? const Color(0xFF35355A) : Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (withChips)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, __) =>
                    const SkeletonBox(width: 88, height: 36),
              ),
            ),
          if (withChips) const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: aspectRatio,
              ),
              itemCount: columns * 4,
              itemBuilder: (_, __) => const SkeletonBox(
                borderRadius: BorderRadius.all(Radius.circular(18)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
