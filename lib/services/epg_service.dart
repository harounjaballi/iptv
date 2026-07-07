import 'package:dio/dio.dart';

import '../models/epg_program.dart';
import '../models/xtream_credentials.dart';

/// Guide TV Xtream (action=get_short_epg) avec cache mémoire par chaîne.
/// Les comptes M3U sans EPG renvoient simplement une liste vide.
class EpgService {
  final Dio _dio;

  /// streamId → (date de récupération, programmes)
  final Map<String, (DateTime, List<EpgProgram>)> _cache = {};

  static const _ttl = Duration(minutes: 10);

  EpgService(this._dio);

  Future<List<EpgProgram>> shortEpg(
    XtreamCredentials creds,
    int streamId, {
    int limit = 4,
  }) async {
    final key = '${creds.host}_${creds.username}_$streamId';
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.$1) < _ttl) {
      return cached.$2;
    }

    try {
      final response = await _dio.get(
        creds.playerApiUrl,
        queryParameters: {
          'username': creds.username,
          'password': creds.password,
          'action': 'get_short_epg',
          'stream_id': streamId.toString(),
          'limit': limit.toString(),
        },
      );
      final data = response.data;
      final listings = data is Map ? data['epg_listings'] : null;
      final programs = listings is List
          ? listings
              .whereType<Map>()
              .map((e) => EpgProgram.fromXtream(Map<String, dynamic>.from(e)))
              .toList()
          : <EpgProgram>[];
      programs.sort((a, b) => a.start.compareTo(b.start));
      _cache[key] = (DateTime.now(), programs);
      return programs;
    } catch (_) {
      // EPG indisponible : non bloquant.
      return const [];
    }
  }

  void clear() => _cache.clear();
}
