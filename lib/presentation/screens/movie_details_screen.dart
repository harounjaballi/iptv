import 'package:cached_network_image/cached_network_image.dart';
import '../../core/cache/app_cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/vod_details.dart';
import '../../models/vod_item.dart';
import '../../models/watch_progress.dart';
import '../../providers/auth_provider.dart';
import '../../providers/media_providers.dart';
import '../../utils/formatters.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/media_row.dart';
import '../../widgets/poster_card.dart';
import 'player_screen.dart';

/// Fiche film façon Netflix : backdrop, affiche, métadonnées
/// (année, durée, genres, note), synopsis, casting, réalisateur,
/// Lire / Reprendre, favori et recommandations.
class MovieDetailsScreen extends ConsumerWidget {
  final VodItem movie;

  const MovieDetailsScreen({super.key, required this.movie});

  void _play(BuildContext context, WidgetRef ref, {Duration? startAt}) {
    final creds = ref.read(credentialsProvider);
    final url = movie.directUrl ??
        creds?.vodStreamUrl(movie.streamId, movie.containerExtension);
    if (url == null) return;
    context.push('/player', extra: PlayerArgs(
      url: url,
      title: movie.name,
      isLive: false,
      progressKey: WatchProgress.vodKey(movie.streamId),
      startAt: startAt,
      imageUrl: movie.posterUrl,
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(vodDetailsProvider(movie.streamId));
    final details = detailsAsync.valueOrNull ?? VodDetails.empty;
    final progress =
        ref.watch(watchProgressProvider)[WatchProgress.vodKey(movie.streamId)];
    final favorites = ref.watch(vodFavoritesProvider);
    final isFav = favorites.contains(movie.streamId);
    final recommendations = ref.watch(movieRecommendationsProvider(movie));

    final backdrop =
        details.backdropUrl.isNotEmpty ? details.backdropUrl : movie.posterUrl;
    final year = details.year.isNotEmpty ? details.year : movie.year;
    final genre = details.genre.isNotEmpty ? details.genre : movie.genre;
    final rating = Formatters.rating(
        details.rating.isNotEmpty ? details.rating : movie.rating);

    return Scaffold(
      body: CustomScrollView(
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
                    .read(vodFavoritesProvider.notifier)
                    .toggle(movie.streamId),
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
                ],
              ),
            ),
          ),
          // ---------- Contenu ----------
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: 110,
                          height: 165,
                          child: movie.posterUrl.isEmpty
                              ? const ColoredBox(
                                  color: Colors.black26,
                                  child: Icon(Icons.movie_outlined, size: 40))
                              : CachedNetworkImage(
                                  imageUrl: movie.posterUrl,
                                  cacheManager: AppCacheManager.instance,
                                  memCacheWidth: 1280, // backdrop plein écran, plafonné 1280px
                                  fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              movie.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if (year.isNotEmpty) _chip(context, year),
                                if (details.duration.isNotEmpty)
                                  _chip(context, details.duration,
                                      icon: Icons.schedule_rounded),
                                if (rating != '—')
                                  _chip(context, rating,
                                      icon: Icons.star_rounded),
                              ],
                            ),
                            if (genre.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final g in genre
                                      .split(RegExp(r'[,/|]'))
                                      .map((g) => g.trim())
                                      .where((g) => g.isNotEmpty)
                                      .take(4))
                                    _chip(context, g, outlined: true),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ---------- Boutons Lire / Reprendre ----------
                  if (progress != null && progress.inProgress) ...[
                    GradientButton(
                      onPressed: () => _play(context, ref,
                          startAt:
                              Duration(milliseconds: progress.positionMs)),
                      icon: Icons.play_arrow_rounded,
                      label:
                          'Reprendre à ${Formatters.duration(Duration(milliseconds: progress.positionMs))}',
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _play(context, ref),
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Reprendre depuis le début'),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: progress.ratio,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ] else
                    GradientButton(
                      onPressed: () => _play(context, ref),
                      icon: Icons.play_arrow_rounded,
                      label: 'Lire',
                    ),
                  const SizedBox(height: 20),
                  // ---------- Synopsis ----------
                  if (detailsAsync.isLoading)
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ))
                  else ...[
                    Text('Synopsis',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      details.plot.isEmpty
                          ? 'Aucun synopsis disponible.'
                          : details.plot,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(height: 1.4),
                    ),
                    // ---------- Casting / Réalisateur ----------
                    if (details.director.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _infoLine(context, 'Réalisateur', details.director),
                    ],
                    if (details.cast.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _infoLine(context, 'Casting', details.cast),
                    ],
                    if (details.releaseDate.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _infoLine(context, 'Sortie', details.releaseDate),
                    ],
                  ],
                ],
              ),
            ),
          ),
          // ---------- Recommandations ----------
          if (recommendations.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: MediaRow(
                  title: 'Vous aimerez aussi',
                  itemCount: recommendations.length,
                  itemBuilder: (context, i) {
                    final m = recommendations[i];
                    return PosterCard(
                      title: m.name,
                      imageUrl: m.posterUrl,
                      rating: Formatters.rating(m.rating),
                      subtitle: m.year,
                      onTap: () => context.pushReplacement(
                          '/movie/${m.streamId}',
                          extra: m),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label,
      {IconData? icon, bool outlined = false}) {
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

  Widget _infoLine(BuildContext context, String label, String value) {
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
