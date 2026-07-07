/// Exceptions métier typées de l'application.
sealed class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  const NetworkException(
      [super.message = 'Erreur réseau. Vérifiez votre connexion Internet.']);
}

class AuthException extends AppException {
  const AuthException(
      [super.message = 'Identifiants invalides ou compte expiré.']);
}

class ServerException extends AppException {
  const ServerException(
      [super.message = 'Le serveur ne répond pas correctement.']);
}

class ParsingException extends AppException {
  const ParsingException([super.message = 'Réponse du serveur illisible.']);
}

/// Playlist M3U invalide, vide ou illisible.
class PlaylistException extends AppException {
  const PlaylistException(
      [super.message = 'Playlist M3U invalide ou vide.']);
}

/// Fichier local introuvable ou illisible.
class FileException extends AppException {
  const FileException(
      [super.message = 'Impossible de lire le fichier sélectionné.']);
}

/// Activation MAC : appareil non encore activé côté serveur.
class ActivationPendingException extends AppException {
  const ActivationPendingException(
      [super.message =
          'Appareil en attente d\'activation. Enregistrez votre adresse MAC sur le portail.']);
}

/// Activation MAC : échec (appareil inconnu, portail invalide, etc.).
class ActivationException extends AppException {
  const ActivationException(
      [super.message = 'Échec de l\'activation de l\'appareil.']);
}
