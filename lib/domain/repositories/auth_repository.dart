import '../../models/account_info.dart';
import '../../models/iptv_account.dart';
import '../../services/m3u_parser_service.dart';

/// Résultat d'une connexion validée : compte (éventuellement enrichi)
/// + infos Xtream (si applicable) + playlist M3U parsée (si applicable).
class ConnectionResult {
  final IptvAccount account;
  final AccountInfo? info; // comptes Xtream uniquement
  final M3uPlaylist? playlist; // comptes M3U uniquement
  final bool offline; // contenu servi depuis le cache local

  const ConnectionResult({
    required this.account,
    this.info,
    this.playlist,
    this.offline = false,
  });
}

/// Contrat d'authentification multi-comptes (couche domaine).
abstract interface class AuthRepository {
  /// Valide un compte auprès de sa source (API Xtream, playlist M3U,
  /// portail MAC) SANS le sauvegarder. Lève une AppException en cas d'échec.
  Future<ConnectionResult> validate(IptvAccount account);

  /// Sauvegarde un compte et le définit comme compte actif.
  Future<void> saveAndActivate(IptvAccount account);

  /// Tous les comptes enregistrés.
  Future<List<IptvAccount>> accounts();

  /// Compte actif enregistré (null si aucun).
  Future<IptvAccount?> activeAccount();

  /// Déconnecte le compte actif (les comptes restent enregistrés).
  Future<void> deactivate();

  /// Supprime définitivement un compte (et ses données locales).
  Future<void> deleteAccount(IptvAccount account);
}
