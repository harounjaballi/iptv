import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/live_providers.dart';
import '../../providers/media_providers.dart';
import '../../providers/profile_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/stats_providers.dart';

/// Statistiques de visionnage du profil actif :
/// temps total / aujourd'hui, activité des 7 derniers jours,
/// répartition TV / Films / Séries et contenus suivis.
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}min';
    if (m > 0) return '${m}min';
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final stats = ref.watch(watchStatsProvider);
    final profile = ref.watch(activeProfileProvider);
    final progress = ref.watch(watchProgressProvider);
    final scheme = Theme.of(context).colorScheme;

    final inProgress = progress.values.where((p) => p.inProgress).length;
    final completed = progress.values.where((p) => p.completed).length;
    final favCount = ref.watch(vodFavoritesProvider).length +
        ref.watch(seriesFavoritesProvider).length +
        ref.watch(liveFavoritesProvider).length;

    final last7 = stats.last7Days;
    final maxDay =
        last7.fold<int>(0, (max, v) => v > max ? v : max).clamp(1, 1 << 31);
    final week = last7.fold<int>(0, (total, v) => total + v);

    final byType = [
      ('live', l10n.tabLive, const Color(0xFF22D3EE)),
      ('vod', l10n.movies, const Color(0xFF7C3AED)),
      ('series', l10n.series, const Color(0xFFDB2777)),
    ];
    final maxType = stats.byType.values
        .fold<int>(0, (max, v) => v > max ? v : max)
        .clamp(1, 1 << 31);

    final dayLabels = () {
      final now = DateTime.now();
      const names = ['Lu', 'Ma', 'Me', 'Je', 'Ve', 'Sa', 'Di'];
      return [
        for (var i = 6; i >= 0; i--)
          names[(now.subtract(Duration(days: i)).weekday - 1) % 7],
      ];
    }();

    return Scaffold(
      appBar: AppBar(title: Text('${l10n.statistics} — ${profile.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---------- Cartes de synthèse ----------
          Row(
            children: [
              _statCard(context, Icons.schedule_rounded, l10n.watchTime,
                  _formatDuration(stats.totalSeconds)),
              const SizedBox(width: 12),
              _statCard(context, Icons.today_rounded, l10n.today,
                  _formatDuration(stats.todaySeconds)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statCard(context, Icons.play_circle_outline_rounded,
                  l10n.totalPlays, '${stats.plays}'),
              const SizedBox(width: 12),
              _statCard(context, Icons.favorite_rounded, l10n.favorites,
                  '$favCount'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statCard(context, Icons.pause_circle_outline_rounded,
                  l10n.inProgress, '$inProgress'),
              const SizedBox(width: 12),
              _statCard(context, Icons.check_circle_outline_rounded,
                  l10n.completed, '$completed'),
            ],
          ),
          const SizedBox(height: 20),
          // ---------- 7 derniers jours ----------
          Text('${l10n.last7Days} · ${_formatDuration(week)}',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++) ...[
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (last7[i] > 0)
                          Text(_formatDuration(last7[i]),
                              style: const TextStyle(fontSize: 9)),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 90 * (last7[i] / maxDay) + 4,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                scheme.primary,
                                scheme.primary.withValues(alpha: 0.5)
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(dayLabels[i],
                            style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  if (i < 6) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          // ---------- Répartition par type ----------
          Text(l10n.watchTime,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          for (final (key, label, color) in byType) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(width: 64, child: Text(label)),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (stats.byType[key] ?? 0) / maxType,
                        minHeight: 12,
                        backgroundColor: scheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 72,
                    child: Text(
                      _formatDuration(stats.byType[key] ?? 0),
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statCard(
      BuildContext context, IconData icon, String label, String value) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon,
                  size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(value,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
