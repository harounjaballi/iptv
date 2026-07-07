import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../domain/repositories/auth_repository.dart';
import '../models/account_info.dart';
import '../models/iptv_account.dart';
import '../models/xtream_credentials.dart';
import '../services/m3u_parser_service.dart';
import 'app_providers.dart';

/// ---------------- État d'authentification ----------------
sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Reconnexion automatique en cours (tentative n / total).
class AuthReconnecting extends AuthState {
  final int attempt;
  final int maxAttempts;
  const AuthReconnecting(this.attempt, this.maxAttempts);
}

class AuthAuthenticated extends AuthState {
  final IptvAccount account;
  final AccountInfo? info; // infos Xtream (null pour M3U)
  final M3uPlaylist? playlist; // playlist parsée (null pour Xtream)
  final bool offline; // contenu servi depuis le cache

  const AuthAuthenticated({
    required this.account,
    this.info,
    this.playlist,
    this.offline = false,
  });
}

class AuthError extends AuthState {
  final String message;

  /// L'activation MAC est simplement en attente (pas un vrai échec).
  final bool activationPending;

  const AuthError(this.message, {this.activationPending = false});
}

/// ---------------- Notifier ----------------
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthInitial();

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  // ---------- Connexions par type (validation AVANT sauvegarde) ----------

  /// Xtream Codes : serveur + utilisateur + mot de passe.
  Future<bool> loginXtream({
    required String name,
    required String host,
    required String username,
    required String password,
  }) =>
      _connect(IptvAccount.xtream(
        name: name,
        host: host,
        username: username,
        password: password,
      ));

  /// Playlist M3U distante.
  Future<bool> loginM3uUrl({required String name, required String url}) =>
      _connect(IptvAccount.m3uUrl(name: name, url: url));

  /// Playlist M3U locale (fichier déjà copié dans le dossier de l'app).
  Future<bool> loginM3uFile({required String name, required String path}) =>
      _connect(IptvAccount.m3uFile(name: name, path: path));

  /// Activation par adresse MAC : interroge le portail. Renvoie true si
  /// l'appareil est activé et connecté ; sinon l'état devient AuthError
  /// (avec activationPending=true si l'appareil attend son activation).
  Future<bool> loginMac({
    required String name,
    required String portalUrl,
    required String mac,
    required String deviceId,
  }) =>
      _connect(
        IptvAccount.mac(
          name: name,
          portalUrl: portalUrl,
          mac: mac,
          deviceId: deviceId,
        ),
        retryOnNetworkError: false, // le polling de l'écran d'activation gère
      );

  /// Reconnecte un compte déjà enregistré (changement de compte).
  Future<bool> switchAccount(IptvAccount account) => _connect(account);

  /// Relance la connexion du compte actif (bouton « Réessayer »).
  Future<bool> reconnect() async {
    final current = state;
    if (current is AuthAuthenticated) return _connect(current.account);
    final saved = await _repo.activeAccount();
    if (saved == null) return false;
    return _connect(saved);
  }

  // ---------- Cœur : validation + reconnexion automatique ----------

  Future<bool> _connect(IptvAccount account,
      {bool retryOnNetworkError = true}) async {
    state = const AuthLoading();

    final maxAttempts =
        retryOnNetworkError ? AppConstants.reconnectAttempts : 1;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final result = await _repo.validate(account);
        await _repo.saveAndActivate(result.account);
        state = AuthAuthenticated(
          account: result.account,
          info: result.info,
          playlist: result.playlist,
          offline: result.offline,
        );
        return true;
      } on NetworkException catch (e) {
        if (attempt >= maxAttempts) {
          state = AuthError(e.message);
          return false;
        }
        // Reconnexion automatique : délai progressif (2s, 4s, ...).
        state = AuthReconnecting(attempt, maxAttempts);
        await Future.delayed(AppConstants.reconnectBaseDelay * (1 << (attempt - 1)));
      } on ActivationPendingException catch (e) {
        // Cas MAC : l'appareil n'est pas encore activé côté portail.
        await _repo.saveAndActivate(account); // on garde le compte en attente
        state = AuthError(e.message, activationPending: true);
        return false;
      } on AppException catch (e) {
        state = AuthError(e.message);
        return false;
      } catch (_) {
        state = const AuthError('Erreur inattendue lors de la connexion.');
        return false;
      }
    }
    return false;
  }

  /// Restaure la session au démarrage (avec reconnexion automatique).
  /// Renvoie true si connecté.
  Future<bool> tryRestore() async {
    final saved = await _repo.activeAccount();
    if (saved == null) return false;
    return _connect(saved);
  }

  // ---------- Gestion des comptes ----------

  Future<List<IptvAccount>> accounts() => _repo.accounts();

  Future<void> deleteAccount(IptvAccount account) async {
    await _repo.deleteAccount(account);
    final current = state;
    if (current is AuthAuthenticated && current.account.id == account.id) {
      state = const AuthInitial();
    }
  }

  /// Déconnexion : quitte la session active mais conserve les comptes.
  Future<void> logout() async {
    await _repo.deactivate();
    state = const AuthInitial();
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// ---------------- Sélecteurs pratiques ----------------

/// Compte actif (null si non connecté).
final activeAccountProvider = Provider<IptvAccount?>((ref) {
  final state = ref.watch(authProvider);
  return state is AuthAuthenticated ? state.account : null;
});

/// Identifiants Xtream courants (null si non connecté ou compte M3U).
final credentialsProvider = Provider<XtreamCredentials?>((ref) {
  return ref.watch(activeAccountProvider)?.xtreamCredentials;
});

/// Playlist M3U parsée du compte actif (null si compte Xtream).
final activePlaylistProvider = Provider<M3uPlaylist?>((ref) {
  final state = ref.watch(authProvider);
  return state is AuthAuthenticated ? state.playlist : null;
});

/// Liste des comptes enregistrés (rafraîchie à chaque changement d'état).
final savedAccountsProvider =
    FutureProvider.autoDispose<List<IptvAccount>>((ref) {
  ref.watch(authProvider); // invalide après login/logout/suppression
  return ref.read(authProvider.notifier).accounts();
});
