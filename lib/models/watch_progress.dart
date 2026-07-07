import 'package:equatable/equatable.dart';

/// Position de lecture d'un contenu VOD (film ou épisode).
/// Clés : "vod_{streamId}" ou "ep_{episodeId}".
class WatchProgress extends Equatable {
  final int positionMs;
  final int durationMs;
  final int updatedAt; // epoch ms

  const WatchProgress({
    required this.positionMs,
    required this.durationMs,
    required this.updatedAt,
  });

  factory WatchProgress.fromJson(Map<String, dynamic> json) => WatchProgress(
        positionMs: int.tryParse(json['p']?.toString() ?? '') ?? 0,
        durationMs: int.tryParse(json['d']?.toString() ?? '') ?? 0,
        updatedAt: int.tryParse(json['t']?.toString() ?? '') ?? 0,
      );

  Map<String, dynamic> toJson() =>
      {'p': positionMs, 'd': durationMs, 't': updatedAt};

  /// Ratio 0..1 (0 si durée inconnue).
  double get ratio =>
      durationMs <= 0 ? 0 : (positionMs / durationMs).clamp(0.0, 1.0);

  /// Lecture en cours : entamée mais pas terminée.
  bool get inProgress => ratio >= 0.02 && ratio <= 0.95;

  /// Considéré comme vu.
  bool get completed => ratio > 0.95;

  static String vodKey(int streamId) => 'vod_$streamId';
  static String episodeKey(int episodeId) => 'ep_$episodeId';

  @override
  List<Object?> get props => [positionMs, durationMs, updatedAt];
}
