import 'package:equatable/equatable.dart';

/// Identifiants Xtream Codes (host normalisé + user + pass).
class XtreamCredentials extends Equatable {
  final String host; // ex: http://server.tld:8080 (sans slash final)
  final String username;
  final String password;

  const XtreamCredentials({
    required this.host,
    required this.username,
    required this.password,
  });

  /// Normalise l'URL saisie par l'utilisateur.
  factory XtreamCredentials.normalize({
    required String host,
    required String username,
    required String password,
  }) {
    var h = host.trim();
    if (!h.startsWith('http://') && !h.startsWith('https://')) {
      h = 'http://$h';
    }
    while (h.endsWith('/')) {
      h = h.substring(0, h.length - 1);
    }
    return XtreamCredentials(
      host: h,
      username: username.trim(),
      password: password.trim(),
    );
  }

  String get playerApiUrl => '$host/player_api.php';

  String liveStreamUrl(int streamId, {String ext = 'm3u8'}) =>
      '$host/live/$username/$password/$streamId.$ext';

  String vodStreamUrl(int streamId, String containerExtension) =>
      '$host/movie/$username/$password/$streamId.$containerExtension';

  String seriesStreamUrl(int episodeId, String containerExtension) =>
      '$host/series/$username/$password/$episodeId.$containerExtension';

  @override
  List<Object?> get props => [host, username, password];
}
