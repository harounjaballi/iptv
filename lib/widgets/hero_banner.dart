import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/perf/perf_mode.dart';
import '../themes/app_colors.dart';
import 'gradient_button.dart';
import 'optimized_image.dart';

/// Bannière "héro" façon Netflix : image de fond, dégradé,
/// titre, métadonnées et boutons Lire / Détails.
class HeroBanner extends StatelessWidget {
  final String title;
  final String imageUrl;
  final String? metadata; // ex. "2024 • Action, Thriller • ★ 8.1"
  final VoidCallback onPlay;
  final VoidCallback onDetails;

  const HeroBanner({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.onPlay,
    required this.onDetails,
    this.metadata,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final banner = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: wide ? 320 : 220,
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageUrl.isEmpty
                  ? const DecoratedBox(
                      decoration:
                          BoxDecoration(gradient: AppColors.brandGradient))
                  : OptimizedImage(
                      url: imageUrl,
                      // La bannière occupe la largeur de l'écran : on décode
                      // plus grand qu'un poster, plafonné par OptimizedImage.
                      logicalWidth: MediaQuery.sizeOf(context).width,
                      errorWidget: const DecoratedBox(
                        decoration:
                            BoxDecoration(gradient: AppColors.brandGradient),
                      ),
                    ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                    stops: [0.35, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: wide ? 28 : 20,
                        fontWeight: FontWeight.w800,
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 8)
                        ],
                      ),
                    ),
                    if (metadata != null && metadata!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        metadata!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        GradientButton(
                          onPressed: onPlay,
                          icon: Icons.play_arrow_rounded,
                          label: 'Lire',
                          expanded: false,
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: onDetails,
                          icon: const Icon(Icons.info_outline, size: 18),
                          label: const Text('Détails'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // Fondu décoratif : ignoré sur TV / "réduire les animations"
    // (affichage immédiat, aucune frame d'animation superflue).
    if (!PerfMode.decorativeAnimations(context)) return banner;
    return banner.animate().fadeIn(duration: 350.ms);
  }
}
