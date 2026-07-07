import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/cache/app_cache_manager.dart';

/// Image réseau optimisée pour listes et grilles :
///
/// - **Compression mémoire** : l'image est décodée à la taille d'affichage
///   réelle (`memCacheWidth`) et non à sa taille d'origine. Un poster 2000px
///   affiché en 122px consomme ainsi ~25× moins de RAM.
/// - **Compression disque** : `maxWidthDiskCache` limite la version stockée.
/// - **Cache borné** : utilise [AppCacheManager] (LRU 1200 objets / 14 jours).
/// - **Fade-in court** : transition douce sans jank, désactivable.
class OptimizedImage extends StatelessWidget {
  final String url;

  /// Largeur logique d'affichage prévue (dp). Sert à calculer la taille de
  /// décodage : `logicalWidth × devicePixelRatio` (plafonné).
  final double logicalWidth;

  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration fadeDuration;

  const OptimizedImage({
    super.key,
    required this.url,
    required this.logicalWidth,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.fadeDuration = const Duration(milliseconds: 180),
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return errorWidget ?? const ColoredBox(color: Colors.black26);
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // Taille de décodage : jamais plus grand que nécessaire, plafonnée à
    // 1080px pour les très grands écrans (TV 4K : inutile au-delà pour un
    // poster, et le GPU upscale très bien).
    final decodeWidth = (logicalWidth * dpr).round().clamp(64, 1080);

    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: AppCacheManager.instance,
      fit: fit,
      memCacheWidth: decodeWidth,
      maxWidthDiskCache: decodeWidth,
      fadeInDuration: fadeDuration,
      fadeOutDuration: Duration.zero,
      placeholder: placeholder != null ? (_, __) => placeholder! : null,
      errorWidget: (_, __, ___) =>
          errorWidget ?? const ColoredBox(color: Colors.black26),
    );
  }
}
