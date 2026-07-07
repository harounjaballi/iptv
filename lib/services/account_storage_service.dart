import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/constants/app_constants.dart';
import '../models/iptv_account.dart';

/// Stockage chiffré des comptes IPTV (flutter_secure_storage).
/// Gère plusieurs comptes + le compte actif, avec migration automatique
/// de l'ancien format v1 (compte Xtream unique).
class AccountStorageService {
  final FlutterSecureStorage _storage;

  const AccountStorageService(
      [this._storage = const FlutterSecureStorage()]);

  // ---------- Lecture ----------

  /// Tous les comptes enregistrés, du plus récemment utilisé au plus ancien.
  Future<List<IptvAccount>> getAccounts() async {
    await _migrateLegacyIfNeeded();
    final raw = await _storage.read(key: AppConstants.keyAccounts);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      final accounts = list
          .whereType<Map>()
          .map((e) => IptvAccount.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      accounts.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
      return accounts;
    } catch (_) {
      return const [];
    }
  }

  Future<String?> getActiveAccountId() =>
      _storage.read(key: AppConstants.keyActiveAccountId);

  Future<IptvAccount?> getActiveAccount() async {
    final id = await getActiveAccountId();
    if (id == null) return null;
    final accounts = await getAccounts();
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  // ---------- Écriture ----------

  /// Ajoute ou met à jour un compte (clé = id).
  Future<void> upsertAccount(IptvAccount account) async {
    final accounts = await getAccounts();
    final updated = [
      account,
      ...accounts.where((a) => a.id != account.id),
    ];
    await _saveAll(updated);
  }

  Future<void> setActiveAccount(String? id) async {
    if (id == null) {
      await _storage.delete(key: AppConstants.keyActiveAccountId);
    } else {
      await _storage.write(key: AppConstants.keyActiveAccountId, value: id);
    }
  }

  /// Supprime un compte ; renvoie true si c'était le compte actif.
  Future<bool> deleteAccount(String id) async {
    final accounts = await getAccounts();
    await _saveAll(accounts.where((a) => a.id != id).toList());
    final activeId = await getActiveAccountId();
    if (activeId == id) {
      await setActiveAccount(null);
      return true;
    }
    return false;
  }

  Future<void> _saveAll(List<IptvAccount> accounts) => _storage.write(
        key: AppConstants.keyAccounts,
        value: jsonEncode(accounts.map((a) => a.toJson()).toList()),
      );

  // ---------- Migration v1 → v2 ----------

  /// Si d'anciens identifiants Xtream (v1, compte unique) existent,
  /// les convertit en IptvAccount actif puis supprime les anciennes clés.
  Future<void> _migrateLegacyIfNeeded() async {
    final host = await _storage.read(key: AppConstants.legacyKeyHost);
    if (host == null) return;
    final user = await _storage.read(key: AppConstants.legacyKeyUsername);
    final pass = await _storage.read(key: AppConstants.legacyKeyPassword);

    if (user != null && pass != null) {
      final raw = await _storage.read(key: AppConstants.keyAccounts);
      final existing = (raw == null || raw.isEmpty)
          ? <IptvAccount>[]
          : (jsonDecode(raw) as List)
              .whereType<Map>()
              .map((e) => IptvAccount.fromJson(Map<String, dynamic>.from(e)))
              .toList();
      final migrated = IptvAccount.xtream(
          name: user, host: host, username: user, password: pass);
      await _saveAll([migrated, ...existing]);
      final activeId = await getActiveAccountId();
      if (activeId == null) await setActiveAccount(migrated.id);
    }

    await _storage.delete(key: AppConstants.legacyKeyHost);
    await _storage.delete(key: AppConstants.legacyKeyUsername);
    await _storage.delete(key: AppConstants.legacyKeyPassword);
  }
}
