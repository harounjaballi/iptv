import 'package:equatable/equatable.dart';

import 'xtream_credentials.dart';

/// Type de source d'un compte IPTV.
enum AccountSourceType {
  xtream, // API Xtream Codes (serveur + user + pass)
  m3uUrl, // Playlist M3U distante (URL)
  m3uFile, // Playlist M3U locale (fichier importé)
  mac; // Activation par adresse MAC (portail d'activation)

  String get label => switch (this) {
        AccountSourceType.xtream => 'Xtream Codes',
        AccountSourceType.m3uUrl => 'URL M3U',
        AccountSourceType.m3uFile => 'Fichier M3U',
        AccountSourceType.mac => 'Adresse MAC',
      };

  static AccountSourceType fromName(String? name) =>
      AccountSourceType.values.firstWhere(
        (t) => t.name == name,
        orElse: () => AccountSourceType.xtream,
      );
}

/// Type de source résolu après activation MAC.
enum MacResolvedType {
  none,
  xtream,
  m3u;

  static MacResolvedType fromName(String? name) =>
      MacResolvedType.values.firstWhere(
        (t) => t.name == name,
        orElse: () => MacResolvedType.none,
      );
}

/// Compte IPTV unifié — supporte Xtream, M3U (URL/fichier) et MAC.
/// Sérialisable en JSON pour le stockage sécurisé multi-comptes.
class IptvAccount extends Equatable {
  final String id;
  final String name;
  final AccountSourceType type;
  final int createdAt; // ms epoch
  final int lastUsedAt; // ms epoch

  // ---- Xtream ----
  final String? host;
  final String? username;
  final String? password;

  // ---- M3U ----
  final String? m3uUrl; // pour m3uUrl
  final String? m3uFilePath; // pour m3uFile (copie locale dans l'app)

  // ---- MAC ----
  final String? portalUrl; // serveur d'activation
  final String? mac; // adresse MAC virtuelle de l'appareil
  final String? deviceId; // identifiant appareil
  final MacResolvedType macResolvedType; // source obtenue après activation

  const IptvAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    required this.lastUsedAt,
    this.host,
    this.username,
    this.password,
    this.m3uUrl,
    this.m3uFilePath,
    this.portalUrl,
    this.mac,
    this.deviceId,
    this.macResolvedType = MacResolvedType.none,
  });

  /// Génère un id unique (timestamp + suffixe aléatoire).
  static String newId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'acc_${now.toRadixString(36)}';
  }

  // ---------- Fabriques par type ----------

  factory IptvAccount.xtream({
    required String name,
    required String host,
    required String username,
    required String password,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final creds = XtreamCredentials.normalize(
        host: host, username: username, password: password);
    return IptvAccount(
      id: newId(),
      name: name.trim().isEmpty ? creds.username : name.trim(),
      type: AccountSourceType.xtream,
      createdAt: now,
      lastUsedAt: now,
      host: creds.host,
      username: creds.username,
      password: creds.password,
    );
  }

  factory IptvAccount.m3uUrl({required String name, required String url}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final u = url.trim();
    return IptvAccount(
      id: newId(),
      name: name.trim().isEmpty ? 'Playlist M3U' : name.trim(),
      type: AccountSourceType.m3uUrl,
      createdAt: now,
      lastUsedAt: now,
      m3uUrl: u,
    );
  }

  factory IptvAccount.m3uFile({required String name, required String path}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return IptvAccount(
      id: newId(),
      name: name.trim().isEmpty ? 'Fichier M3U' : name.trim(),
      type: AccountSourceType.m3uFile,
      createdAt: now,
      lastUsedAt: now,
      m3uFilePath: path,
    );
  }

  factory IptvAccount.mac({
    required String name,
    required String portalUrl,
    required String mac,
    required String deviceId,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    var p = portalUrl.trim();
    if (!p.startsWith('http://') && !p.startsWith('https://')) {
      p = 'http://$p';
    }
    while (p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return IptvAccount(
      id: newId(),
      name: name.trim().isEmpty ? 'Appareil $mac' : name.trim(),
      type: AccountSourceType.mac,
      createdAt: now,
      lastUsedAt: now,
      portalUrl: p,
      mac: mac,
      deviceId: deviceId,
    );
  }

  // ---------- Aides ----------

  /// Le compte utilise-t-il l'API Xtream pour le contenu ?
  bool get usesXtream =>
      type == AccountSourceType.xtream ||
      (type == AccountSourceType.mac &&
          macResolvedType == MacResolvedType.xtream);

  /// Le compte utilise-t-il une playlist M3U pour le contenu ?
  bool get usesM3u =>
      type == AccountSourceType.m3uUrl ||
      type == AccountSourceType.m3uFile ||
      (type == AccountSourceType.mac &&
          macResolvedType == MacResolvedType.m3u);

  /// Identifiants Xtream (null si non applicable / non résolu).
  XtreamCredentials? get xtreamCredentials {
    if (!usesXtream || host == null || username == null || password == null) {
      return null;
    }
    return XtreamCredentials(
        host: host!, username: username!, password: password!);
  }

  /// Sous-titre lisible pour l'affichage (masque le mot de passe).
  String get subtitle => switch (type) {
        AccountSourceType.xtream => '${type.label} • $host',
        AccountSourceType.m3uUrl => '${type.label} • ${_short(m3uUrl)}',
        AccountSourceType.m3uFile =>
          '${type.label} • ${m3uFilePath?.split('/').last ?? ''}',
        AccountSourceType.mac => '${type.label} • $mac',
      };

  static String _short(String? s) {
    if (s == null) return '';
    return s.length <= 42 ? s : '${s.substring(0, 42)}…';
  }

  IptvAccount copyWith({
    String? name,
    int? lastUsedAt,
    String? host,
    String? username,
    String? password,
    String? m3uUrl,
    String? m3uFilePath,
    MacResolvedType? macResolvedType,
  }) =>
      IptvAccount(
        id: id,
        name: name ?? this.name,
        type: type,
        createdAt: createdAt,
        lastUsedAt: lastUsedAt ?? this.lastUsedAt,
        host: host ?? this.host,
        username: username ?? this.username,
        password: password ?? this.password,
        m3uUrl: m3uUrl ?? this.m3uUrl,
        m3uFilePath: m3uFilePath ?? this.m3uFilePath,
        portalUrl: portalUrl,
        mac: mac,
        deviceId: deviceId,
        macResolvedType: macResolvedType ?? this.macResolvedType,
      );

  // ---------- Sérialisation ----------

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'created_at': createdAt,
        'last_used_at': lastUsedAt,
        'host': host,
        'username': username,
        'password': password,
        'm3u_url': m3uUrl,
        'm3u_file_path': m3uFilePath,
        'portal_url': portalUrl,
        'mac': mac,
        'device_id': deviceId,
        'mac_resolved_type': macResolvedType.name,
      };

  factory IptvAccount.fromJson(Map<String, dynamic> json) => IptvAccount(
        id: json['id']?.toString() ?? newId(),
        name: json['name']?.toString() ?? 'Compte',
        type: AccountSourceType.fromName(json['type']?.toString()),
        createdAt: int.tryParse(json['created_at']?.toString() ?? '') ?? 0,
        lastUsedAt: int.tryParse(json['last_used_at']?.toString() ?? '') ?? 0,
        host: json['host']?.toString(),
        username: json['username']?.toString(),
        password: json['password']?.toString(),
        m3uUrl: json['m3u_url']?.toString(),
        m3uFilePath: json['m3u_file_path']?.toString(),
        portalUrl: json['portal_url']?.toString(),
        mac: json['mac']?.toString(),
        deviceId: json['device_id']?.toString(),
        macResolvedType:
            MacResolvedType.fromName(json['mac_resolved_type']?.toString()),
      );

  @override
  List<Object?> get props => [id];
}
