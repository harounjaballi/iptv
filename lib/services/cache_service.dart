import 'package:hive_flutter/hive_flutter.dart';
import '../core/constants/app_constants.dart';

/// Cache local (Hive) : listes JSON avec TTL + favoris + préférences.
class CacheService {
  late final Box _cache;
  late final Box _settings;
  late final Box _favorites;

  Future<void> init() async {
    await Hive.initFlutter();
    _cache = await _openSafe(AppConstants.boxCache);
    _settings = await _openSafe(AppConstants.boxSettings);
    _favorites = await _openSafe(AppConstants.boxFavorites);
  }

  /// Ouvre une boîte Hive en survivant à la corruption (coupure de courant
  /// sur box TV, stockage plein...) : si l'ouverture échoue, la boîte est
  /// supprimée puis recréée vide au lieu de bloquer le démarrage.
  ///
  /// Le compactage automatique (dès 50 entrées mortes) évite que le fichier
  /// ne gonfle indéfiniment avec les réécritures de catalogues.
  Future<Box> _openSafe(String name) async {
    Future<Box> open() => Hive.openBox(
          name,
          compactionStrategy: (entries, deleted) => deleted > 50,
        );
    try {
      return await open();
    } catch (_) {
      await Hive.deleteBoxFromDisk(name);
      return open();
    }
  }

  /// Compacte les boîtes (récupère l'espace disque des entrées supprimées).
  Future<void> compact() async {
    await _cache.compact();
    await _settings.compact();
    await _favorites.compact();
  }

  // ---------- Cache JSON avec TTL ----------
  Future<void> putJson(String key, dynamic json) async {
    await _cache.put(key, json);
    await _cache.put('${key}_ts', DateTime.now().millisecondsSinceEpoch);
  }

  dynamic getJson(String key) {
    final ts = _cache.get('${key}_ts');
    if (ts is int) {
      final age = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(ts));
      if (age > AppConstants.cacheTtl) return null;
    }
    return _cache.get(key);
  }

  Future<void> clearCache() => _cache.clear();

  // ---------- Playlists M3U brutes (par compte, sans TTL : sert de repli hors ligne) ----------
  Future<void> putM3uRaw(String accountId, String content) =>
      _cache.put('${AppConstants.cacheM3uRawPrefix}$accountId', content);

  String? getM3uRaw(String accountId) =>
      _cache.get('${AppConstants.cacheM3uRawPrefix}$accountId') as String?;

  Future<void> deleteM3uRaw(String accountId) =>
      _cache.delete('${AppConstants.cacheM3uRawPrefix}$accountId');

  // ---------- Préférences ----------
  String? getThemeMode() =>
      _settings.get(AppConstants.prefThemeMode) as String?;

  Future<void> setThemeMode(String mode) =>
      _settings.put(AppConstants.prefThemeMode, mode);

  // ---------- Réglages génériques (récents, reprise de lecture, ...) ----------
  String? getSetting(String key) => _settings.get(key) as String?;

  Future<void> putSetting(String key, String value) =>
      _settings.put(key, value);

  Future<void> deleteSetting(String key) => _settings.delete(key);

  // ---------- Favoris (clé = "live_123" / "vod_45" / "series_9") ----------
  bool isFavorite(String key) => _favorites.containsKey(key);

  Future<void> toggleFavorite(String key) async {
    if (_favorites.containsKey(key)) {
      await _favorites.delete(key);
    } else {
      await _favorites.put(key, true);
    }
  }

  List<String> allFavorites() =>
      _favorites.keys.map((k) => k.toString()).toList();

  Future<void> addFavoriteRaw(String key) => _favorites.put(key, true);

  // ---------- Sauvegarde / restauration / synchronisation ----------

  /// Toutes les préférences (réglages, favoris, progression, profils...).
  Map<String, String> dumpSettings() => {
        for (final k in _settings.keys)
          if (_settings.get(k) is String) k.toString(): _settings.get(k) as String,
      };

  /// Restaure des préférences (écrase les clés fournies).
  Future<void> restoreSettings(Map<String, String> settings) async {
    for (final e in settings.entries) {
      await _settings.put(e.key, e.value);
    }
  }

  /// Restaure des favoris (union avec l'existant).
  Future<void> restoreFavorites(Iterable<String> keys) async {
    for (final k in keys) {
      await _favorites.put(k, true);
    }
  }

  /// Tailles approximatives (nombre d'entrées) pour l'écran Cache.
  int get cacheEntryCount => _cache.length;
  int get settingsEntryCount => _settings.length;
  int get favoritesEntryCount => _favorites.length;

  /// Supprime uniquement les catalogues en cache (chaînes / films / séries).
  Future<void> clearCatalogCache() async {
    final keys = _cache.keys
        .map((k) => k.toString())
        .where((k) =>
            k.startsWith('live_all_') ||
            k.startsWith('vod_all_') ||
            k.startsWith('series_all_'))
        .toList();
    for (final k in keys) {
      await _cache.delete(k);
      await _cache.delete('${k}_ts');
    }
  }
}
