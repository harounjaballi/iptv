import 'dart:io';

import 'package:dio/dio.dart';

import '../core/errors/app_exception.dart';
import '../models/category_model.dart';
import '../models/episode_item.dart';
import '../models/live_channel.dart';
import '../models/series_item.dart';
import '../models/vod_item.dart';

/// Résultat du parsing d'une playlist M3U : contenu classé et prêt
/// à alimenter les onglets Live / Films / Séries.
class M3uPlaylist {
  final List<CategoryModel> liveCategories;
  final List<CategoryModel> vodCategories;
  final List<CategoryModel> seriesCategories;
  final List<LiveChannel> channels;
  final List<VodItem> movies;
  final List<SeriesItem> series;
  final Map<int, List<EpisodeItem>> episodesBySeries;

  const M3uPlaylist({
    required this.liveCategories,
    required this.vodCategories,
    required this.seriesCategories,
    required this.channels,
    required this.movies,
    required this.series,
    required this.episodesBySeries,
  });

  bool get isEmpty => channels.isEmpty && movies.isEmpty && series.isEmpty;

  int get totalEntries =>
      channels.length +
      movies.length +
      episodesBySeries.values.fold(0, (s, l) => s + l.length);
}

/// Parse les playlists M3U / M3U8 (attributs tvg-*, group-title)
/// et classe automatiquement les entrées :
/// - épisode de série si le nom contient SxxExx (ou « Saison x Épisode y ») ;
/// - film si l'URL pointe vers un fichier vidéo ou /movie/ ;
/// - chaîne live sinon.
class M3uParserService {
  final Dio _dio;

  const M3uParserService(this._dio);

  static final _attrRegex = RegExp(r'([\w-]+)="([^"]*)"');
  static final _seriesRegex = RegExp(
    r'^(.*?)[\s._-]*(?:S(\d{1,2})[\s._-]*E(\d{1,3})|Saison[\s._-]*(\d{1,2})[\s._-]*(?:Épisode|Episode|Ep)[\s._-]*(\d{1,3}))',
    caseSensitive: false,
  );
  static const _videoExtensions = {
    'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'mpg', 'mpeg', 'm4v'
  };

  // ---------- Récupération ----------

  /// Télécharge une playlist depuis une URL et la valide.
  Future<String> fetchFromUrl(String url) async {
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      final content = response.data;
      if (response.statusCode != 200 || content == null) {
        throw const ServerException(
            'Le serveur de la playlist ne répond pas (code HTTP invalide).');
      }
      _assertLooksLikeM3u(content);
      return content;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const NetworkException();
      }
      throw const ServerException(
          'Impossible de télécharger la playlist M3U.');
    }
  }

  /// Lit une playlist depuis un fichier local et la valide.
  Future<String> readFromFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        throw const FileException('Le fichier M3U est introuvable.');
      }
      final content = await file.readAsString();
      _assertLooksLikeM3u(content);
      return content;
    } on AppException {
      rethrow;
    } catch (_) {
      throw const FileException();
    }
  }

  void _assertLooksLikeM3u(String content) {
    final head = content.trimLeft();
    if (!head.startsWith('#EXTM3U') && !head.startsWith('#EXTINF')) {
      throw const PlaylistException(
          'Ce contenu n\'est pas une playlist M3U valide (en-tête #EXTM3U absent).');
    }
  }

  // ---------- Parsing & classement ----------

  M3uPlaylist parse(String content) {
    final lines = content.split(RegExp(r'\r?\n'));

    final channels = <LiveChannel>[];
    final movies = <VodItem>[];
    final liveCats = <String>{};
    final vodCats = <String>{};
    final seriesCats = <String>{};

    // titre de série → (catégorie, poster, épisodes)
    final seriesDraft = <String, _SeriesDraft>{};

    var nextId = 1;
    String? pendingExtinf;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF')) {
        pendingExtinf = line;
        continue;
      }
      if (line.startsWith('#')) continue; // autres directives ignorées
      if (pendingExtinf == null) continue; // URL orpheline

      final extinf = pendingExtinf;
      pendingExtinf = null;
      final url = line;

      // Nom = texte après la dernière virgule de la ligne EXTINF.
      final commaIndex = extinf.lastIndexOf(',');
      var name = commaIndex >= 0 && commaIndex < extinf.length - 1
          ? extinf.substring(commaIndex + 1).trim()
          : 'Sans nom';

      final attrs = <String, String>{
        for (final m in _attrRegex.allMatches(extinf))
          m.group(1)!.toLowerCase(): m.group(2) ?? '',
      };
      final logo = attrs['tvg-logo'] ?? '';
      final group = (attrs['group-title'] ?? '').trim();
      if (name.isEmpty) name = attrs['tvg-name'] ?? 'Sans nom';

      final id = nextId++;
      final kind = _classify(name, url, group);

      switch (kind) {
        case _EntryKind.seriesEpisode:
          // Le nom peut ne pas contenir de motif SxxExx (classement par URL).
          final match = _seriesRegex.firstMatch(name);
          final rawTitle = match?.group(1)?.trim() ?? '';
          final title = rawTitle.isEmpty ? name : rawTitle;
          final season = match == null
              ? 1
              : int.tryParse(match.group(2) ?? match.group(4) ?? '') ?? 1;
          final cat = group.isEmpty ? 'Séries' : group;
          seriesCats.add(cat);
          final draft = seriesDraft.putIfAbsent(
              title.toLowerCase(),
              () => _SeriesDraft(title: title, categoryName: cat));
          if (draft.posterUrl.isEmpty && logo.isNotEmpty) {
            draft.posterUrl = logo;
          }
          final episode = match == null
              ? draft.episodes.length + 1
              : int.tryParse(match.group(3) ?? match.group(5) ?? '') ?? 1;
          draft.episodes.add(EpisodeItem(
            episodeId: id,
            title: name,
            season: season,
            episodeNumber: episode,
            containerExtension: _extension(url),
            directUrl: url,
          ));
        case _EntryKind.movie:
          final cat = group.isEmpty ? 'Films' : group;
          vodCats.add(cat);
          movies.add(VodItem(
            streamId: id,
            name: name,
            posterUrl: logo,
            categoryId: cat,
            rating: '',
            containerExtension: _extension(url),
            directUrl: url,
          ));
        case _EntryKind.live:
          final cat = group.isEmpty ? 'Chaînes' : group;
          liveCats.add(cat);
          channels.add(LiveChannel(
            streamId: id,
            name: name,
            logoUrl: logo,
            categoryId: cat,
            number: channels.length + 1,
            directUrl: url,
          ));
      }
    }

    // Construction des séries finales avec ids synthétiques.
    final series = <SeriesItem>[];
    final episodesBySeries = <int, List<EpisodeItem>>{};
    var seriesId = 1;
    for (final draft in seriesDraft.values) {
      draft.episodes.sort((a, b) => a.season != b.season
          ? a.season.compareTo(b.season)
          : a.episodeNumber.compareTo(b.episodeNumber));
      series.add(SeriesItem(
        seriesId: seriesId,
        name: draft.title,
        posterUrl: draft.posterUrl,
        categoryId: draft.categoryName,
        rating: '',
        plot: '',
      ));
      episodesBySeries[seriesId] = draft.episodes;
      seriesId++;
    }

    List<CategoryModel> toCategories(Set<String> names) {
      final sorted = names.toList()..sort();
      return [for (final n in sorted) CategoryModel(id: n, name: n)];
    }

    final playlist = M3uPlaylist(
      liveCategories: toCategories(liveCats),
      vodCategories: toCategories(vodCats),
      seriesCategories: toCategories(seriesCats),
      channels: channels,
      movies: movies,
      series: series,
      episodesBySeries: episodesBySeries,
    );

    if (playlist.isEmpty) {
      throw const PlaylistException(
          'La playlist ne contient aucune entrée exploitable.');
    }
    return playlist;
  }

  _EntryKind _classify(String name, String url, String group) {
    if (_seriesRegex.hasMatch(name)) return _EntryKind.seriesEpisode;

    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    if (path.contains('/series/')) return _EntryKind.seriesEpisode;
    if (path.contains('/movie/')) return _EntryKind.movie;

    final ext = _extension(url).toLowerCase();
    if (_videoExtensions.contains(ext)) {
      final g = group.toLowerCase();
      if (g.contains('serie') || g.contains('series')) {
        return _EntryKind.seriesEpisode;
      }
      return _EntryKind.movie;
    }
    return _EntryKind.live;
  }

  String _extension(String url) {
    final path = Uri.tryParse(url)?.path ?? url;
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return 'ts';
    final ext = path.substring(dot + 1);
    return ext.length <= 5 ? ext : 'ts';
  }
}

enum _EntryKind { live, movie, seriesEpisode }

class _SeriesDraft {
  final String title;
  final String categoryName;
  String posterUrl = '';
  final List<EpisodeItem> episodes = [];

  _SeriesDraft({required this.title, required this.categoryName});
}
