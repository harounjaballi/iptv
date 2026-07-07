import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';
import 'profile_providers.dart';

/// ---------------- Statistiques de visionnage ----------------
/// Alimentées par les lecteurs (15 s de lecture → +15 s), par profil.
class WatchStats {
  /// Secondes par jour ('2026-07-06' → 5400), 60 derniers jours.
  final Map<String, int> days;

  /// Secondes par type ('live' / 'vod' / 'series').
  final Map<String, int> byType;

  /// Nombre de lectures démarrées.
  final int plays;

  const WatchStats({
    this.days = const {},
    this.byType = const {},
    this.plays = 0,
  });

  int get totalSeconds =>
      byType.values.fold(0, (total, seconds) => total + seconds);

  static String dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  int get todaySeconds => days[dayKey(DateTime.now())] ?? 0;

  /// Secondes des 7 derniers jours (du plus ancien à aujourd'hui).
  List<int> get last7Days {
    final now = DateTime.now();
    return [
      for (var i = 6; i >= 0; i--)
        days[dayKey(now.subtract(Duration(days: i)))] ?? 0,
    ];
  }

  factory WatchStats.fromJson(Map<String, dynamic> json) => WatchStats(
        days: {
          if (json['days'] is Map)
            for (final e in (json['days'] as Map).entries)
              e.key.toString(): int.tryParse(e.value.toString()) ?? 0,
        },
        byType: {
          if (json['byType'] is Map)
            for (final e in (json['byType'] as Map).entries)
              e.key.toString(): int.tryParse(e.value.toString()) ?? 0,
        },
        plays: int.tryParse(json['plays']?.toString() ?? '') ?? 0,
      );

  Map<String, dynamic> toJson() =>
      {'days': days, 'byType': byType, 'plays': plays};
}

class WatchStatsNotifier extends Notifier<WatchStats> {
  String get _key => 'watch_stats_${ref.read(dataScopeProvider)}';

  @override
  WatchStats build() {
    ref.watch(dataScopeProvider); // recharge au changement compte/profil
    final raw = ref.watch(cacheServiceProvider).getSetting(_key);
    if (raw == null || raw.isEmpty) return const WatchStats();
    try {
      return WatchStats.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return const WatchStats();
    }
  }

  Future<void> _persist(WatchStats stats) async {
    state = stats;
    await ref
        .read(cacheServiceProvider)
        .putSetting(_key, jsonEncode(stats.toJson()));
  }

  /// Ajoute du temps de visionnage (type : 'live' / 'vod' / 'series').
  Future<void> addSeconds(String type, int seconds) async {
    final today = WatchStats.dayKey(DateTime.now());
    final days = {...state.days, today: (state.days[today] ?? 0) + seconds};
    // Conserve ~60 jours d'historique.
    if (days.length > 60) {
      final keys = days.keys.toList()..sort();
      for (final k in keys.take(days.length - 60)) {
        days.remove(k);
      }
    }
    await _persist(WatchStats(
      days: days,
      byType: {...state.byType, type: (state.byType[type] ?? 0) + seconds},
      plays: state.plays,
    ));
  }

  Future<void> registerPlay() async => _persist(WatchStats(
        days: state.days,
        byType: state.byType,
        plays: state.plays + 1,
      ));
}

final watchStatsProvider =
    NotifierProvider<WatchStatsNotifier, WatchStats>(WatchStatsNotifier.new);
