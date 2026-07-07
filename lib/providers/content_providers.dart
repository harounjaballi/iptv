import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category_model.dart';
import '../models/episode_item.dart';
import '../models/live_channel.dart';
import '../models/series_item.dart';
import '../models/vod_item.dart';
import 'app_providers.dart';
import 'auth_provider.dart';
import 'parental_providers.dart';

/// Les providers de contenu servent automatiquement la bonne source :
/// - comptes Xtream (ou MAC→Xtream) : API player_api.php + cache Hive ;
/// - comptes M3U (URL, fichier ou MAC→M3U) : playlist parsée en mémoire.

/// Catégories Live
final liveCategoriesRawProvider =
    FutureProvider.autoDispose<List<CategoryModel>>((ref) async {
  final playlist = ref.watch(activePlaylistProvider);
  if (playlist != null) return playlist.liveCategories;
  final creds = ref.watch(credentialsProvider);
  if (creds == null) return const [];
  return ref.watch(contentRepositoryProvider).liveCategories(creds);
});

/// Chaînes d'une catégorie (null = toutes)
final liveChannelsProvider = FutureProvider.autoDispose
    .family<List<LiveChannel>, String?>((ref, categoryId) async {
  final playlist = ref.watch(activePlaylistProvider);
  if (playlist != null) {
    return categoryId == null
        ? playlist.channels
        : playlist.channels
            .where((c) => c.categoryId == categoryId)
            .toList();
  }
  final creds = ref.watch(credentialsProvider);
  if (creds == null) return const [];
  return ref
      .watch(contentRepositoryProvider)
      .liveChannels(creds, categoryId: categoryId);
});

/// Catégories VOD
final vodCategoriesRawProvider =
    FutureProvider.autoDispose<List<CategoryModel>>((ref) async {
  final playlist = ref.watch(activePlaylistProvider);
  if (playlist != null) return playlist.vodCategories;
  final creds = ref.watch(credentialsProvider);
  if (creds == null) return const [];
  return ref.watch(contentRepositoryProvider).vodCategories(creds);
});

/// Films d'une catégorie (null = tous)
final moviesProvider = FutureProvider.autoDispose
    .family<List<VodItem>, String?>((ref, categoryId) async {
  final playlist = ref.watch(activePlaylistProvider);
  if (playlist != null) {
    return categoryId == null
        ? playlist.movies
        : playlist.movies.where((m) => m.categoryId == categoryId).toList();
  }
  final creds = ref.watch(credentialsProvider);
  if (creds == null) return const [];
  return ref
      .watch(contentRepositoryProvider)
      .movies(creds, categoryId: categoryId);
});

/// Catégories Séries
final seriesCategoriesRawProvider =
    FutureProvider.autoDispose<List<CategoryModel>>((ref) async {
  final playlist = ref.watch(activePlaylistProvider);
  if (playlist != null) return playlist.seriesCategories;
  final creds = ref.watch(credentialsProvider);
  if (creds == null) return const [];
  return ref.watch(contentRepositoryProvider).seriesCategories(creds);
});

/// Séries d'une catégorie (null = toutes)
final seriesProvider = FutureProvider.autoDispose
    .family<List<SeriesItem>, String?>((ref, categoryId) async {
  final playlist = ref.watch(activePlaylistProvider);
  if (playlist != null) {
    return categoryId == null
        ? playlist.series
        : playlist.series.where((s) => s.categoryId == categoryId).toList();
  }
  final creds = ref.watch(credentialsProvider);
  if (creds == null) return const [];
  return ref
      .watch(contentRepositoryProvider)
      .series(creds, categoryId: categoryId);
});

/// Épisodes d'une série
final episodesProvider = FutureProvider.autoDispose
    .family<List<EpisodeItem>, int>((ref, seriesId) async {
  final playlist = ref.watch(activePlaylistProvider);
  if (playlist != null) return playlist.episodesBySeries[seriesId] ?? const [];
  final creds = ref.watch(credentialsProvider);
  if (creds == null) return const [];
  return ref.watch(contentRepositoryProvider).episodes(creds, seriesId);
});

/// Catégories live visibles (catégories cachées exclues).
final liveCategoriesProvider =
    FutureProvider.autoDispose<List<CategoryModel>>((ref) async {
  final categories = await ref.watch(liveCategoriesRawProvider.future);
  final hidden = ref.watch(hiddenCategoriesProvider('live'));
  if (hidden.isEmpty) return categories;
  return categories.where((c) => !hidden.contains(c.id)).toList();
});

/// Catégories vod visibles (catégories cachées exclues).
final vodCategoriesProvider =
    FutureProvider.autoDispose<List<CategoryModel>>((ref) async {
  final categories = await ref.watch(vodCategoriesRawProvider.future);
  final hidden = ref.watch(hiddenCategoriesProvider('vod'));
  if (hidden.isEmpty) return categories;
  return categories.where((c) => !hidden.contains(c.id)).toList();
});

/// Catégories series visibles (catégories cachées exclues).
final seriesCategoriesProvider =
    FutureProvider.autoDispose<List<CategoryModel>>((ref) async {
  final categories = await ref.watch(seriesCategoriesRawProvider.future);
  final hidden = ref.watch(hiddenCategoriesProvider('series'));
  if (hidden.isEmpty) return categories;
  return categories.where((c) => !hidden.contains(c.id)).toList();
});
