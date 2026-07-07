import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/perf/image_prefetcher.dart';
import '../../core/utils/debouncer.dart';
import '../../models/vod_item.dart';
import '../../models/watch_progress.dart';
import '../../providers/auth_provider.dart';
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
import 'player_screen.dart';

/// Onglet Films — style Netflix :
/// - Accueil : bannière héro + rangées (Continuer, Favoris, Récents, Top, catégories)
/// - Navigation : recherche + filtres (catégorie, tri) + grille d'affiches.
class MoviesTab extends ConsumerStatefulWidget {
  const MoviesTab({super.key});

  @override
  ConsumerState<MoviesTab> createState() => _MoviesTabState();
}

class _MoviesTabState extends ConsumerState<MoviesTab> {
  final _searchCtrl = TextEditingController();

  /// Anti-rebond : le filtre (et donc la reconstruction de la grille) ne
  /// s'exécute que 300 ms après la dernière frappe.
  final _debouncer = Debouncer();

  @override
  void dispose() {
    _debouncer.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---------------- Navigation ----------------

  void _openDetails(VodItem movie) =>
      context.push('/movie/${movie.streamId}', extra: movie);

  void _play(VodItem movie, {Duration? startAt}) {
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

  // ---------------- Build ----------------

  @override
  Widget build(BuildContext context) {
    final categoryId = ref.watch(selectedVodCategoryProvider);
    final query = ref.watch(vodSearchProvider);
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
            child: Text('Films',
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
    final sort = ref.watch(vodSortProvider);
    return PopupMenuButton<MediaSort>(
      tooltip: 'Trier',
      icon: const Icon(Icons.sort_rounded),
      initialValue: sort,
      onSelected: (s) => ref.read(vodSortProvider.notifier).state = s,
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
            .run(() => ref.read(vodSearchProvider.notifier).state = v),
        decoration: InputDecoration(
          hintText: 'Rechercher un film...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchCtrl.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _searchCtrl.clear();
                    _debouncer.runNow(() =>
                        ref.read(vodSearchProvider.notifier).state = '');
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
    final categories = ref.watch(vodCategoriesProvider);
    final selected = ref.watch(selectedVodCategoryProvider);

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
          ref.read(selectedVodCategoryProvider.notifier).state = id,
    );
  }

  // ---------------- Accueil Netflix ----------------

  Widget _netflixHome() {
    final all = ref.watch(allMoviesProvider);

    return all.when(
      data: (movies) {
        if (movies.isEmpty) {
          return const Center(child: Text('Aucun film disponible'));
        }
        final continueWatching = ref.watch(continueWatchingMoviesProvider);
        final favorites = ref.watch(vodFavoritesProvider);
        final favMovies =
            movies.where((m) => favorites.contains(m.streamId)).toList();
        final recent = ref.watch(recentMoviesProvider);
        final topRated = ref.watch(topRatedMoviesProvider);
        final categories =
            ref.watch(vodCategoriesProvider).valueOrNull ?? const [];
        final hero = topRated.isNotEmpty ? topRated.first : movies.first;

        // Préchargement des images critiques : bannière + premières affiches
        // des rangées visibles (affichage instantané au premier scroll).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ImagePrefetcher.warm(context, [
            hero.posterUrl,
            ...continueWatching.take(8).map((m) => m.posterUrl),
            ...recent.take(8).map((m) => m.posterUrl),
            ...topRated.take(8).map((m) => m.posterUrl),
          ]);
        });

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(allMoviesProvider),
          child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 8, bottom: 96),
          children: [
            HeroBanner(
              title: hero.name,
              imageUrl: hero.posterUrl,
              metadata: _metadata(hero),
              onPlay: () => _play(hero),
              onDetails: () => _openDetails(hero),
            ),
            _movieRow('Continuer la lecture', continueWatching,
                showProgress: true),
            _movieRow('Mes favoris', favMovies,
                onSeeAll: () => ref
                    .read(selectedVodCategoryProvider.notifier)
                    .state = mediaFavCategoryId),
            _movieRow('Récemment ajoutés', recent),
            _movieRow('Les mieux notés', topRated),
            // Une rangée par catégorie (limité pour rester fluide).
            // Regroupement mémoïsé : pas de re-filtrage du catalogue complet.
            for (final cat in categories.take(10))
              _movieRow(
                cat.name,
                (ref.watch(moviesByCategoryProvider)[cat.id] ?? const [])
                    .take(20)
                    .toList(),
                onSeeAll: () => ref
                    .read(selectedVodCategoryProvider.notifier)
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
        onRetry: () => ref.invalidate(allMoviesProvider),
      ),
    );
  }

  String _metadata(VodItem m) {
    final parts = <String>[
      if (m.year.isNotEmpty) m.year,
      if (m.genre.isNotEmpty) m.genre,
      if (Formatters.rating(m.rating) != '—') '★ ${Formatters.rating(m.rating)}',
    ];
    return parts.join(' • ');
  }

  Widget _movieRow(String title, List<VodItem> movies,
      {VoidCallback? onSeeAll, bool showProgress = false}) {
    if (movies.isEmpty) return const SizedBox.shrink();
    final progress = ref.watch(watchProgressProvider);
    final favorites = ref.watch(vodFavoritesProvider);
    return MediaRow(
      title: title,
      itemCount: movies.length,
      onSeeAll: onSeeAll,
      itemBuilder: (context, i) {
        final m = movies[i];
        final p = progress[WatchProgress.vodKey(m.streamId)];
        return PosterCard(
          title: m.name,
          imageUrl: m.posterUrl,
          rating: Formatters.rating(m.rating),
          subtitle: m.year,
          isFavorite: favorites.contains(m.streamId),
          progress: showProgress || (p?.inProgress ?? false) ? p?.ratio : null,
          onTap: () => _openDetails(m),
        );
      },
    );
  }

  // ---------------- Grille (navigation / recherche) ----------------

  Widget _browseGrid() {
    final filtered = ref.watch(filteredMoviesProvider);
    final columns = Responsive.gridColumns(context);
    final progress = ref.watch(watchProgressProvider);
    final favorites = ref.watch(vodFavoritesProvider);

    return filtered.when(
      data: (list) => list.isEmpty
          ? const Center(child: Text('Aucun film trouvé'))
          // Grille paginée : rendu incrémental par pages de 60 éléments
          // (lazy loading) — indispensable sur des catalogues de 10 000+.
          : PagedGrid<VodItem>(
              items: list,
              columns: columns,
              itemBuilder: (context, m) {
                final p = progress[WatchProgress.vodKey(m.streamId)];
                return PosterCard(
                  title: m.name,
                  imageUrl: m.posterUrl,
                  rating: Formatters.rating(m.rating),
                  subtitle: m.year,
                  isFavorite: favorites.contains(m.streamId),
                  progress: (p?.inProgress ?? false) ? p?.ratio : null,
                  onTap: () => _openDetails(m),
                );
              },
            ),
      loading: () => SkeletonGrid(columns: columns, withChips: false),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(allMoviesProvider),
      ),
    );
  }
}
