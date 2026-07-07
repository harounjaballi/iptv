import 'package:cached_network_image/cached_network_image.dart';
import '../../core/cache/app_cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/debouncer.dart';
import '../../models/live_channel.dart';
import '../../providers/live_providers.dart';
import '../../providers/media_providers.dart';
import '../../providers/settings_providers.dart';
import '../../utils/formatters.dart';
import '../../widgets/media_row.dart';
import '../../widgets/poster_card.dart';
import 'live_player_screen.dart';

/// Requête de la recherche globale.
final globalSearchProvider = StateProvider<String>((ref) => '');

/// Recherche globale : chaînes TV, films et séries en un seul endroit.
/// Respecte les catégories cachées (contrôle parental).
class GlobalSearchTab extends ConsumerStatefulWidget {
  const GlobalSearchTab({super.key});

  @override
  ConsumerState<GlobalSearchTab> createState() => _GlobalSearchTabState();
}

class _GlobalSearchTabState extends ConsumerState<GlobalSearchTab> {
  final _controller = TextEditingController();

  /// Anti-rebond : la recherche parcourt les 3 catalogues complets
  /// (chaînes + films + séries, souvent 20 000+ éléments) — on ne la
  /// relance que 300 ms après la dernière frappe.
  final _debouncer = Debouncer();

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(globalSearchProvider);
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _openChannel(List<LiveChannel> results, int index) {
    context.push('/live-player',
        extra: LivePlayerArgs(channels: results, initialIndex: index));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final query = ref.watch(globalSearchProvider).trim().toLowerCase();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(l10n.search,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _controller,
              autofocus: false,
              onChanged: (v) => _debouncer.run(
                  () => ref.read(globalSearchProvider.notifier).state = v),
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _controller.clear();
                          _debouncer.runNow(() => ref
                              .read(globalSearchProvider.notifier)
                              .state = '');
                        },
                      ),
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: query.length < 2
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.travel_explore_rounded,
                            size: 56, color: Colors.white24),
                        const SizedBox(height: 12),
                        Text(l10n.searchEmpty,
                            style:
                                const TextStyle(color: Colors.white54)),
                      ],
                    ),
                  )
                : _results(query, l10n),
          ),
        ],
      ),
    );
  }

  Widget _results(String query, dynamic l10n) {
    final channels = (ref.watch(allLiveChannelsProvider).valueOrNull ??
            const <LiveChannel>[])
        .where((c) => c.name.toLowerCase().contains(query))
        .take(20)
        .toList();
    final movies = (ref.watch(allMoviesProvider).valueOrNull ?? const [])
        .where((m) => m.name.toLowerCase().contains(query))
        .take(15)
        .toList();
    final series = (ref.watch(allSeriesProvider).valueOrNull ?? const [])
        .where((s) => s.name.toLowerCase().contains(query))
        .take(15)
        .toList();

    if (channels.isEmpty && movies.isEmpty && series.isEmpty) {
      return Center(child: Text(l10n.searchNoResults));
    }

    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        // ---------- Chaînes TV ----------
        if (channels.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('${l10n.channels} (${channels.length})',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          for (var i = 0; i < channels.length; i++)
            ListTile(
              leading: SizedBox(
                width: 44,
                height: 44,
                child: channels[i].logoUrl.isEmpty
                    ? CircleAvatar(
                        backgroundColor: scheme.surfaceContainerHighest,
                        child: const Icon(Icons.live_tv_rounded, size: 20))
                    : CachedNetworkImage(
                        imageUrl: channels[i].logoUrl,
                        cacheManager: AppCacheManager.instance,
                        memCacheWidth: 480, // ~160dp × 3 (compression mémoire)
                        fit: BoxFit.contain,
                        errorWidget: (_, __, ___) => CircleAvatar(
                            backgroundColor:
                                scheme.surfaceContainerHighest,
                            child: const Icon(Icons.live_tv_rounded,
                                size: 20)),
                      ),
              ),
              title: Text(channels[i].name,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.play_arrow_rounded),
              onTap: () => _openChannel(channels, i),
            ),
        ],
        // ---------- Films ----------
        if (movies.isNotEmpty)
          MediaRow(
            title: '${l10n.movies} (${movies.length})',
            itemCount: movies.length,
            itemBuilder: (context, i) {
              final m = movies[i];
              return PosterCard(
                title: m.name,
                imageUrl: m.posterUrl,
                rating: Formatters.rating(m.rating),
                subtitle: m.year,
                onTap: () => context.push('/movie/${m.streamId}', extra: m),
              );
            },
          ),
        // ---------- Séries ----------
        if (series.isNotEmpty)
          MediaRow(
            title: '${l10n.series} (${series.length})',
            itemCount: series.length,
            itemBuilder: (context, i) {
              final s = series[i];
              return PosterCard(
                title: s.name,
                imageUrl: s.posterUrl,
                rating: Formatters.rating(s.rating),
                subtitle: s.year,
                onTap: () =>
                    context.push('/series/${s.seriesId}', extra: s),
              );
            },
          ),
      ],
    );
  }
}
