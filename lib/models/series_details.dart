import 'package:equatable/equatable.dart';

import 'episode_item.dart';

/// Fiche détaillée d'une série (Xtream : get_series_info) :
/// métadonnées + épisodes triés par saison/numéro.
class SeriesDetails extends Equatable {
  final String plot;
  final String cast;
  final String director;
  final String genre;
  final String releaseDate;
  final String rating;
  final String backdropUrl;
  final List<EpisodeItem> episodes;

  const SeriesDetails({
    this.plot = '',
    this.cast = '',
    this.director = '',
    this.genre = '',
    this.releaseDate = '',
    this.rating = '',
    this.backdropUrl = '',
    this.episodes = const [],
  });

  factory SeriesDetails.fromJson(Map<String, dynamic> json) {
    final info = json['info'] is Map
        ? Map<String, dynamic>.from(json['info'] as Map)
        : const <String, dynamic>{};

    String backdrop = '';
    final raw = info['backdrop_path'];
    if (raw is List && raw.isNotEmpty) {
      backdrop = raw.first?.toString() ?? '';
    } else if (raw is String) {
      backdrop = raw;
    }

    final episodes = <EpisodeItem>[];
    final episodesRaw = json['episodes'];
    if (episodesRaw is Map) {
      episodesRaw.forEach((seasonKey, list) {
        final season = int.tryParse(seasonKey.toString()) ?? 0;
        if (list is List) {
          for (final e in list.whereType<Map>()) {
            episodes
                .add(EpisodeItem.fromJson(Map<String, dynamic>.from(e), season));
          }
        }
      });
    } else if (episodesRaw is List) {
      // Certains portails renvoient une liste de listes.
      for (final seasonList in episodesRaw.whereType<List>()) {
        for (final e in seasonList.whereType<Map>()) {
          final map = Map<String, dynamic>.from(e);
          final season = int.tryParse(map['season']?.toString() ?? '') ?? 0;
          episodes.add(EpisodeItem.fromJson(map, season));
        }
      }
    }
    episodes.sort((a, b) => a.season != b.season
        ? a.season.compareTo(b.season)
        : a.episodeNumber.compareTo(b.episodeNumber));

    return SeriesDetails(
      plot: info['plot']?.toString() ?? '',
      cast: info['cast']?.toString() ?? '',
      director: info['director']?.toString() ?? '',
      genre: info['genre']?.toString() ?? '',
      releaseDate: info['releaseDate']?.toString() ??
          info['release_date']?.toString() ??
          '',
      rating: info['rating']?.toString() ?? '',
      backdropUrl: backdrop,
      episodes: episodes,
    );
  }

  /// Saisons disponibles, triées.
  List<int> get seasons =>
      episodes.map((e) => e.season).toSet().toList()..sort();

  @override
  List<Object?> get props => [plot, cast, director, genre, episodes];
}
