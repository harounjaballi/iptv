import 'package:cached_network_image/cached_network_image.dart';
import '../../core/cache/app_cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/episode_item.dart';
import '../../models/series_details.dart';
import '../../models/series_item.dart';
import '../../models/watch_progress.dart';
import '../../providers/auth_provider.dart';
import '../../providers/media_providers.dart';
import '../../utils/formatters.dart';
import '../../widgets/error_view.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/media_row.dart';
import '../../widgets/poster_card.dart';
import 'player_screen.dart';

/// Fiche série façon Netflix : backdrop, métadonnées, synopsis,
/// casting, réalisateur, sélecteur de saisons, épisodes avec progression,
/// reprise du dernier épisode, favori, lecture auto et recommandations.
class SeriesDetailsScreen extends ConsumerStatefulWidget {
  final SeriesItem series;

  const SeriesDetailsScreen({super.key, required this.series});

  @override
  ConsumerState<SeriesDetailsScreen> createState() =>
      _SeriesDetailsScreenState();
}

class _SeriesDetailsScreenState extends ConsumerState<SeriesDetailsScreen> {
  int? _selectedSeason;
  bool _plotExpanded = false;

  SeriesItem get series => widget.series;

  // ---------------- Lecture ----------------

  /// Lance la lecture à partir d'un épisode, avec la suite de la série
  /// en file d'attente (lecture automatique de l'épisode suivant).
  void _playFrom(List<EpisodeItem> episodes, int index, {Duration? startAt}) {
    final creds = ref.read(credentialsProvider);
    final queue = <PlayerQueueItem>[];
    for (final ep in episodes) {
      final url = ep.directUrl ??
          creds?.seriesStreamUrl(ep.episodeId, ep.containerExtension);
      if (url == null) return;
      queue.add(PlayerQueueItem(
        url: url,
        title: '${series.name} — ${ep.code} · ${ep.title}',
        progressKey: WatchProgress.episodeKey(ep.episodeId),
      ));
    }
    ref.read(seriesHistoryProvider.notifier).registerWatch(series.seriesId);

    context.push('/player', extra: PlayerArgs(
      url: queue[index].url,
      title: queue[index].title,
      isLive: false,
      startAt: startAt,
      queue: queue,
      queueIndex: index,
      imageUrl: series.posterUrl,
      onItemStarted: (i) {
        // Mémorise le dernier épisode lu (reprise de la série).
        ref
            .read(seriesLastEpisodeProvider.notifier)
            .register(series.seriesId, episodes[i].episodeId);
      },
    ));
  }

  /// Épisode de reprise : dernier vu (à sa position), sinon le premier.
  (int, Duration?) _resumePoint(List<EpisodeItem> episodes) {
    final lastEp = ref.read(seriesLastEpisodeProvider)[series.seriesId];
    if (lastEp != null) {
      final index = episodes.indexWhere((e) => e.episodeId == lastEp);
      if (index != -1) {
        final p = ref
            .read(watchProgressProvider)[WatchProgress.episodeKey(lastEp)];
        if (p != null && p.completed && index < episodes.length - 1) {
          return (index + 1, null); // épisode terminé → le suivant
        }
        return (
          index,
          p != null && p.inProgress
              ? Duration(milliseconds: p.positionMs)
              : null
        );
      }
    }
    return (0, null);
  }

  // ---------------- Build ----------------

  @override
  Widget build(BuildContext context) {
    final detailsAsync = ref.watch(seriesDetailsProvider(series.seriesId));

    return Scaffold(
      body: detailsAsync.when(
        data: (details) => _content(details),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => SafeArea(
          child: Column(
            children: [
              AppBar(title: Text(series.name)),
              Expanded(
                child: ErrorView(
                  message: e.toString(),
                  onRetry: () =>
                      ref.invalidate(seriesDetailsProvider(series.seriesId)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(SeriesDetails details) {
    final favorites = ref.watch(seriesFavoritesProvider);
    final isFav = favorites.contains(series.seriesId);
    final progress = ref.watch(watchProgressProvider);
    final lastEpisodes = ref.watch(seriesLastEpisodeProvider);
    final recommendations = ref.watch(seriesRecommendationsProvider(series));

    final episodes = details.episodes;
    final seasons = details.seasons;
    final season = _selectedSeason ??
        (() {
          // Saison par défaut : celle du dernier épisode vu, sinon la première.
          final lastEp = lastEpisodes[series.seriesId];
          if (lastEp != null) {
            for (final e in episodes) {
              if (e.episodeId == lastEp) return e.season;
            }
          }
          return seasons.isNotEmpty ? seasons.first : 0;
        })();
    final seasonEpisodes =
        episodes.where((e) => e.season == season).toList();

    final backdrop = details.backdropUrl.isNotEmpty
        ? details.backdropUrl
        : (series.backdropUrl.isNotEmpty
            ? series.backdropUrl
            : series.posterUrl);
    final plot = details.plot.isNotEmpty ? details.plot : series.plot;
    final genre = details.genre.isNotEmpty ? details.genre : series.genre;
    final cast = details.cast.isNotEmpty ? details.cast : series.cast;
    final director =
        details.director.isNotEmpty ? details.director : series.director;
    final rating = Formatters.rating(
        details.rating.isNotEmpty ? details.rating : series.rating);

    final resumeLabel = () {
      if (episodes.isEmpty) return 'Lire';
      final (index, startAt) = _resumePoint(episodes);
      final ep = episodes[index];
      if (index == 0 && startAt == null) return 'Lire ${ep.code}';
      return startAt == null ? 'Lire ${ep.code}' : 'Reprendre ${ep.code}';
    }();

    return CustomScrollView(
      slivers: [
        // ---------- En-tête backdrop ----------
        SliverAppBar(
          expandedHeight: 260,
          pinned: true,
          actions: [
            IconButton(
              tooltip: isFav ? 'Retirer des favoris' : 'Ajouter aux favoris',
              icon: Icon(
                isFav ? Icons.favorite : Icons.favorite_border,
                color: isFav ? Colors.redAccent : null,
              ),
              onPressed: () => ref
                  .read(seriesFavoritesProvider.notifier)
                  .toggle(series.seriesId),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (backdrop.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: backdrop,
                    cacheManager: AppCacheManager.instance,
                    memCacheWidth: 1280, // backdrop plein écran, plafonné 1280px
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        const ColoredBox(color: Colors.black26),
                  )
                else
                  const ColoredBox(color: Colors.black26),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                      stops: [0.4, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Text(
                    series.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // ---------- Métadonnées + synopsis ----------
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (series.year.isNotEmpty) _chip(series.year),
                    if (seasons.isNotEmpty)
                      _chip(
                          '${seasons.length} saison${seasons.length > 1 ? 's' : ''}'),
                    if (episodes.isNotEmpty)
                      _chip('${episodes.length} épisodes'),
                    if (rating != '—') _chip(rating, icon: Icons.star_rounded),
                    for (final g in genre
                        .split(RegExp(r'[,/|]'))
                        .map((g) => g.trim())
                        .where((g) => g.isNotEmpty)
                        .take(3))
                      _chip(g, outlined: true),
                  ],
                ),
                const SizedBox(height: 14),
                if (episodes.isNotEmpty)
                  GradientButton(
                    onPressed: () {
                      final (index, startAt) = _resumePoint(episodes);
                      _playFrom(episodes, index, startAt: startAt);
                    },
                    icon: Icons.play_arrow_rounded,
                    label: resumeLabel,
                  ),
                const SizedBox(height: 16),
                if (plot.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () =>
                        setState(() => _plotExpanded = !_plotExpanded),
                    child: Text(
                      plot,
                      maxLines: _plotExpanded ? null : 4,
                      overflow: _plotExpanded ? null : TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (director.isNotEmpty) ...[
                  _infoLine('Réalisateur', director),
                  const SizedBox(height: 6),
                ],
                if (cast.isNotEmpty) ...[
                  _infoLine('Casting', cast),
                  const SizedBox(height: 6),
                ],
                const SizedBox(height: 8),
                // ---------- Sélecteur de saisons ----------
                if (seasons.length > 1)
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: seasons.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => ChoiceChip(
                        label: Text('Saison ${seasons[i]}'),
                        selected: season == seasons[i],
                        onSelected: (_) =>
                            setState(() => _selectedSeason = seasons[i]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // ---------- Épisodes de la saison ----------
        if (seasonEpisodes.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Aucun épisode disponible')),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            sliver: SliverList.builder(
              itemCount: seasonEpisodes.length,
              itemBuilder: (context, i) {
                final ep = seasonEpisodes[i];
                final p =
                    progress[WatchProgress.episodeKey(ep.episodeId)];
                return _EpisodeTile(
                  episode: ep,
                  progress: p,
                  onTap: () {
                    final index = episodes.indexOf(ep);
                    _playFrom(
                      episodes,
                      index,
                      startAt: p != null && p.inProgress
                          ? Duration(milliseconds: p.positionMs)
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        // ---------- Recommandations ----------
        if (recommendations.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: MediaRow(
                title: 'Séries similaires',
                itemCount: recommendations.length,
                itemBuilder: (context, i) {
                  final s = recommendations[i];
                  return PosterCard(
                    title: s.name,
                    imageUrl: s.posterUrl,
                    rating: Formatters.rating(s.rating),
                    subtitle: s.year,
                    onTap: () => context
                        .pushReplacement('/series/${s.seriesId}', extra: s),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _chip(String label, {IconData? icon, bool outlined = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : scheme.surfaceContainerHighest,
        border: outlined ? Border.all(color: scheme.outlineVariant) : null,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: scheme.primary),
            const SizedBox(width: 4),
          ],
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _infoLine(String label, String value) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyMedium,
        children: [
          TextSpan(
              text: '$label : ',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

/// Ligne d'épisode : miniature, titre, synopsis, durée + progression.
class _EpisodeTile extends StatelessWidget {
  final EpisodeItem episode;
  final WatchProgress? progress;
  final VoidCallback onTap;

  const _EpisodeTile({
    required this.episode,
    required this.onTap,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final duration = episode.durationSecs > 0
        ? Formatters.duration(Duration(seconds: episode.durationSecs))
        : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Miniature
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 110,
                      height: 66,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          episode.imageUrl.isEmpty
                              ? ColoredBox(
                                  color: scheme.surfaceContainerHighest,
                                  child: const Icon(
                                      Icons.play_circle_outline,
                                      size: 28))
                              : CachedNetworkImage(
                                  imageUrl: episode.imageUrl,
                                  cacheManager: AppCacheManager.instance,
                                  memCacheWidth: 1280, // backdrop plein écran, plafonné 1280px
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => ColoredBox(
                                    color: scheme.surfaceContainerHighest,
                                    child: const Icon(
                                        Icons.play_circle_outline,
                                        size: 28),
                                  ),
                                ),
                          if (progress?.completed ?? false)
                            const Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.check_circle,
                                    color: Colors.greenAccent, size: 18),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${episode.code} · ${episode.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (duration != null)
                          Text(duration,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant)),
                        if (episode.plot.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            episode.plot,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.play_circle_outline),
                ],
              ),
            ),
            if (progress != null && progress!.inProgress)
              LinearProgressIndicator(
                value: progress!.ratio,
                minHeight: 3,
                backgroundColor: Colors.transparent,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFFE50914)),
              ),
          ],
        ),
      ),
    );
  }
}
