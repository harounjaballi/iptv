import 'package:cached_network_image/cached_network_image.dart';
import '../../core/cache/app_cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/debouncer.dart';
import '../../models/category_model.dart';
import '../../models/live_channel.dart';
import '../../providers/content_providers.dart';
import '../../providers/live_providers.dart';
import '../../themes/app_colors.dart';
import '../../widgets/channel_list_tile.dart';
import '../../widgets/channel_preview.dart';
import '../../widgets/epg_now_next_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/skeleton_loader.dart';
import 'live_player_screen.dart';

/// Onglet TV en direct — module complet :
/// catégories (+ Favoris / Récents), recherche, tri, reprise de lecture,
/// EPG en ligne, aperçu de chaîne (écrans larges) et lecteur plein écran
/// avec zapping ultra rapide.
class LiveTab extends ConsumerStatefulWidget {
  const LiveTab({super.key});

  @override
  ConsumerState<LiveTab> createState() => _LiveTabState();
}

class _LiveTabState extends ConsumerState<LiveTab> {
  final _searchCtrl = TextEditingController();
  final _debouncer = Debouncer();

  @override
  void dispose() {
    _debouncer.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openPlayer(List<LiveChannel> list, int index) async {
    await context.push(
      '/live-player',
      extra: LivePlayerArgs(channels: list, initialIndex: index),
    );
    // Réactive l'aperçu au retour du plein écran.
    if (mounted) ref.read(previewEnabledProvider.notifier).state = true;
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return SafeArea(
      child: wide ? _buildWideLayout() : _buildMobileLayout(),
    );
  }

  // ================= MOBILE =================

  Widget _buildMobileLayout() {
    final filtered = ref.watch(filteredLiveChannelsProvider);
    final resume = ref.watch(resumeChannelProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text('TV en direct',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              _sortMenu(),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _searchField(),
        const SizedBox(height: 10),
        _categoryChips(),
        if (resume != null) _resumeBanner(resume),
        const SizedBox(height: 4),
        Expanded(
          child: filtered.when(
            data: (list) => list.isEmpty
                ? const Center(
                    child: Text('Aucune chaîne trouvée',
                        style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: list.length,
                    itemExtent: 72,
                    itemBuilder: (context, i) => ChannelListTile(
                      channel: list[i],
                      onTap: () => _openPlayer(list, i),
                    ),
                  ),
            loading: () =>
                const SkeletonGrid(columns: 1, aspectRatio: 6, withChips: false),
            error: (e, _) => ErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(allLiveChannelsProvider),
            ),
          ),
        ),
      ],
    );
  }

  // ================= LARGE / TV : 3 panneaux =================

  Widget _buildWideLayout() {
    final filtered = ref.watch(filteredLiveChannelsProvider);
    final preview = ref.watch(previewChannelProvider);
    final resume = ref.watch(resumeChannelProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- Panneau catégories ----
        SizedBox(width: 232, child: _categoryPanel()),
        const VerticalDivider(width: 1),

        // ---- Panneau chaînes ----
        Expanded(
          flex: 5,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                child: Row(
                  children: [
                    Expanded(child: _searchField(dense: true)),
                    _sortMenu(),
                  ],
                ),
              ),
              if (resume != null) _resumeBanner(resume),
              const SizedBox(height: 4),
              Expanded(
                child: filtered.when(
                  data: (list) => list.isEmpty
                      ? const Center(
                          child: Text('Aucune chaîne trouvée',
                              style: TextStyle(color: Colors.white54)))
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: list.length,
                          itemExtent: 72,
                          itemBuilder: (context, i) {
                            final channel = list[i];
                            final selected =
                                preview?.streamId == channel.streamId;
                            return ChannelListTile(
                              channel: channel,
                              selected: selected,
                              onTap: () {
                                if (selected) {
                                  _openPlayer(list, i);
                                } else {
                                  ref
                                      .read(previewChannelProvider.notifier)
                                      .state = channel;
                                }
                              },
                              onFocus: (focused) {
                                // Sur TV : le focus D-Pad met à jour l'aperçu.
                                if (focused) {
                                  ref
                                      .read(previewChannelProvider.notifier)
                                      .state = channel;
                                }
                              },
                            );
                          },
                        ),
                  loading: () => const SkeletonGrid(
                      columns: 1, aspectRatio: 6, withChips: false),
                  error: (e, _) => ErrorView(
                    message: e.toString(),
                    onRetry: () => ref.invalidate(allLiveChannelsProvider),
                  ),
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),

        // ---- Panneau aperçu + EPG ----
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: preview == null
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.live_tv, color: Colors.white24, size: 64),
                        SizedBox(height: 12),
                        Text('Sélectionnez une chaîne pour l\'aperçu',
                            style: TextStyle(color: Colors.white38)),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ChannelPreview(channel: preview),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            if (preview.logoUrl.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: CachedNetworkImage(
                                      imageUrl: preview.logoUrl,
                                      cacheManager: AppCacheManager.instance,
                                      memCacheWidth: 360, // ~120dp × 3 (compression mémoire)
                                      fit: BoxFit.contain),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                preview.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                            Consumer(builder: (context, ref, _) {
                              final fav = ref
                                  .watch(liveFavoritesProvider)
                                  .contains(preview.streamId);
                              return IconButton(
                                onPressed: () => ref
                                    .read(liveFavoritesProvider.notifier)
                                    .toggle(preview.streamId),
                                icon: Icon(
                                  fav
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color:
                                      fav ? Colors.amber : Colors.white54,
                                  size: 28,
                                ),
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 12),
                        EpgNowNextView(streamId: preview.streamId),
                        const SizedBox(height: 20),
                        GradientButton(
                          label: 'Regarder en plein écran',
                          icon: Icons.play_arrow_rounded,
                          onPressed: () {
                            final list = ref
                                .read(filteredLiveChannelsProvider)
                                .valueOrNull;
                            if (list == null || list.isEmpty) return;
                            var index = list.indexWhere(
                                (c) => c.streamId == preview.streamId);
                            if (index < 0) index = 0;
                            _openPlayer(list, index);
                          },
                        ),
                      ],
                    ).animate().fadeIn(duration: 220.ms),
                  ),
          ),
        ),
      ],
    );
  }

  // ================= Éléments partagés =================

  Widget _searchField({bool dense = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 16),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => _debouncer
            .run(() => ref.read(liveSearchProvider.notifier).state = v),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Rechercher une chaîne…',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Colors.white38),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchCtrl,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white38, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      _debouncer.runNow(() =>
                          ref.read(liveSearchProvider.notifier).state = '');
                    },
                  ),
          ),
          isDense: dense,
          fillColor: Colors.white.withValues(alpha: 0.06),
        ),
      ),
    );
  }

  Widget _sortMenu() {
    final sort = ref.watch(liveSortProvider);
    return PopupMenuButton<LiveSort>(
      tooltip: 'Trier',
      icon: const Icon(Icons.sort_rounded, color: Colors.white70),
      initialValue: sort,
      onSelected: (s) => ref.read(liveSortProvider.notifier).state = s,
      itemBuilder: (context) => [
        for (final s in LiveSort.values)
          PopupMenuItem(
            value: s,
            child: Row(
              children: [
                if (s == sort)
                  const Icon(Icons.check, size: 16)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(s.label),
              ],
            ),
          ),
      ],
    );
  }

  List<CategoryModel> _pseudoCategories() => const [
        CategoryModel(id: favCategoryId, name: '★ Favoris'),
        CategoryModel(id: recentCategoryId, name: '🕒 Récents'),
      ];

  Widget _categoryChips() {
    final categories = ref.watch(liveCategoriesProvider);
    final selected = ref.watch(selectedLiveCategoryProvider);
    return SizedBox(
      height: 42,
      child: categories.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (cats) {
          final all = [..._pseudoCategories(), ...cats];
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: all.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final isAll = index == 0;
              final cat = isAll ? null : all[index - 1];
              final isSelected =
                  isAll ? selected == null : selected == cat!.id;
              return ChoiceChip(
                label: Text(isAll ? 'Toutes' : cat!.name),
                selected: isSelected,
                onSelected: (_) => ref
                    .read(selectedLiveCategoryProvider.notifier)
                    .state = isAll ? null : cat!.id,
              );
            },
          );
        },
      ),
    );
  }

  Widget _categoryPanel() {
    final categories = ref.watch(liveCategoriesProvider);
    final selected = ref.watch(selectedLiveCategoryProvider);

    Widget tile(String? id, String name, {IconData? icon}) {
      final isSelected = selected == id;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: ListTile(
          dense: true,
          selected: isSelected,
          selectedTileColor: AppColors.seed.withValues(alpha: 0.22),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: icon != null
              ? Icon(icon,
                  size: 18,
                  color: isSelected ? AppColors.cyan : Colors.white38)
              : null,
          title: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          onTap: () =>
              ref.read(selectedLiveCategoryProvider.notifier).state = id,
        ),
      );
    }

    return categories.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
      data: (cats) => ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          tile(null, 'Toutes les chaînes', icon: Icons.apps),
          tile(favCategoryId, 'Favoris', icon: Icons.star_rounded),
          tile(recentCategoryId, 'Récents', icon: Icons.history),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Divider(height: 1),
          ),
          for (final c in cats) tile(c.id, c.name),
        ],
      ),
    );
  }

  Widget _resumeBanner(LiveChannel channel) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          final list =
              ref.read(filteredLiveChannelsProvider).valueOrNull ?? [channel];
          var index =
              list.indexWhere((c) => c.streamId == channel.streamId);
          List<LiveChannel> playlist = list;
          if (index < 0) {
            playlist = [channel];
            index = 0;
          }
          _openPlayer(playlist, index);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [
                AppColors.seed.withValues(alpha: 0.35),
                AppColors.accent.withValues(alpha: 0.25),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.play_circle_fill_rounded,
                  color: Colors.white, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Reprendre la lecture',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 10.5)),
                    Text(
                      channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.15),
      ),
    );
  }
}
