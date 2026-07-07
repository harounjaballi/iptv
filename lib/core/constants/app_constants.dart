/// Constantes globales de l'application.
class AppConstants {
  AppConstants._();

  static const String appName = 'Premium IPTV Player';

  // ---- Clés flutter_secure_storage ----
  // Multi-comptes : liste JSON + id du compte actif
  static const String keyAccounts = 'iptv_accounts';
  static const String keyActiveAccountId = 'iptv_active_account_id';

  // Identité de l'appareil (mode MAC)
  static const String keyDeviceMac = 'device_mac';
  static const String keyDeviceId = 'device_id';

  // Anciennes clés (v1, compte Xtream unique) — migrées automatiquement
  static const String legacyKeyHost = 'xtream_host';
  static const String legacyKeyUsername = 'xtream_username';
  static const String legacyKeyPassword = 'xtream_password';

  // ---- Boîtes Hive (cache & préférences non sensibles) ----
  static const String boxSettings = 'settings';
  static const String boxCache = 'cache';
  static const String boxFavorites = 'favorites';

  // Clés de préférences
  static const String prefThemeMode = 'theme_mode';

  // Préfixe de cache pour le contenu brut des playlists M3U
  static const String cacheM3uRawPrefix = 'm3u_raw_';

  // ---- Cache & réseau ----
  static const Duration cacheTtl = Duration(hours: 6);
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ---- Reconnexion automatique ----
  /// Nombre de tentatives de connexion (login / restauration de session).
  static const int reconnectAttempts = 3;

  /// Délai de base entre deux tentatives (doublé à chaque essai : 2s, 4s, 8s).
  static const Duration reconnectBaseDelay = Duration(seconds: 2);

  // ---- Activation MAC ----
  /// Préfixe MAC virtuel de style MAG (convention IPTV).
  static const String macPrefix = '00:1A:79';

  /// Intervalle de vérification du statut d'activation.
  static const Duration activationPollInterval = Duration(seconds: 5);
}
