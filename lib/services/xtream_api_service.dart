import 'dart:isolate';

import 'package:dio/dio.dart';
import '../core/errors/app_exception.dart';
import '../models/account_info.dart';
import '../models/category_model.dart';
import '../models/episode_item.dart';
import '../models/live_channel.dart';
import '../models/series_details.dart';
import '../models/series_item.dart';
import '../models/vod_details.dart';
import '../models/vod_item.dart';
import '../models/xtream_credentials.dart';

/// Client API Xtream Codes (player_api.php).
class XtreamApiService {
  final Dio _dio;

  const XtreamApiService(this._dio);

  Future<dynamic> _get(XtreamCredentials creds,
      {Map<String, String> extra = const {}}) async {
    try {
      final response = await _dio.get(
        creds.playerApiUrl,
        queryParameters: {
          'username': creds.username,
          'password': creds.password,
          ...extra,
        },
      );
      if (response.statusCode != 200) {
        throw const ServerException();
      }
      return response.data;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const NetworkException();
      }
      throw const ServerException();
    }
  }

  /// Authentification : renvoie les infos du compte si valide.
  Future<AccountInfo> authenticate(XtreamCredentials creds) async {
    final data = await _get(creds);
    if (data is! Map || data['user_info'] is! Map) {
      throw const AuthException();
    }
    final userInfo = Map<String, dynamic>.from(data['user_info'] as Map);
    final auth = userInfo['auth']?.toString();
    if (auth == '0' || auth == 'false') {
      throw const AuthException();
    }
    final account = AccountInfo.fromJson(userInfo);
    if (!account.isActive) {
      throw const AuthException('Compte inactif ou expiré.');
    }
    return account;
  }

  /// Seuil au-delà duquel le parsing part dans un isolate : mapper 10 000
  /// chaînes sur le thread UI bloque plusieurs frames (jank visible au
  /// premier chargement, surtout sur Fire TV Stick).
  static const int _isolateThreshold = 800;

  static List<T> _parseListSync<T>(
      List<dynamic> data, T Function(Map<String, dynamic>) mapper) {
    return data
        .whereType<Map>()
        .map((e) => mapper(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<T>> _parseList<T>(
      dynamic data, T Function(Map<String, dynamic>) mapper) async {
    if (data is! List) return const [];
    if (data.length < _isolateThreshold) return _parseListSync(data, mapper);
    // Grande liste : parsing hors du thread UI (les tear-offs de
    // constructeurs des modèles sont transférables entre isolates).
    return Isolate.run(() => _parseListSync(data, mapper));
  }

  Future<List<CategoryModel>> getLiveCategories(XtreamCredentials c) async =>
      _parseList(await _get(c, extra: {'action': 'get_live_categories'}),
          CategoryModel.fromJson);

  Future<List<CategoryModel>> getVodCategories(XtreamCredentials c) async =>
      _parseList(await _get(c, extra: {'action': 'get_vod_categories'}),
          CategoryModel.fromJson);

  Future<List<CategoryModel>> getSeriesCategories(XtreamCredentials c) async =>
      _parseList(await _get(c, extra: {'action': 'get_series_categories'}),
          CategoryModel.fromJson);

  Future<List<LiveChannel>> getLiveStreams(XtreamCredentials c,
      {String? categoryId}) async {
    final extra = {'action': 'get_live_streams'};
    if (categoryId != null) extra['category_id'] = categoryId;
    return _parseList(await _get(c, extra: extra), LiveChannel.fromJson);
  }

  Future<List<VodItem>> getVodStreams(XtreamCredentials c,
      {String? categoryId}) async {
    final extra = {'action': 'get_vod_streams'};
    if (categoryId != null) extra['category_id'] = categoryId;
    return _parseList(await _get(c, extra: extra), VodItem.fromJson);
  }

  Future<List<SeriesItem>> getSeries(XtreamCredentials c,
      {String? categoryId}) async {
    final extra = {'action': 'get_series'};
    if (categoryId != null) extra['category_id'] = categoryId;
    return _parseList(await _get(c, extra: extra), SeriesItem.fromJson);
  }

  /// Fiche détaillée d'un film (synopsis, casting, réalisateur, durée...).
  Future<VodDetails> getVodInfo(XtreamCredentials c, int streamId) async {
    final data = await _get(c, extra: {
      'action': 'get_vod_info',
      'vod_id': streamId.toString(),
    });
    if (data is! Map) return VodDetails.empty;
    return VodDetails.fromJson(Map<String, dynamic>.from(data));
  }

  /// Fiche détaillée d'une série : métadonnées + épisodes par saison.
  Future<SeriesDetails> getSeriesInfo(
      XtreamCredentials c, int seriesId) async {
    final data = await _get(c, extra: {
      'action': 'get_series_info',
      'series_id': seriesId.toString(),
    });
    if (data is! Map) return const SeriesDetails();
    return SeriesDetails.fromJson(Map<String, dynamic>.from(data));
  }

  /// Épisodes d'une série (raccourci sur getSeriesInfo).
  Future<List<EpisodeItem>> getSeriesEpisodes(
          XtreamCredentials c, int seriesId) async =>
      (await getSeriesInfo(c, seriesId)).episodes;
}
