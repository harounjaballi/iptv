import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../cache/app_cache_manager.dart';

/// Préchargement des images critiques (bannière héro, premières affiches
/// visibles) pour un affichage instantané, façon Netflix / Bob Player.
///
/// Règles :
/// - jamais plus de [maxConcurrent] téléchargements simultanés (on ne
///   sature pas la bande passante nécessaire au flux vidéo) ;
/// - erreurs silencieuses : un poster manquant ne doit rien casser ;
/// - déduplication : une URL déjà demandée n'est pas relancée.
class ImagePrefetcher {
  ImagePrefetcher._();

  static final Set<String> _requested = <String>{};
  static const int maxConcurrent = 4;

  /// Précharge [urls] (les vides / doublons sont ignorés) par petits lots.
  static Future<void> warm(
    BuildContext context,
    Iterable<String> urls, {
    int decodeWidth = 400,
  }) async {
    final pending = urls
        .where((u) => u.isNotEmpty && _requested.add(u))
        .toList(growable: false);

    for (var i = 0; i < pending.length; i += maxConcurrent) {
      if (!context.mounted) return;
      final batch = pending.skip(i).take(maxConcurrent).map(
            (url) => precacheImage(
              ResizeImage(
                CachedNetworkImageProvider(
                  url,
                  cacheManager: AppCacheManager.instance,
                ),
                width: decodeWidth,
              ),
              context,
              onError: (_, __) {}, // silencieux
            ),
          );
      await Future.wait(batch);
    }
  }

  /// À appeler au changement de compte pour autoriser un nouveau préchargement.
  static void reset() => _requested.clear();
}
