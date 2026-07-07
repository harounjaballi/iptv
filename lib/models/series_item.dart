import 'package:equatable/equatable.dart';

/// Série (get_series).
class SeriesItem extends Equatable {
  final int seriesId;
  final String name;
  final String posterUrl;
  final String categoryId;
  final String rating;
  final String plot;

  /// Métadonnées catalogue (souvent déjà présentes dans get_series).
  final String year;
  final String genre;
  final String cast;
  final String director;
  final String releaseDate;
  final String backdropUrl;

  /// Timestamp Unix de dernière modification (tri "Récemment ajoutés").
  final int lastModified;

  const SeriesItem({
    required this.seriesId,
    required this.name,
    required this.posterUrl,
    required this.categoryId,
    required this.rating,
    required this.plot,
    this.year = '',
    this.genre = '',
    this.cast = '',
    this.director = '',
    this.releaseDate = '',
    this.backdropUrl = '',
    this.lastModified = 0,
  });

  factory SeriesItem.fromJson(Map<String, dynamic> json) {
    // backdrop_path peut être une liste ou une chaîne selon les portails.
    String backdrop = '';
    final raw = json['backdrop_path'];
    if (raw is List && raw.isNotEmpty) {
      backdrop = raw.first?.toString() ?? '';
    } else if (raw is String) {
      backdrop = raw;
    }
    return SeriesItem(
      seriesId: int.tryParse(json['series_id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? 'Série',
      posterUrl: json['cover']?.toString() ?? '',
      categoryId: json['category_id']?.toString() ?? '',
      rating: json['rating']?.toString() ?? '',
      plot: json['plot']?.toString() ?? '',
      year: json['year']?.toString() ??
          (json['releaseDate']?.toString().split('-').firstOrNull ?? ''),
      genre: json['genre']?.toString() ?? '',
      cast: json['cast']?.toString() ?? '',
      director: json['director']?.toString() ?? '',
      releaseDate: json['releaseDate']?.toString() ??
          json['release_date']?.toString() ??
          '',
      backdropUrl: backdrop,
      lastModified:
          int.tryParse(json['last_modified']?.toString() ?? '') ?? 0,
    );
  }

  /// Sérialisation pour le cache Hive.
  Map<String, dynamic> toJson() => {
        'series_id': seriesId,
        'name': name,
        'cover': posterUrl,
        'category_id': categoryId,
        'rating': rating,
        'plot': plot,
        'year': year,
        'genre': genre,
        'cast': cast,
        'director': director,
        'releaseDate': releaseDate,
        'backdrop_path': backdropUrl,
        'last_modified': lastModified,
      };

  double get ratingValue => double.tryParse(rating) ?? 0;

  @override
  List<Object?> get props => [seriesId];
}
