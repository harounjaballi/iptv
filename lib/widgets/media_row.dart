import 'package:flutter/material.dart';

/// Rangée horizontale de posters façon Netflix :
/// titre de section + liste défilante + bouton "Voir tout" optionnel.
class MediaRow extends StatelessWidget {
  final String title;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final VoidCallback? onSeeAll;
  final double posterWidth;
  final double posterHeight;

  const MediaRow({
    super.key,
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
    this.onSeeAll,
    this.posterWidth = 122,
    this.posterHeight = 183, // ratio 2/3
  });

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  child: const Text('Voir tout'),
                ),
            ],
          ),
        ),
        SizedBox(
          height: posterHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            // Pré-construit ~3 posters hors écran de chaque côté : le
            // défilement horizontal reste fluide sans décoder toute la rangée.
            cacheExtent: posterWidth * 3,
            itemCount: itemCount,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => RepaintBoundary(
              child: SizedBox(
                width: posterWidth,
                child: itemBuilder(context, i),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
