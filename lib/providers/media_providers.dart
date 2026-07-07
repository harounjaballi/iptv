import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/series_details.dart';
import '../models/series_item.dart';
import '../models/vod_details.dart';
import '../models/vod_item.dart';
import '../models/watch_progress.dart';
import 'app_providers.dart';
import 'auth_provider.dart';
import 'parental_providers.dart';
import 'profile_providers.dart';

/// ================= Module Films & Séries =================
/// Même philosophie que le module Live : un seul chargement complet
/// mis en cache (Hive), puis filtrage / recherche / tri en mémoire
/// → navigation instantanée façon Netflix.

/// ---------------- Pseudo-catégories ----------------
const String mediaFavCategoryId = '__favorites__';
const String mediaHistoryCategoryId = '__history__';

/// ---------------- Tri ----------------
enum MediaSort {
  recent('Récemment ajoutés'),
  az('Nom A → Z'),
  za('Nom Z → A'),
  topRated('Mieux notés'),
  year('Année');

  final String label;
  const MediaSort(this.label);
}

/// ---------------- États UI ----------------
final vodSearchProvider = StateProvider<String>((ref) => '');
final vodSortProvider = StateProvider<MediaSort>((ref) => MediaSort.recent);
final selectedVodCategoryProvider = StateProvider<String?>((ref) => null);

final seriesSearchProvider = StateProvider<String>((ref) => '');
final seriesSortProvider =
    StateProvider<MediaSort>((ref) => MediaSort.recent);
final selectedSeriesCategoryProvider = StateProvider<String?>((ref) => null);

/// ---------------- Catalogues complets (cache Hive par compte) ----------------
final _allMoviesRawProvider =
    FutureProvider.autoDispose<List<VodItem>>((ref) async {
  final playlist = ref.watch(activePlaylistProvider);
  if (playlist != null) return playlist.movies;

  final creds = ref.watch(credentialsProvider);
  final account = ref.watch(activeAccountProvider);
  if (creds == null || account == null) return const [];

  final cache = ref.watch(cacheServiceProvider);
  final cacheKey = 'vod_all_${account.id}';

  final cached = cache.getJson(cacheKey);
  if (cached is String && cached.isNotEmpty) {
    try {
      final list = jsonDecode(cached) as List;
      final movies = list
          .whereType<Map>()
          .map((e) => VodItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (movies.isNotEmpty) return movies;
    } catch (_) {/* cache corrompu : refetch */}
  }

  final fresh = await ref.watch(contentRepositoryProvider).movies(creds);
  await cache.putJson(
      cacheKey, jsonEncode([for (final m in fresh) m.toJson()]));
  return fresh;
});

final _allSeriesRawProvider =
    FutureProvider.autoDispose<List<SeriesItem>>((ref) async {
  final playlist = ref.watch(activePlaylistProvider);
  if (playlist != null) return playlist.series;

  final creds = ref.watch(credentialsProvider);
  final account = ref.watch(activeAccountProvider);
  if (creds == null || account == null) return const [];

  final cache = ref.watch(cacheServiceProvider);
  final cacheKey = 'series_all_${account.id}';

  final cached = cache.getJson(cacheKey);
  if (cached is String && cached.isNotEmpty) {
    try {
      final list = jsonDecode(cached) as List;
      final series = list
          .whereType<Map>()
          .map((e) => SeriesItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (series.isNotEmpty) return series;
    } catch (_) {/* cache corrompu : refetch */}
  }

  final fresh = await ref.watch(contentRepositoryProvider).series(creds);
  await cache.putJson(
      cacheKey, jsonEncode([for (final s in fresh) s.toJson()]));
  return fresh;
});

/// Catalogues visibles : les catégories cachées (contrôle parental)
/// sont exclues partout — rangées, grilles, recherche, recommandations.
final allMoviesProvider =
    FutureProvider.autoDispose<List<VodItem>>((ref) async {
  final movies = await ref.watch(_allMoviesRawProvider.future);
  final hidden = ref.watch(hiddenCategoriesProvider('vod'));
  if (hidden.isEmpty) return movies;
  return movies.where((m) => !hidden.contains(m.categoryId)).toList();
});

final allSeriesProvider =
    FutureProvider.autoDispose<List<SeriesItem>>((ref) async {
  final series = await ref.watch(_allSeriesRawProvider.future);
  final hidden = ref.watch(hiddenCategoriesProvider('series'));
  if (hidden.isEmpty) return series;
  return series.where((s) => !hidden.contains(s.categoryId)).toList();
});

/// ---------------- Fiches détaillées ----------------
final vodDetailsProvider = FutureProvider.autoDispose
    .family<VodDetails, int>((ref, streamId) async {
  final playlist = ref.watch(activePlaylistProvider);
  if (playlist != null) return VodDetails.empty; // M3U : pas de fiche.
  final creds = ref.watch(credentialsProvider);
  if (creds == null) return VodDetails.empty;
  return ref.watch(contentRepositoryProvider).vodDetails(creds, streamId);
});

final seriesDetailsProvider = FutureProvider.autoDispose
    .family<SeriesDetails, int>((ref, seriesId) async {
  final playlist = ref.watch(activePlaylistProvider);
  if (playlist != null) {
    // M3U : fiche minimale construite depuis la playlist.
    return SeriesDetails(
        episodes: playlist.episodesBySeries[seriesId] ?? const []);
  }
  final creds = ref.watch(credentialsProvider);
  if (creds == null) return const SeriesDetails();
  return ref.watch(contentRepositoryProvider).seriesDetails(creds, seriesId);
});

/// ---------------- Favoris (persistés par compte) ----------------
class _MediaFavoritesNotifier extends Notifier<Set<int>> {
  final String kind; // 'vod' | 'series'
  _MediaFavoritesNotifier(this.kind);

  String get _prefix => 'fav_${kind}_${ref.read(dataScopeProvider)}_';

  @override
  Set<int> build() {
    ref.watch(dataScopeProvider); // recharge au changement compte/profil
    final cache = ref.watch(cacheServiceProvider);
    final prefix = _prefix;
    return {
      for (final key in cache.allFavorites())
        if (key.startsWith(prefix))
          int.tryParse(key.substring(prefix.length)) ?? -1
    }..remove(-1);
  }

  Future<void> toggle(int id) async {
    await ref.read(cacheServiceProvider).toggleFavorite('$_prefix$id');
    final updated = {...state};
    updated.contains(id) ? updated.remove(id) : updated.add(id);
    state = updated;
  }
}

final vodFavoritesProvider =
    NotifierProvider<_MediaFavoritesNotifier, Set<int>>(
        () => _MediaFavoritesNotifier('vod'));

final seriesFavoritesProvider =
    NotifierProvider<_MediaFavoritesNotifier, Set<int>>(
        () => _MediaFavoritesNotifier('series'));

/// ---------------- Progression de lecture (reprise + historique) ----------------
/// Map clé → WatchProgress, persistée par compte dans Hive.
/// Clés : WatchProgress.vodKey / WatchProgress.episodeKey.
class WatchProgressNotifier extends Notifier<Map<String, WatchProgress>> {
  static const _maxEntries = 200;

  String get _key => 'watch_progress_${ref.read(dataScopeProvider)}';

  @override
  Map<String, WatchProgress> build() {
    ref.watch(dataScopeProvider);
    final raw = ref.watch(cacheServiceProvider).getSetting(_key);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final map = jsonDecode(raw) as Map;
      return {
        for (final e in map.entries)
          if (e.value is Map)
            e.key.toString(): WatchProgress.fromJson(
                Map<String, dynamic>.from(e.value as Map)),
      };
    } catch (_) {
      return const {};
    }
  }

  Future<void> _persist(Map<String, WatchProgress> map) async {
    // Limite la taille : on garde les entrées les plus récentes.
    var entries = map.entries.toList()
      ..sort((a, b) => b.value.updatedAt.compareTo(a.value.updatedAt));
    if (entries.length > _maxEntries) {
      entries = entries.sublist(0, _maxEntries);
    }
    final trimmed = {for (final e in entries) e.key: e.value};
    state = trimmed;
    await ref
        .read(cacheServiceProvider)
        .putSetting(_key, jsonEncode(
            {for (final e in trimmed.entries) e.key: e.value.toJson()}));
  }

  /// Enregistre la position courante (appelé périodiquement par le lecteur).
  Future<void> save(String key, Duration position, Duration duration) async {
    if (duration.inSeconds < 30) return; // contenu trop court / inconnu
    await _persist({
      ...state,
      key: WatchProgress(
        positionMs: position.inMilliseconds,
        durationMs: duration.inMilliseconds,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    });
  }

  /// Marque un contenu comme terminé (fin de lecture).
  Future<void> markCompleted(String key) async {
    final current = state[key];
    final dur = current?.durationMs ?? 1;
    await _persist({
      ...state,
      key: WatchProgress(
        positionMs: dur,
        durationMs: dur,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    });
  }

  Future<void> remove(String key) async {
    final updated = {...state}..remove(key);
    await _persist(updated);
  }
}

final watchProgressProvider =
    NotifierProvider<WatchProgressNotifier, Map<String, WatchProgress>>(
        WatchProgressNotifier.new);

/// ---------------- Dernier épisode vu par série (reprise) ----------------
class SeriesLastEpisodeNotifier extends Notifier<Map<int, int>> {
  String get _key => 'series_last_ep_${ref.read(dataScopeProvider)}';

  @override
  Map<int, int> build() {
    ref.watch(dataScopeProvider);
    final raw = ref.watch(cacheServiceProvider).getSetting(_key);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final map = jsonDecode(raw) as Map;
      return {
        for (final e in map.entries)
          int.tryParse(e.key.toString()) ?? -1:
              int.tryParse(e.value.toString()) ?? -1,
      }..removeWhere((k, v) => k < 0 || v < 0);
    } catch (_) {
      return const {};
    }
  }

  Future<void> register(int seriesId, int episodeId) async {
    final updated = {...state, seriesId: episodeId};
    state = updated;
    await ref.read(cacheServiceProvider).putSetting(
        _key,
        jsonEncode(
            {for (final e in updated.entries) e.key.toString(): e.value}));
  }
}

final seriesLastEpisodeProvider =
    NotifierProvider<SeriesLastEpisodeNotifier, Map<int, int>>(
        SeriesLastEpisodeNotifier.new);

/// ---------------- Historique de visionnage des séries ----------------
/// Liste ordonnée des séries regardées (la plus récente en tête).
class SeriesHistoryNotifier extends Notifier<List<int>> {
  static const _max = 60;

  String get _key => 'series_history_${ref.read(dataScopeProvider)}';

  @override
  List<int> build() {
    ref.watch(dataScopeProvider);
    final raw = ref.watch(cacheServiceProvider).getSetting(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => int.tryParse(e.toString()) ?? -1)
          .where((id) => id > 0)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> registerWatch(int seriesId) async {
    final updated = [seriesId, ...state.where((id) => id != seriesId)];
    if (updated.length > _max) updated.removeRange(_max, updated.length);
    state = updated;
    await ref
        .read(cacheServiceProvider)
        .putSetting(_key, jsonEncode(updated));
  }
}

final seriesHistoryProvider =
    NotifierProvider<SeriesHistoryNotifier, List<int>>(
        SeriesHistoryNotifier.new);

/// ---------------- Historique / Reprise — Films ----------------
/// Films entamés (2 %–95 %), du plus récent au plus ancien → "Continuer".
final continueWatchingMoviesProvider =
    Provider.autoDispose<List<VodItem>>((ref) {
  final movies = ref.watch(allMoviesProvider).valueOrNull;
  if (movies == null) return const [];
  final progress = ref.watch(watchProgressProvider);
  final byId = {for (final m in movies) m.streamId: m};

  final entries = progress.entries
      .where((e) => e.key.startsWith('vod_') && e.value.inProgress)
      .toList()
    ..sort((a, b) => b.value.updatedAt.compareTo(a.value.updatedAt));

  return [
    for (final e in entries)
      if (byId[int.tryParse(e.key.substring(4)) ?? -1] != null)
        byId[int.tryParse(e.key.substring(4))]!,
  ];
});

/// Historique complet des films (tout ce qui a une progression).
final vodHistoryProvider = Provider.autoDispose<List<VodItem>>((ref) {
  final movies = ref.watch(allMoviesProvider).valueOrNull;
  if (movies == null) return const [];
  final progress = ref.watch(watchProgressProvider);
  final byId = {for (final m in movies) m.streamId: m};

  final entries = progress.entries
      .where((e) => e.key.startsWith('vod_'))
      .toList()
    ..sort((a, b) => b.value.updatedAt.compareTo(a.value.updatedAt));

  return [
    for (final e in entries)
      if (byId[int.tryParse(e.key.substring(4)) ?? -1] != null)
        byId[int.tryParse(e.key.substring(4))]!,
  ];
});

/// Séries en cours (au moins un épisode entamé), les plus récentes en tête.
final continueWatchingSeriesProvider =
    Provider.autoDispose<List<SeriesItem>>((ref) {
  final series = ref.watch(allSeriesProvider).valueOrNull;
  if (series == null) return const [];
  final history = ref.watch(seriesHistoryProvider);
  final byId = {for (final s in series) s.seriesId: s};
  return [
    for (final id in history)
      if (byId[id] != null) byId[id]!,
  ];
});

/// ---------------- Filtrage (catégorie + recherche + tri) ----------------
List<T> _applySort<T>(
  List<T> list,
  MediaSort sort, {
  required String Function(T) name,
  required double Function(T) rating,
  required int Function(T) added,
  required String Function(T) year,
}) {
  final result = [...list];
  switch (sort) {
    case MediaSort.recent:
      result.sort((a, b) => added(b).compareTo(added(a)));
    case MediaSort.az:
      result.sort(
          (a, b) => name(a).toLowerCase().compareTo(name(b).toLowerCase()));
    case MediaSort.za:
      result.sort(
          (a, b) => name(b).toLowerCase().compareTo(name(a).toLowerCase()));
    case MediaSort.topRated:
      result.sort((a, b) => rating(b).compareTo(rating(a)));
    case MediaSort.year:
      result.sort((a, b) => year(b).compareTo(year(a)));
  }
  return result;
}

final filteredMoviesProvider =
    Provider.autoDispose<AsyncValue<List<VodItem>>>((ref) {
  final moviesAsync = ref.watch(allMoviesProvider);
  final categoryId = ref.watch(selectedVodCategoryProvider);
  final query = ref.watch(vodSearchProvider).trim().toLowerCase();
  final sort = ref.watch(vodSortProvider);
  final favorites = ref.watch(vodFavoritesProvider);
  final history = ref.watch(vodHistoryProvider);

  return moviesAsync.whenData((all) {
    // Historique : ordre chronologique conservé.
    if (categoryId == mediaHistoryCategoryId) {
      return query.isEmpty
          ? history
          : history
              .where((m) => m.name.toLowerCase().contains(query))
              .toList();
    }

    Iterable<VodItem> list = all;
    if (categoryId == mediaFavCategoryId) {
      list = list.where((m) => favorites.contains(m.streamId));
    } else if (categoryId != null) {
      list = list.where((m) => m.categoryId == categoryId);
    }
    if (query.isNotEmpty) {
      list = list.where((m) => m.name.toLowerCase().contains(query));
    }
    return _applySort(
      list.toList(),
      sort,
      name: (m) => m.name,
      rating: (m) => m.ratingValue,
      added: (m) => m.added,
      year: (m) => m.year,
    );
  });
});

final filteredSeriesProvider =
    Provider.autoDispose<AsyncValue<List<SeriesItem>>>((ref) {
  final seriesAsync = ref.watch(allSeriesProvider);
  final categoryId = ref.watch(selectedSeriesCategoryProvider);
  final query = ref.watch(seriesSearchProvider).trim().toLowerCase();
  final sort = ref.watch(seriesSortProvider);
  final favorites = ref.watch(seriesFavoritesProvider);
  final history = ref.watch(continueWatchingSeriesProvider);

  return seriesAsync.whenData((all) {
    if (categoryId == mediaHistoryCategoryId) {
      return query.isEmpty
          ? history
          : history
              .where((s) => s.name.toLowerCase().contains(query))
              .toList();
    }

    Iterable<SeriesItem> list = all;
    if (categoryId == mediaFavCategoryId) {
      list = list.where((s) => favorites.contains(s.seriesId));
    } else if (categoryId != null) {
      list = list.where((s) => s.categoryId == categoryId);
    }
    if (query.isNotEmpty) {
      list = list.where((s) => s.name.toLowerCase().contains(query));
    }
    return _applySort(
      list.toList(),
      sort,
      name: (s) => s.name,
      rating: (s) => s.ratingValue,
      added: (s) => s.lastModified,
      year: (s) => s.year,
    );
  });
});

/// ---------------- Recommandations ----------------
/// Score simple : même catégorie + genres communs + note,
/// en excluant l'élément source et les contenus déjà vus.
Set<String> _genreTokens(String genre) => genre
    .toLowerCase()
    .split(RegExp(r'[,/|]'))
    .map((g) => g.trim())
    .where((g) => g.isNotEmpty)
    .toSet();

final movieRecommendationsProvider = Provider.autoDispose
    .family<List<VodItem>, VodItem>((ref, seed) {
  final movies = ref.watch(allMoviesProvider).valueOrNull;
  if (movies == null) return const [];
  final progress = ref.watch(watchProgressProvider);
  final seedGenres = _genreTokens(seed.genre);

  final scored = <(double, VodItem)>[];
  for (final m in movies) {
    if (m.streamId == seed.streamId) continue;
    if (progress[WatchProgress.vodKey(m.streamId)]?.completed ?? false) {
      continue;
    }
    var score = 0.0;
    if (m.categoryId == seed.categoryId) score += 2;
    if (seedGenres.isNotEmpty) {
      score += _genreTokens(m.genre).intersection(seedGenres).length;
    }
    if (score <= 0) continue;
    score += m.ratingValue / 10; // départage par la note
    scored.add((score, m));
  }
  scored.sort((a, b) => b.$1.compareTo(a.$1));
  return [for (final s in scored.take(12)) s.$2];
});

final seriesRecommendationsProvider = Provider.autoDispose
    .family<List<SeriesItem>, SeriesItem>((ref, seed) {
  final series = ref.watch(allSeriesProvider).valueOrNull;
  if (series == null) return const [];
  final seedGenres = _genreTokens(seed.genre);

  final scored = <(double, SeriesItem)>[];
  for (final s in series) {
    if (s.seriesId == seed.seriesId) continue;
    var score = 0.0;
    if (s.categoryId == seed.categoryId) score += 2;
    if (seedGenres.isNotEmpty) {
      score += _genreTokens(s.genre).intersection(seedGenres).length;
    }
    if (score <= 0) continue;
    score += s.ratingValue / 10;
    scored.add((score, s));
  }
  scored.sort((a, b) => b.$1.compareTo(a.$1));
  return [for (final s in scored.take(12)) s.$2];
});

/// Recommandations pour l'accueil : mieux notés non vus (films).
final topRatedMoviesProvider = Provider.autoDispose<List<VodItem>>((ref) {
  final movies = ref.watch(allMoviesProvider).valueOrNull;
  if (movies == null) return const [];
  final sorted = [...movies]
    ..sort((a, b) => b.ratingValue.compareTo(a.ratingValue));
  return sorted.take(20).toList();
});

final topRatedSeriesProvider = Provider.autoDispose<List<SeriesItem>>((ref) {
  final series = ref.watch(allSeriesProvider).valueOrNull;
  if (series == null) return const [];
  final sorted = [...series]
    ..sort((a, b) => b.ratingValue.compareTo(a.ratingValue));
  return sorted.take(20).toList();
});

/// Récemment ajoutés (films / séries).
final recentMoviesProvider = Provider.autoDispose<List<VodItem>>((ref) {
  final movies = ref.watch(allMoviesProvider).valueOrNull;
  if (movies == null) return const [];
  final sorted = [...movies]..sort((a, b) => b.added.compareTo(a.added));
  return sorted.take(20).toList();
});

final recentSeriesProvider = Provider.autoDispose<List<SeriesItem>>((ref) {
  final series = ref.watch(allSeriesProvider).valueOrNull;
  if (series == null) return const [];
  final sorted = [...series]
    ..sort((a, b) => b.lastModified.compareTo(a.lastModified));
  return sorted.take(20).toList();
});

/// Films regroupés par catégorie — **mémoïsé** : le regroupement O(N) n'est
/// exécuté qu'une fois par (re)chargement du catalogue, au lieu d'un
/// `where()` complet par rangée de l'accueil à chaque rebuild (10 rangées ×
/// 20 000 films = 200 000 itérations économisées par frame).
final moviesByCategoryProvider =
    Provider.autoDispose<Map<String, List<VodItem>>>((ref) {
  final movies = ref.watch(allMoviesProvider).valueOrNull ?? const <VodItem>[];
  final map = <String, List<VodItem>>{};
  for (final m in movies) {
    (map[m.categoryId] ??= []).add(m);
  }
  return map;
});

/// Séries regroupées par catégorie (même principe que les films).
final seriesByCategoryProvider =
    Provider.autoDispose<Map<String, List<SeriesItem>>>((ref) {
  final series =
      ref.watch(allSeriesProvider).valueOrNull ?? const <SeriesItem>[];
  final map = <String, List<SeriesItem>>{};
  for (final s in series) {
    (map[s.categoryId] ??= []).add(s);
  }
  return map;
});
