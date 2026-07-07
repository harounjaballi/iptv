import 'package:dio/dio.dart';

import '../core/errors/app_exception.dart';
import '../models/iptv_account.dart';

/// Résultat d'une activation MAC réussie : la source de contenu
/// attribuée à l'appareil par le portail.
class MacActivationResult {
  final MacResolvedType type;

  // Si type == xtream :
  final String? host;
  final String? username;
  final String? password;

  // Si type == m3u :
  final String? m3uUrl;

  const MacActivationResult({
    required this.type,
    this.host,
    this.username,
    this.password,
    this.m3uUrl,
  });
}

/// Activation d'appareil par adresse MAC.
///
/// L'application affiche la MAC + le Device ID ; l'utilisateur les
/// enregistre sur le portail du fournisseur, puis l'app interroge :
///
///   GET {portalUrl}/activation?mac=00:1A:79:XX:XX:XX&device_id=XXXXXXXXXXXX
///
/// Réponses JSON attendues :
///   { "status": "active", "type": "xtream",
///     "host": "http://srv:8080", "username": "u", "password": "p" }
///   { "status": "active", "type": "m3u", "url": "http://.../liste.m3u" }
///   { "status": "pending" }                       → en attente d'activation
///   { "status": "not_found", "message": "..." }   → appareil inconnu
class MacActivationService {
  final Dio _dio;

  const MacActivationService(this._dio);

  Future<MacActivationResult> checkActivation({
    required String portalUrl,
    required String mac,
    required String deviceId,
  }) async {
    dynamic data;
    try {
      final response = await _dio.get(
        '$portalUrl/activation',
        queryParameters: {'mac': mac, 'device_id': deviceId},
      );
      if (response.statusCode == 404) {
        throw const ActivationException(
            'Portail d\'activation introuvable. Vérifiez l\'adresse du serveur.');
      }
      if (response.statusCode != 200) {
        throw const ServerException(
            'Le portail d\'activation ne répond pas correctement.');
      }
      data = response.data;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const NetworkException();
      }
      throw const ServerException(
          'Impossible de contacter le portail d\'activation.');
    }

    if (data is! Map) {
      throw const ParsingException(
          'Réponse du portail d\'activation illisible.');
    }
    final map = Map<String, dynamic>.from(data);
    final status = map['status']?.toString().toLowerCase() ?? '';

    switch (status) {
      case 'active':
        return _parseActive(map);
      case 'pending':
        throw const ActivationPendingException();
      case 'not_found':
        throw ActivationException(map['message']?.toString() ??
            'Appareil non enregistré sur le portail.');
      default:
        throw const ActivationException(
            'Statut d\'activation inconnu renvoyé par le portail.');
    }
  }

  MacActivationResult _parseActive(Map<String, dynamic> map) {
    final type = map['type']?.toString().toLowerCase() ?? '';
    if (type == 'xtream') {
      final host = map['host']?.toString();
      final username = map['username']?.toString();
      final password = map['password']?.toString();
      if (host == null ||
          host.isEmpty ||
          username == null ||
          password == null) {
        throw const ActivationException(
            'Le portail a renvoyé des identifiants Xtream incomplets.');
      }
      return MacActivationResult(
        type: MacResolvedType.xtream,
        host: host,
        username: username,
        password: password,
      );
    }
    if (type == 'm3u') {
      final url = map['url']?.toString();
      if (url == null || url.isEmpty) {
        throw const ActivationException(
            'Le portail a renvoyé une URL de playlist vide.');
      }
      return MacActivationResult(type: MacResolvedType.m3u, m3uUrl: url);
    }
    throw const ActivationException(
        'Type de source inconnu renvoyé par le portail (attendu : xtream ou m3u).');
  }
}
