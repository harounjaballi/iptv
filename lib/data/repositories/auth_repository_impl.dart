import 'dart:io';

import '../../core/errors/app_exception.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../models/account_info.dart';
import '../../models/iptv_account.dart';
import '../../services/account_storage_service.dart';
import '../../services/cache_service.dart';
import '../../services/m3u_parser_service.dart';
import '../../services/mac_activation_service.dart';
import '../../services/xtream_api_service.dart';

/// Implémentation : valide chaque type de compte auprès de sa source,
/// gère le stockage multi-comptes et le repli hors ligne (M3U en cache).
class AuthRepositoryImpl implements AuthRepository {
  final XtreamApiService _xtreamApi;
  final M3uParserService _m3uParser;
  final MacActivationService _macActivation;
  final AccountStorageService _accounts;
  final CacheService _cache;

  const AuthRepositoryImpl(
    this._xtreamApi,
    this._m3uParser,
    this._macActivation,
    this._accounts,
    this._cache,
  );

  // ---------- Validation par type ----------

  @override
  Future<ConnectionResult> validate(IptvAccount account) async {
    switch (account.type) {
      case AccountSourceType.xtream:
        return _validateXtream(account);
      case AccountSourceType.m3uUrl:
        return _validateM3uUrl(account);
      case AccountSourceType.m3uFile:
        return _validateM3uFile(account);
      case AccountSourceType.mac:
        return _validateMac(account);
    }
  }

  Future<ConnectionResult> _validateXtream(IptvAccount account) async {
    final creds = account.xtreamCredentials;
    if (creds == null) {
      throw const AuthException('Identifiants Xtream incomplets.');
    }
    final AccountInfo info = await _xtreamApi.authenticate(creds);
    return ConnectionResult(account: account, info: info);
  }

  Future<ConnectionResult> _validateM3uUrl(IptvAccount account) async {
    final url = account.m3uUrl;
    if (url == null || url.isEmpty) {
      throw const PlaylistException('URL de playlist manquante.');
    }
    try {
      final content = await _m3uParser.fetchFromUrl(url);
      final playlist = _m3uParser.parse(content);
      await _cache.putM3uRaw(account.id, content);
      return ConnectionResult(account: account, playlist: playlist);
    } on NetworkException {
      // Repli hors ligne : dernière playlist téléchargée pour ce compte.
      final cached = _cache.getM3uRaw(account.id);
      if (cached != null) {
        return ConnectionResult(
          account: account,
          playlist: _m3uParser.parse(cached),
          offline: true,
        );
      }
      rethrow;
    }
  }

  Future<ConnectionResult> _validateM3uFile(IptvAccount account) async {
    final path = account.m3uFilePath;
    if (path == null || path.isEmpty) {
      throw const FileException('Chemin du fichier M3U manquant.');
    }
    final content = await _m3uParser.readFromFile(path);
    final playlist = _m3uParser.parse(content);
    await _cache.putM3uRaw(account.id, content); // repli si fichier déplacé
    return ConnectionResult(account: account, playlist: playlist);
  }

  Future<ConnectionResult> _validateMac(IptvAccount account) async {
    // 1) Interroger le portail (lève ActivationPendingException si en attente).
    final result = await _macActivation.checkActivation(
      portalUrl: account.portalUrl ?? '',
      mac: account.mac ?? '',
      deviceId: account.deviceId ?? '',
    );

    // 2) Enrichir le compte avec la source attribuée, puis la valider.
    switch (result.type) {
      case MacResolvedType.xtream:
        final enriched = account.copyWith(
          macResolvedType: MacResolvedType.xtream,
          host: result.host,
          username: result.username,
          password: result.password,
        );
        final xtream = await _validateXtream(enriched);
        return ConnectionResult(account: enriched, info: xtream.info);
      case MacResolvedType.m3u:
        final enriched = account.copyWith(
          macResolvedType: MacResolvedType.m3u,
          m3uUrl: result.m3uUrl,
        );
        final m3u = await _validateM3uUrl(enriched);
        return ConnectionResult(
            account: enriched, playlist: m3u.playlist, offline: m3u.offline);
      case MacResolvedType.none:
        throw const ActivationException();
    }
  }

  // ---------- Stockage ----------

  @override
  Future<void> saveAndActivate(IptvAccount account) async {
    final updated = account.copyWith(
        lastUsedAt: DateTime.now().millisecondsSinceEpoch);
    await _accounts.upsertAccount(updated);
    await _accounts.setActiveAccount(updated.id);
  }

  @override
  Future<List<IptvAccount>> accounts() => _accounts.getAccounts();

  @override
  Future<IptvAccount?> activeAccount() => _accounts.getActiveAccount();

  @override
  Future<void> deactivate() => _accounts.setActiveAccount(null);

  @override
  Future<void> deleteAccount(IptvAccount account) async {
    await _accounts.deleteAccount(account.id);
    await _cache.deleteM3uRaw(account.id);
    // Supprimer la copie locale du fichier M3U importé, le cas échéant.
    final path = account.m3uFilePath;
    if (path != null && path.isNotEmpty) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {/* non bloquant */}
    }
  }
}
