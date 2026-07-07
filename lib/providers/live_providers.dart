import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/epg_program.dart';
import '../models/live_channel.dart';
import '../services/epg_service.dart';
import 'app_providers.dart';
import 'auth_provider.dart';
import 'parental_providers.dart';
import 'profile_providers.dart';

/// ---------------- Constantes des pseudo-catégories ----------------
const String favCategoryId = '__favorites__';
const String recentCategoryId = '__recents__';

/// ---------------- Tri ----------------
enum LiveSort {
  byNumber('Numéro'),
  az('Nom A → Z'),
  za('Nom Z → A');

  final String label;
  const LiveSort(this.label);
}

/// ---------------- États UI ----------------
final liveSearchProvider = StateProvider<String>((ref) => '');
final liveSortProvider = StateProvider<LiveSort>((ref) => LiveSort.byNumber);
final selectedLiveCategoryProvider = StateProvider<String?>((ref) => null);

/// Chaîne sélectionnée pour l'aperçu (panneau latéral TV / desktop).
final previewChannelProvider = StateProvider<LiveChannel?>((ref) => null);

/// Coupe l'aperçu quand le lecteur plein écran est ouvert (évite le double son).
final previewEnabledProvider = StateProvider<bool>((ref) => true);

/// ---------------- Service EPG ----------------
final epgServiceProvider =
    Provider<EpgService>((ref) => EpgService(ref.watch(dioProvider)));

/// Programme actuel + suivant d'une chaîne (Xtream uniquement, sinon vide).
final epgNowNextProvider = FutureProvider.autoDispose
    .family<EpgNowNext, int>((ref, streamId) async {
  final creds = ref.watch(credentialsProvider);
  if (creds == null) return EpgNowNext.empty;
  final programs =
      await ref.watch(epgServiceProvider).shortEpg(creds, streamId);
  return EpgNowNext.fromPrograms(programs);
});

/// ---------------- Toutes les chaînes (mise en cache Hive) ----------------
/// Une seule requête pour toutes les chaînes ; le filtrage par catégorie,
/// recherche et tri se fait ensuite en mémoire → zapping et navigation
/// instantanés, à la TiviMate.
final _allLiveChannelsRawProvider =
    FutureProvider.autoDispose<List<LiveChannel>>((ref) async {
  // Comptes M3U : la playlist est déjà en mémoire.
  final playlist = ref.watch(activePlaylistProvider);
  if (playlist != null) return playlist.channels;

  final creds = ref.watch(credentialsProvider);
  final account = ref.watch(activeAccountProvider);
  if (creds == null || account == null) return const [];

  final cache = ref.watch(cacheServiceProvider);
  final cacheKey = 'live_all_${account.id}';

  // 1) Cache Hive (TTL global) → affichage instantané.
  final cached = cache.getJson(cacheKey);
  if (cached is String && cached.isNotEmpty) {
    try {
      final list = jsonDecode(cached) as List;
      final channels = list
          .whereType<Map>()
          .map((e) => LiveChannel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (channels.isNotEmpty) return channels;
    } catch (_) {/* cache corrompu : refetch */}
  }

  // 2) API puis mise en cache.
  final fresh =
      await ref.watch(contentRepositoryProvider).liveChannels(creds);
  await cache.putJson(
    cacheKey,
    jsonEncode([
      for (final c in fresh)
        {
          'stream_id': c.streamId,
          'name': c.name,
          'stream_icon': c.logoUrl,
          'category_id': c.categoryId,
          'num': c.number,
        }
    ]),
  );
  return fresh;
});

/// Chaînes visibles : catégories cachées (contrôle parental) exclues.
final allLiveChannelsProvider =
    FutureProvider.autoDispose<List<LiveChannel>>((ref) async {
  final channels = await ref.watch(_allLiveChannelsRawProvider.future);
  final hidden = ref.watch(hiddenCategoriesProvider('live'));
  if (hidden.isEmpty) return channels;
  return channels.where((c) => !hidden.contains(c.categoryId)).toList();
});

/// ---------------- Favoris (persistés par compte) ----------------
class LiveFavoritesNotifier extends Notifier<Set<int>> {
  String get _prefix => 'fav_live_${ref.read(dataScopeProvider)}_';

  @override
  Set<int> build() {
    ref.watch(dataScopeProvider); // recharge au changement compte/profil
    final cache = ref.watch(cacheServiceProvider);
    final prefix = _prefix;
    return {
      for (final key in cache.allFavorites())
        if (key.startsWith(prefix))
          int.tryParse(key.substring(prefix.length)) ?? -1
    }..remove(-1);
  }

  Future<void> toggle(int streamId) async {
    await ref
        .read(cacheServiceProvider)
        .toggleFavorite('$_prefix$streamId');
    final updated = {...state};
    updated.contains(streamId)
        ? updated.remove(streamId)
        : updated.add(streamId);
    state = updated;
  }
}

final liveFavoritesProvider =
    NotifierProvider<LiveFavoritesNotifier, Set<int>>(
        LiveFavoritesNotifier.new);

/// ---------------- Chaînes récentes + reprise (persistées par compte) ----------------
class LiveRecentsNotifier extends Notifier<List<int>> {
  static const _maxRecents = 15;

  String get _key => 'recent_live_${ref.read(dataScopeProvider)}';

  @override
  List<int> build() {
    ref.watch(dataScopeProvider); // recharge au changement compte/profil
    final raw = ref.watch(cacheServiceProvider).getSetting(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => int.tryParse(e.toString()) ?? -1)
          .where((id) => id > 0)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Enregistre une lecture : passe la chaîne en tête des récents
  /// (sert aussi de point de reprise).
  Future<void> registerWatch(int streamId) async {
    final updated = [streamId, ...state.where((id) => id != streamId)];
    if (updated.length > _maxRecents) updated.removeRange(_maxRecents, updated.length);
    state = updated;
    await ref
        .read(cacheServiceProvider)
        .putSetting(_key, jsonEncode(updated));
  }
}

final liveRecentsProvider =
    NotifierProvider<LiveRecentsNotifier, List<int>>(LiveRecentsNotifier.new);

/// Dernière chaîne regardée (reprise de lecture), résolue dans la liste.
final resumeChannelProvider = Provider.autoDispose<LiveChannel?>((ref) {
  final recents = ref.watch(liveRecentsProvider);
  if (recents.isEmpty) return null;
  final channels = ref.watch(allLiveChannelsProvider).valueOrNull;
  if (channels == null) return null;
  for (final c in channels) {
    if (c.streamId == recents.first) return c;
  }
  return null;
});

/// ---------------- Liste filtrée (catégorie + recherche + tri) ----------------
final filteredLiveChannelsProvider =
    Provider.autoDispose<AsyncValue<List<LiveChannel>>>((ref) {
  final channelsAsync = ref.watch(allLiveChannelsProvider);
  final categoryId = ref.watch(selectedLiveCategoryProvider);
  final query = ref.watch(liveSearchProvider).trim().toLowerCase();
  final sort = ref.watch(liveSortProvider);
  final favorites = ref.watch(liveFavoritesProvider);
  final recents = ref.watch(liveRecentsProvider);

  return channelsAsync.whenData((all) {
    // Récents : ordre chronologique conservé, pas de tri.
    if (categoryId == recentCategoryId) {
      final byId = {for (final c in all) c.streamId: c};
      return [
        for (final id in recents)
          if (byId[id] != null &&
              (query.isEmpty || byId[id]!.name.toLowerCase().contains(query)))
            byId[id]!
      ];
    }

    Iterable<LiveChannel> list = all;
    if (categoryId == favCategoryId) {
      list = list.where((c) => favorites.contains(c.streamId));
    } else if (categoryId != null) {
      list = list.where((c) => c.categoryId == categoryId);
    }
    if (query.isNotEmpty) {
      list = list.where((c) => c.name.toLowerCase().contains(query));
    }

    final result = list.toList();
    switch (sort) {
      case LiveSort.byNumber:
        result.sort((a, b) => a.number != b.number
            ? a.number.compareTo(b.number)
            : a.name.compareTo(b.name));
      case LiveSort.az:
        result.sort((a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case LiveSort.za:
        result.sort((a, b) =>
            b.name.toLowerCase().compareTo(a.name.toLowerCase()));
    }
    return result;
  });
});

/// ---------------- Résolution de l'URL d'une chaîne ----------------
/// M3U : URL directe ; Xtream/MAC résolu : URL construite.
final liveUrlResolverProvider = Provider<String? Function(LiveChannel)>((ref) {
  final creds = ref.watch(credentialsProvider);
  return (channel) => channel.directUrl ?? creds?.liveStreamUrl(channel.streamId);
});
