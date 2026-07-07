import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Gestionnaire de cache disque pour les images (posters, logos, bannières).
///
/// Contrairement au [DefaultCacheManager] (200 objets, 30 jours), celui-ci est
/// dimensionné pour un catalogue IPTV (milliers d'affiches) tout en gardant
/// une empreinte disque bornée :
/// - 1200 objets maximum (LRU : les moins utilisés sont évincés) ;
/// - péremption après 14 jours (les affiches changent rarement).
class AppCacheManager {
  AppCacheManager._();

  static const key = 'premiumIptvImageCache';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 1200,
    ),
  );

  /// Vide entièrement le cache disque des images (écran Cache des réglages).
  static Future<void> clear() => instance.emptyCache();
}
