import 'package:flutter/material.dart';

import 'focusable_card.dart';
import 'optimized_image.dart';

/// Affiche (film / série) avec image mise en cache, titre, note,
/// badge favori et barre de progression de lecture (optionnels).
class PosterCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final String? rating;
  final VoidCallback onTap;

  /// Progression de lecture 0..1 (barre rouge façon Netflix).
  final double? progress;

  /// Affiche un cœur en haut à gauche.
  final bool isFavorite;

  /// Année affichée sous le titre (optionnel).
  final String? subtitle;

  /// Largeur logique d'affichage (dp) : sert au décodage redimensionné
  /// de l'image (compression mémoire). 130 couvre les grilles standard.
  final double displayWidth;

  const PosterCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.onTap,
    this.rating,
    this.progress,
    this.isFavorite = false,
    this.subtitle,
    this.displayWidth = 130,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FocusableCard(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          imageUrl.isEmpty
              ? ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: const Icon(Icons.movie_outlined, size: 40),
                )
              : OptimizedImage(
                  url: imageUrl,
                  logicalWidth: displayWidth,
                  errorWidget: ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
          // Dégradé + titre
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 10),
                    ),
                ],
              ),
            ),
          ),
          if (rating != null && rating != '—')
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 12),
                    const SizedBox(width: 2),
                    Text(rating!,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11)),
                  ],
                ),
              ),
            ),
          if (isFavorite)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite,
                    color: Colors.redAccent, size: 13),
              ),
            ),
          // Barre de progression de lecture
          if (progress != null && progress! > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                height: 4,
                child: LinearProgressIndicator(
                  value: progress!.clamp(0.0, 1.0),
                  backgroundColor: Colors.white24,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFFE50914)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
