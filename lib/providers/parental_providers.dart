import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';
import 'auth_provider.dart';

/// ---------------- Code PIN parental (haché SHA-256, global) ----------------
class ParentalPinNotifier extends Notifier<String?> {
  static const _key = 'parental_pin_hash';

  @override
  String? build() => ref.read(cacheServiceProvider).getSetting(_key);

  static String _hash(String pin) =>
      sha256.convert(utf8.encode('piptv:$pin')).toString();

  bool get isSet => state != null && state!.isNotEmpty;

  bool verify(String pin) => isSet && state == _hash(pin);

  Future<void> setPin(String pin) async {
    state = _hash(pin);
    await ref.read(cacheServiceProvider).putSetting(_key, state!);
  }

  Future<void> clear() async {
    state = null;
    await ref.read(cacheServiceProvider).deleteSetting(_key);
  }
}

final parentalPinProvider =
    NotifierProvider<ParentalPinNotifier, String?>(ParentalPinNotifier.new);

/// Le contrôle parental est actif dès qu'un PIN est défini.
final parentalEnabledProvider = Provider<bool>(
    (ref) => (ref.watch(parentalPinProvider) ?? '').isNotEmpty);

/// ---------------- Catégories cachées (par type et par compte) ----------------
/// type ∈ {'live', 'vod', 'series'} — cachées partout : onglets,
/// rangées Netflix, recherche globale et recommandations.
class HiddenCategoriesNotifier extends FamilyNotifier<Set<String>, String> {
  String get _key {
    final account = ref.read(activeAccountProvider);
    return 'hidden_cats_${arg}_${account?.id ?? 'none'}';
  }

  @override
  Set<String> build(String arg) {
    ref.watch(activeAccountProvider);
    final raw = ref.watch(cacheServiceProvider).getSetting(_key);
    if (raw == null || raw.isEmpty) return const {};
    try {
      return (jsonDecode(raw) as List).map((e) => e.toString()).toSet();
    } catch (_) {
      return const {};
    }
  }

  Future<void> toggle(String categoryId) async {
    final updated = {...state};
    updated.contains(categoryId)
        ? updated.remove(categoryId)
        : updated.add(categoryId);
    state = updated;
    await ref
        .read(cacheServiceProvider)
        .putSetting(_key, jsonEncode(updated.toList()));
  }
}

final hiddenCategoriesProvider =
    NotifierProvider.family<HiddenCategoriesNotifier, Set<String>, String>(
        HiddenCategoriesNotifier.new);
