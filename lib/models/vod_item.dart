import 'package:equatable/equatable.dart';

/// Film VOD (Xtream : get_vod_streams, ou entrée M3U).
class VodItem extends Equatable {
  final int streamId;
  final String name;
  final String posterUrl;
  final String categoryId;
  final String rating;
  final String containerExtension;

  /// Année de sortie (si fournie par le portail).
  final String year;

  /// Genres bruts, ex. "Action, Thriller".
  final String genre;

  /// Timestamp Unix d'ajout au catalogue (tri "Récemment ajoutés").
  final int added;

  /// URL directe du flux (playlists M3U). Null pour les comptes Xtream.
  final String? directUrl;

  const VodItem({
    required this.streamId,
    required this.name,
    required this.posterUrl,
    required this.categoryId,
    required this.rating,
    required this.containerExtension,
    this.year = '',
    this.genre = '',
    this.added = 0,
    this.directUrl,
  });

  factory VodItem.fromJson(Map<String, dynamic> json) => VodItem(
        streamId: int.tryParse(json['stream_id']?.toString() ?? '') ?? 0,
        name: json['name']?.toString() ?? 'Film',
        posterUrl: json['stream_icon']?.toString() ?? '',
        categoryId: json['category_id']?.toString() ?? '',
        rating: json['rating']?.toString() ?? '',
        containerExtension: json['container_extension']?.toString() ?? 'mp4',
        year: json['year']?.toString() ?? '',
        genre: json['genre']?.toString() ?? '',
        added: int.tryParse(json['added']?.toString() ?? '') ?? 0,
        directUrl: json['direct_url']?.toString(),
      );

  /// Sérialisation pour le cache Hive.
  Map<String, dynamic> toJson() => {
        'stream_id': streamId,
        'name': name,
        'stream_icon': posterUrl,
        'category_id': categoryId,
        'rating': rating,
        'container_extension': containerExtension,
        'year': year,
        'genre': genre,
        'added': added,
        if (directUrl != null) 'direct_url': directUrl,
      };

  /// Note numérique (0 si absente) pour les tris.
  double get ratingValue => double.tryParse(rating) ?? 0;

  @override
  List<Object?> get props => [streamId];
}
