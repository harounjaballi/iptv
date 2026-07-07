import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/perf/perf_mode.dart';
import '../themes/app_colors.dart';

/// Fond premium : dégradé profond + orbes lumineux flous.
///
/// Performance :
/// - chaque orbe est isolé dans un [RepaintBoundary] : son animation ne
///   force jamais le repaint du contenu par-dessus ;
/// - sur Android TV / Fire TV (ou si le système demande de réduire les
///   animations), les orbes sont **statiques** : zéro repaint permanent,
///   le GPU reste disponible pour le décodage vidéo.
class PremiumBackground extends StatelessWidget {
  final Widget child;

  const PremiumBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final animated = PerfMode.decorativeAnimations(context);
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
          ),
        ),
        Positioned(
          top: -size.height * 0.15,
          left: -size.width * 0.2,
          child: _Orb(
            color: AppColors.seed,
            size: size.width * 0.7,
            animated: animated,
          ),
        ),
        Positioned(
          bottom: -size.height * 0.2,
          right: -size.width * 0.25,
          child: _Orb(
            color: AppColors.accent,
            size: size.width * 0.8,
            delay: 1200,
            animated: animated,
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  final int delay;
  final bool animated;

  const _Orb({
    required this.color,
    required this.size,
    required this.animated,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    final orb = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.32),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );

    // Mode économie (TV / accessibilité) : orbe statique, aucun repaint.
    if (!animated) return orb;

    return RepaintBoundary(
      child: orb
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.18, 1.18),
            duration: 5.seconds,
            delay: delay.ms,
            curve: Curves.easeInOut,
          )
          .fade(begin: 0.7, end: 1.0, duration: 5.seconds),
    );
  }
}
