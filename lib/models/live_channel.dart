import 'package:equatable/equatable.dart';

/// Chaîne TV en direct (Xtream : get_live_streams, ou entrée M3U).
class LiveChannel extends Equatable {
  final int streamId;
  final String name;
  final String logoUrl;
  final String categoryId;
  final int number;

  /// URL directe du flux (playlists M3U). Null pour les comptes Xtream :
  /// l'URL est alors construite depuis les identifiants.
  final String? directUrl;

  const LiveChannel({
    required this.streamId,
    required this.name,
    required this.logoUrl,
    required this.categoryId,
    required this.number,
    this.directUrl,
  });

  factory LiveChannel.fromJson(Map<String, dynamic> json) => LiveChannel(
        streamId: int.tryParse(json['stream_id']?.toString() ?? '') ?? 0,
        name: json['name']?.toString() ?? 'Chaîne',
        logoUrl: json['stream_icon']?.toString() ?? '',
        categoryId: json['category_id']?.toString() ?? '',
        number: int.tryParse(json['num']?.toString() ?? '') ?? 0,
      );

  @override
  List<Object?> get props => [streamId];
}
