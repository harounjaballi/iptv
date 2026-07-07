import 'dart:convert';

import '../../domain/repositories/content_repository.dart';
import '../../models/category_model.dart';
import '../../models/episode_item.dart';
import '../../models/live_channel.dart';
import '../../models/series_details.dart';
import '../../models/series_item.dart';
import '../../models/vod_details.dart';
import '../../models/vod_item.dart';
import '../../models/xtream_credentials.dart';
import '../../services/cache_service.dart';
import '../../services/xtream_api_service.dart';

/// Implémentation : API Xtream + cache Hive (stratégie cache-first avec TTL).
class ContentRepositoryImpl implements ContentRepository {
  final XtreamApiService _api;
  final CacheService _cache;

  const ContentRepositoryImpl(this._api, this._cache);

  Future<List<T>> _cachedList<T>(
    String cacheKey,
    Future<List<T>> Function() fetch,
    T Function(Map<String, dynamic>) fromJson,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    final cached = _cache.getJson(cacheKey);
    if (cached is String) {
      try {
        final list = jsonDecode(cached) as List;
        return list
            .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {/* cache corrompu : on refetch */}
    }
    final fresh = await fetch();
    await _cache.putJson(cacheKey, jsonEncode(fresh.map(toJson).toList()));
    return fresh;
  }

  @override
  Future<List<CategoryModel>> liveCategories(XtreamCredentials c) =>
      _cachedList(
        'live_categories',
        () => _api.getLiveCategories(c),
        CategoryModel.fromJson,
        (e) => {'category_id': e.id, 'category_name': e.name},
      );

  @override
  Future<List<CategoryModel>> vodCategories(XtreamCredentials c) =>
      _cachedList(
        'vod_categories',
        () => _api.getVodCategories(c),
        CategoryModel.fromJson,
        (e) => {'category_id': e.id, 'category_name': e.name},
      );

  @override
  Future<List<CategoryModel>> seriesCategories(XtreamCredentials c) =>
      _cachedList(
        'series_categories',
        () => _api.getSeriesCategories(c),
        CategoryModel.fromJson,
        (e) => {'category_id': e.id, 'category_name': e.name},
      );

  @override
  Future<List<LiveChannel>> liveChannels(XtreamCredentials c,
          {String? categoryId}) =>
      _api.getLiveStreams(c, categoryId: categoryId);

  @override
  Future<List<VodItem>> movies(XtreamCredentials c, {String? categoryId}) =>
      _api.getVodStreams(c, categoryId: categoryId);

  @override
  Future<List<SeriesItem>> series(XtreamCredentials c, {String? categoryId}) =>
      _api.getSeries(c, categoryId: categoryId);

  @override
  Future<List<EpisodeItem>> episodes(XtreamCredentials c, int seriesId) =>
      _api.getSeriesEpisodes(c, seriesId);

  @override
  Future<VodDetails> vodDetails(XtreamCredentials c, int streamId) =>
      _api.getVodInfo(c, streamId);

  @override
  Future<SeriesDetails> seriesDetails(XtreamCredentials c, int seriesId) =>
      _api.getSeriesInfo(c, seriesId);
}
