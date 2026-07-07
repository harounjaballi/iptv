import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import 'app_providers.dart';
import 'auth_provider.dart';

/// ---------------- Profils utilisateurs (globaux, façon Netflix) ----------------
class ProfilesNotifier extends Notifier<List<UserProfile>> {
  static const _key = 'user_profiles';

  @override
  List<UserProfile> build() {
    final raw = ref.read(cacheServiceProvider).getSetting(_key);
    if (raw == null || raw.isEmpty) return const [UserProfile.main];
    try {
      final list = (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => UserProfile.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      // Le profil principal existe toujours (rétro-compatibilité).
      if (!list.any((p) => p.id == UserProfile.main.id)) {
        list.insert(0, UserProfile.main);
      }
      return list;
    } catch (_) {
      return const [UserProfile.main];
    }
  }

  Future<void> _persist(List<UserProfile> profiles) async {
    state = profiles;
    await ref.read(cacheServiceProvider).putSetting(
        _key, jsonEncode([for (final p in profiles) p.toJson()]));
  }

  Future<void> add(String name, {int colorIndex = 0, bool isKids = false}) =>
      _persist([
        ...state,
        UserProfile(
          id: DateTime.now().millisecondsSinceEpoch.toRadixString(36),
          name: name,
          colorIndex: colorIndex,
          isKids: isKids,
        ),
      ]);

  Future<void> update(UserProfile profile) => _persist([
        for (final p in state) p.id == profile.id ? profile : p,
      ]);

  /// Supprime un profil (jamais le principal). Si c'était le profil actif,
  /// bascule sur le principal.
  Future<void> remove(String id) async {
    if (id == UserProfile.main.id) return;
    await _persist(state.where((p) => p.id != id).toList());
    if (ref.read(activeProfileIdProvider) == id) {
      await ref
          .read(activeProfileIdProvider.notifier)
          .select(UserProfile.main.id);
    }
  }
}

final profilesProvider =
    NotifierProvider<ProfilesNotifier, List<UserProfile>>(ProfilesNotifier.new);

/// ---------------- Profil actif ----------------
class ActiveProfileIdNotifier extends Notifier<String> {
  static const _key = 'active_profile_id';

  @override
  String build() =>
      ref.read(cacheServiceProvider).getSetting(_key) ?? UserProfile.main.id;

  Future<void> select(String id) async {
    state = id;
    await ref.read(cacheServiceProvider).putSetting(_key, id);
  }
}

final activeProfileIdProvider =
    NotifierProvider<ActiveProfileIdNotifier, String>(
        ActiveProfileIdNotifier.new);

final activeProfileProvider = Provider<UserProfile>((ref) {
  final id = ref.watch(activeProfileIdProvider);
  final profiles = ref.watch(profilesProvider);
  return profiles.firstWhere((p) => p.id == id,
      orElse: () => UserProfile.main);
});

/// ---------------- Portée des données ----------------
/// Les favoris, l'historique, la progression et les statistiques sont
/// isolés par compte ET par profil. Le profil principal conserve les
/// clés historiques (compte seul) pour ne perdre aucune donnée existante.
final dataScopeProvider = Provider<String>((ref) {
  final account = ref.watch(activeAccountProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final base = account?.id ?? 'none';
  return profileId == UserProfile.main.id ? base : '${base}__$profileId';
});
