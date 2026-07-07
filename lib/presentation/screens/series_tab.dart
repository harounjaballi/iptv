import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/perf/image_prefetcher.dart';
import '../../core/utils/debouncer.dart';
import '../../models/series_item.dart';
import '../../providers/content_providers.dart';
import '../../providers/media_providers.dart';
import '../../utils/formatters.dart';
import '../../utils/responsive.dart';
import '../../widgets/error_view.dart';
import '../../widgets/hero_banner.dart';
import '../../widgets/media_row.dart';
import '../../widgets/paged_grid.dart';
import '../../widgets/poster_card.dart';
import '../../widgets/skeleton_loader.dart';

/// Onglet Séries — style Netflix :
/// - Accueil : bannière héro + rangées (Continuer, Favoris, Récents, Top, catégories)
/// - Navigation : recherche + filtres (catégorie, tri) + grille d'affiches.
class SeriesTab extends ConsumerStatefulWidget {
  const SeriesTab({super.key});

  @override
  ConsumerState<SeriesTab> createState() => _SeriesTabState();
}

class _SeriesTabState extends ConsumerState<SeriesTab> {
  final _searchCtrl = TextEditingController();
  final _debouncer = Debouncer();

  @override
  void dispose() {
    _debouncer.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openDetails(SeriesItem s) =>
      context.push('/series/${s.seriesId}', extra: s);

  @override
  Widget build(BuildContext context) {
    final categoryId = ref.watch(selectedSeriesCategoryProvider);
    final query = ref.watch(seriesSearchProvider);
    final browsing = categoryId != null || query.trim().isNotEmpty;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 8),
          _searchField(),
          const SizedBox(height: 10),
          _categoryChips(),
          const SizedBox(height: 4),
          Expanded(child: browsing ? _browseGrid() : _netflixHome()),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text('Séries',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          _sortMenu(),
        ],
      ),
    );
  }

  Widget _sortMenu() {
    final sort = ref.watch(seriesSortProvider);
    return PopupMenuButton<MediaSort>(
      tooltip: 'Trier',
      icon: const Icon(Icons.sort_rounded),
      initialValue: sort,
      onSelected: (s) => ref.read(seriesSortProvider.notifier).state = s,
      itemBuilder: (context) => [
        for (final s in MediaSort.values)
          PopupMenuItem(value: s, child: Text(s.label)),
      ],
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => _debouncer
            .run(() => ref.read(seriesSearchProvider.notifier).state = v),
        decoration: InputDecoration(
          hintText: 'Rechercher une série...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchCtrl.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _searchCtrl.clear();
                    _debouncer.runNow(() =>
                        ref.read(seriesSearchProvider.notifier).state = '');
                  },
                ),
          isDense: true,
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _categoryChips() {
    final categories = ref.watch(seriesCategoriesProvider);
    final selected = ref.watch(selectedSeriesCategoryProvider);

    return categories.when(
      data: (cats) => SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _chip('Accueil', null, selected, icon: Icons.home_rounded),
            const SizedBox(width: 8),
            _chip('Favoris', mediaFavCategoryId, selected,
                icon: Icons.favorite_rounded),
            const SizedBox(width: 8),
            _chip('Historique', mediaHistoryCategoryId, selected,
                icon: Icons.history_rounded),
            for (final c in cats) ...[
              const SizedBox(width: 8),
              _chip(c.name, c.id, selected),
            ],
          ],
        ),
      ),
      loading: () => const SizedBox(height: 44),
      error: (_, __) => const SizedBox(height: 44),
    );
  }

  Widget _chip(String label, String? id, String? selected,
      {IconData? icon}) {
    return ChoiceChip(
      avatar: icon != null ? Icon(icon, size: 16) : null,
      label: Text(label),
      selected: selected == id,
      onSelected: (_) =>
          ref.read(selectedSeriesCategoryProvider.notifier).state = id,
    );
  }

  // ---------------- Accueil Netflix ----------------

  Widget _netflixHome() {
    final all = ref.watch(allSeriesProvider);

    return all.when(
      data: (series) {
        if (series.isEmpty) {
          return const Center(child: Text('Aucune série disponible'));
        }
        final continueWatching = ref.watch(continueWatchingSeriesProvider);
        final favorites = ref.watch(seriesFavoritesProvider);
        final favSeries =
            series.where((s) => favorites.contains(s.seriesId)).toList();
        final recent = ref.watch(recentSeriesProvider);
        final topRated = ref.watch(topRatedSeriesProvider);
        final categories =
            ref.watch(seriesCategoriesProvider).valueOrNull ?? const [];
        final hero = topRated.isNotEmpty ? topRated.first : series.first;

        // Préchargement des images critiques de l'accueil.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ImagePrefetcher.warm(context, [
            hero.posterUrl,
            ...continueWatching.take(8).map((e) => e.posterUrl),
            ...recent.take(8).map((e) => e.posterUrl),
            ...topRated.take(8).map((e) => e.posterUrl),
          ]);
        });

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(allSeriesProvider),
          child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 8, bottom: 96),
          children: [
            HeroBanner(
              title: hero.name,
              imageUrl:
                  hero.backdropUrl.isNotEmpty ? hero.backdropUrl : hero.posterUrl,
              metadata: _metadata(hero),
              onPlay: () => _openDetails(hero),
              onDetails: () => _openDetails(hero),
            ),
            _seriesRow('Reprendre le visionnage', continueWatching),
            _seriesRow('Mes favoris', favSeries,
                onSeeAll: () => ref
                    .read(selectedSeriesCategoryProvider.notifier)
                    .state = mediaFavCategoryId),
            _seriesRow('Récemment ajoutées', recent),
            _seriesRow('Les mieux notées', topRated),
            for (final cat in categories.take(10))
              _seriesRow(
                cat.name,
                (ref.watch(seriesByCategoryProvider)[cat.id] ?? const [])
                    .take(20)
                    .toList(),
                onSeeAll: () => ref
                    .read(selectedSeriesCategoryProvider.notifier)
                    .state = cat.id,
              ),
          ],
        ),
        );
      },
      loading: () =>
          SkeletonGrid(columns: Responsive.gridColumns(context), withChips: false),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(allSeriesProvider),
      ),
    );
  }

  String _metadata(SeriesItem s) {
    final parts = <String>[
      if (s.year.isNotEmpty) s.year,
      if (s.genre.isNotEmpty) s.genre,
      if (Formatters.rating(s.rating) != '—') '★ ${Formatters.rating(s.rating)}',
    ];
    return parts.join(' • ');
  }

  Widget _seriesRow(String title, List<SeriesItem> series,
      {VoidCallback? onSeeAll}) {
    if (series.isEmpty) return const SizedBox.shrink();
    final favorites = ref.watch(seriesFavoritesProvider);
    return MediaRow(
      title: title,
      itemCount: series.length,
      onSeeAll: onSeeAll,
      itemBuilder: (context, i) {
        final s = series[i];
        return PosterCard(
          title: s.name,
          imageUrl: s.posterUrl,
          rating: Formatters.rating(s.rating),
          subtitle: s.year,
          isFavorite: favorites.contains(s.seriesId),
          onTap: () => _openDetails(s),
        );
      },
    );
  }

  // ---------------- Grille (navigation / recherche) ----------------

  Widget _browseGrid() {
    final filtered = ref.watch(filteredSeriesProvider);
    final columns = Responsive.gridColumns(context);
    final favorites = ref.watch(seriesFavoritesProvider);

    return filtered.when(
      data: (list) => list.isEmpty
          ? const Center(child: Text('Aucune série trouvée'))
          // Grille paginée : lazy loading par pages de 60 éléments.
          : PagedGrid<SeriesItem>(
              items: list,
              columns: columns,
              itemBuilder: (context, s) {
                return PosterCard(
                  title: s.name,
                  imageUrl: s.posterUrl,
                  rating: Formatters.rating(s.rating),
                  subtitle: s.year,
                  isFavorite: favorites.contains(s.seriesId),
                  onTap: () => _openDetails(s),
                );
              },
            ),
      loading: () => SkeletonGrid(columns: columns, withChips: false),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(allSeriesProvider),
      ),
    );
  }
}
