import 'dart:async';

import 'package:cast/cast.dart';
import 'package:flutter/foundation.dart';

/// État de la diffusion Chromecast.
enum CastState { idle, connecting, connected, error }

/// Contrôleur Chromecast (protocole CASTV2, sans SDK Google Play) :
/// découverte mDNS, session, lancement du récepteur média par défaut,
/// chargement du flux et contrôles play / pause / seek / stop.
class CastController extends ChangeNotifier {
  CastState state = CastState.idle;
  CastDevice? device;
  String? errorMessage;
  bool isPlaying = false;

  CastSession? _session;
  int? _mediaSessionId;
  StreamSubscription? _messageSub;
  StreamSubscription? _stateSub;

  // Média en attente : chargé dès que le récepteur est prêt.
  String? _pendingUrl;
  String? _pendingTitle;
  String? _pendingImage;
  bool _pendingLive = false;
  Duration _pendingStartAt = Duration.zero;

  bool get isCasting => state == CastState.connected;

  /// Recherche les appareils Chromecast sur le réseau local.
  Future<List<CastDevice>> discover() async {
    try {
      return await CastDiscoveryService().search();
    } catch (_) {
      return const [];
    }
  }

  /// Se connecte à un appareil puis diffuse le média demandé.
  Future<void> startCasting(
    CastDevice target, {
    required String url,
    required String title,
    String? imageUrl,
    bool isLive = false,
    Duration startAt = Duration.zero,
  }) async {
    await stop();
    device = target;
    state = CastState.connecting;
    errorMessage = null;
    _pendingUrl = url;
    _pendingTitle = title;
    _pendingImage = imageUrl;
    _pendingLive = isLive;
    _pendingStartAt = startAt;
    notifyListeners();

    try {
      final session = await CastSessionManager().startSession(target);
      _session = session;

      _stateSub = session.stateStream.listen((s) {
        if (s == CastSessionState.connected) {
          // Lance le récepteur média par défaut de Google.
          session.sendMessage(CastSession.kNamespaceReceiver, {
            'type': 'LAUNCH',
            'appId': 'CC1AD845',
          });
        } else if (s == CastSessionState.closed) {
          _reset();
        }
      });

      _messageSub = session.messageStream.listen(_onMessage);
    } catch (e) {
      errorMessage = e.toString();
      state = CastState.error;
      notifyListeners();
    }
  }

  void _onMessage(Map<String, dynamic> message) {
    final type = message['type']?.toString();

    // Récepteur lancé → charger le média.
    if (type == 'RECEIVER_STATUS') {
      final apps = message['status']?['applications'];
      if (apps is List && apps.isNotEmpty && _pendingUrl != null) {
        _loadMedia();
      }
      return;
    }

    // Suivi de l'état de lecture (mediaSessionId nécessaire aux commandes).
    if (type == 'MEDIA_STATUS') {
      final status = message['status'];
      if (status is List && status.isNotEmpty) {
        final first = status.first;
        if (first is Map) {
          _mediaSessionId =
              int.tryParse(first['mediaSessionId']?.toString() ?? '');
          isPlaying = first['playerState']?.toString() == 'PLAYING';
          if (state != CastState.connected) state = CastState.connected;
          notifyListeners();
        }
      }
    }
  }

  void _loadMedia() {
    final url = _pendingUrl;
    if (url == null || _session == null) return;
    _pendingUrl = null;

    _session!.sendMessage(CastSession.kNamespaceMedia, {
      'type': 'LOAD',
      'autoplay': true,
      'currentTime': _pendingLive ? 0 : _pendingStartAt.inSeconds,
      'media': {
        'contentId': url,
        'contentType': _guessContentType(url),
        'streamType': _pendingLive ? 'LIVE' : 'BUFFERED',
        'metadata': {
          'metadataType': 0,
          'title': _pendingTitle ?? 'Premium IPTV Player',
          if (_pendingImage != null && _pendingImage!.isNotEmpty)
            'images': [
              {'url': _pendingImage}
            ],
        },
      },
    });

    state = CastState.connected;
    notifyListeners();
  }

  static String _guessContentType(String url) {
    final clean = url.split('?').first.toLowerCase();
    if (clean.endsWith('.m3u8')) return 'application/x-mpegurl';
    if (clean.endsWith('.mpd')) return 'application/dash+xml';
    if (clean.endsWith('.ts')) return 'video/mp2t';
    if (clean.endsWith('.mkv')) return 'video/x-matroska';
    return 'video/mp4';
  }

  void _sendMediaCommand(String type, [Map<String, dynamic>? extra]) {
    final session = _session;
    final id = _mediaSessionId;
    if (session == null || id == null) return;
    session.sendMessage(CastSession.kNamespaceMedia, {
      'type': type,
      'mediaSessionId': id,
      ...?extra,
    });
  }

  void play() => _sendMediaCommand('PLAY');
  void pause() => _sendMediaCommand('PAUSE');
  void seek(Duration position) =>
      _sendMediaCommand('SEEK', {'currentTime': position.inSeconds});
  void togglePlayPause() => isPlaying ? pause() : play();

  /// Arrête la diffusion et ferme la session.
  Future<void> stop() async {
    try {
      _sendMediaCommand('STOP');
      await _session?.close();
    } catch (_) {/* session déjà fermée */}
    _reset();
  }

  void _reset() {
    _messageSub?.cancel();
    _stateSub?.cancel();
    _messageSub = null;
    _stateSub = null;
    _session = null;
    _mediaSessionId = null;
    device = null;
    isPlaying = false;
    state = CastState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
