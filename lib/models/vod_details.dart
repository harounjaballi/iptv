import 'package:equatable/equatable.dart';

/// Fiche détaillée d'un film (Xtream : get_vod_info).
class VodDetails extends Equatable {
  final String plot;
  final String cast;
  final String director;
  final String genre;
  final String releaseDate;
  final String duration; // "01:52:30"
  final int durationSecs;
  final String rating;
  final String backdropUrl;
  final String youtubeTrailer;

  const VodDetails({
    this.plot = '',
    this.cast = '',
    this.director = '',
    this.genre = '',
    this.releaseDate = '',
    this.duration = '',
    this.durationSecs = 0,
    this.rating = '',
    this.backdropUrl = '',
    this.youtubeTrailer = '',
  });

  static const empty = VodDetails();

  factory VodDetails.fromJson(Map<String, dynamic> json) {
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
    return VodDetails(
      plot: info['plot']?.toString() ?? info['description']?.toString() ?? '',
      cast: info['cast']?.toString() ?? info['actors']?.toString() ?? '',
      director: info['director']?.toString() ?? '',
      genre: info['genre']?.toString() ?? '',
      releaseDate: info['releasedate']?.toString() ??
          info['release_date']?.toString() ??
          '',
      duration: info['duration']?.toString() ?? '',
      durationSecs:
          int.tryParse(info['duration_secs']?.toString() ?? '') ?? 0,
      rating: info['rating']?.toString() ?? '',
      backdropUrl: backdrop,
      youtubeTrailer: info['youtube_trailer']?.toString() ?? '',
    );
  }

  /// Année dérivée de la date de sortie.
  String get year =>
      releaseDate.length >= 4 ? releaseDate.substring(0, 4) : '';

  @override
  List<Object?> get props =>
      [plot, cast, director, genre, releaseDate, duration, rating];
}
