import 'package:equatable/equatable.dart';

/// Épisode d'une série (Xtream : get_series_info, ou entrée M3U).
class EpisodeItem extends Equatable {
  final int episodeId;
  final String title;
  final int season;
  final int episodeNumber;
  final String containerExtension;

  /// Métadonnées (bloc "info" de get_series_info).
  final String plot;
  final String imageUrl;
  final int durationSecs;
  final String rating;

  /// URL directe du flux (playlists M3U). Null pour les comptes Xtream.
  final String? directUrl;

  const EpisodeItem({
    required this.episodeId,
    required this.title,
    required this.season,
    required this.episodeNumber,
    required this.containerExtension,
    this.plot = '',
    this.imageUrl = '',
    this.durationSecs = 0,
    this.rating = '',
    this.directUrl,
  });

  factory EpisodeItem.fromJson(Map<String, dynamic> json, int season) {
    final info = json['info'] is Map
        ? Map<String, dynamic>.from(json['info'] as Map)
        : const <String, dynamic>{};
    return EpisodeItem(
      episodeId: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: json['title']?.toString() ?? 'Épisode',
      season: season,
      episodeNumber: int.tryParse(json['episode_num']?.toString() ?? '') ?? 0,
      containerExtension: json['container_extension']?.toString() ?? 'mp4',
      plot: info['plot']?.toString() ?? '',
      imageUrl: info['movie_image']?.toString() ?? '',
      durationSecs:
          int.tryParse(info['duration_secs']?.toString() ?? '') ?? 0,
      rating: info['rating']?.toString() ?? '',
    );
  }

  /// Libellé court "S1E4".
  String get code => 'S${season}E$episodeNumber';

  @override
  List<Object?> get props => [episodeId];
}
