import 'dart:async';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:cast/cast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../providers/media_providers.dart';
import '../../providers/stats_providers.dart';
import '../../services/cast_service.dart';
import '../../themes/app_colors.dart';
import '../../utils/formatters.dart';

/// Élément de file de lecture (épisode ou film).
class PlayerQueueItem {
  final String url;
  final String title;

  /// Clé de progression (WatchProgress.vodKey / episodeKey). Null = pas de suivi.
  final String? progressKey;

  const PlayerQueueItem({
    required this.url,
    required this.title,
    this.progressKey,
  });
}

/// Arguments passés au lecteur via GoRouter (extra).
class PlayerArgs {
  final String url;
  final String title;
  final bool isLive;

  /// Clé de progression (reprise + historique). Null = pas de suivi.
  final String? progressKey;

  /// Position de départ (reprise de lecture).
  final Duration? startAt;

  /// File d'attente pour la lecture automatique (épisodes suivants).
  final List<PlayerQueueItem> queue;

  /// Index de départ dans la file (si queue non vide, url/title sont ignorés).
  final int queueIndex;

  /// Callback à chaque changement d'élément (mise à jour "dernier épisode vu").
  final void Function(int queueIndex)? onItemStarted;

  /// Image (affiche) transmise au Chromecast.
  final String? imageUrl;

  const PlayerArgs({
    required this.url,
    required this.title,
    required this.isLive,
    this.progressKey,
    this.startAt,
    this.queue = const [],
    this.queueIndex = 0,
    this.onItemStarted,
    this.imageUrl,
  });
}

/// Type de geste en cours (indicateur à l'écran).
enum _GestureKind { none, volume, brightness, seek }

/// ============================================================
/// Lecteur IPTV Premium (Better Player Plus / ExoPlayer)
/// ============================================================
/// Formats : HLS, MPEG-TS, MP4, MKV — HEVC/H.265, 4K, HDR via le
/// décodage matériel ExoPlayer (aucune conversion logicielle).
///
/// - Plein écran immersif, verrouillage de l'écran
/// - Contrôles personnalisés (auto-masqués), compatibles télécommande
/// - Gestes : tap (contrôles), double-tap (±10 s), glisser vertical
///   gauche = luminosité, droite = volume système, horizontal = seek
/// - Sous-titres, pistes audio, qualité (HLS), vitesse de lecture
/// - Picture in Picture, Chromecast (CASTV2)
/// - Reprise automatique + lecture continue (épisode suivant)
class PlayerScreen extends ConsumerStatefulWidget {
  final PlayerArgs args;

  const PlayerScreen({super.key, required this.args});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final BetterPlayerController _controller;
  final GlobalKey _playerKey = GlobalKey();
  final CastController _cast = CastController();

  // ---------------- Timers ----------------
  Timer? _statsTimer; // statistiques de visionnage
  Timer? _progressTimer; // sauvegarde de la position (reprise)
  Timer? _uiTimer; // rafraîchit position/durée à l'écran
  Timer? _hideTimer; // auto-masquage des contrôles
  Timer? _countdownTimer; // épisode suivant
  Timer? _lockHintTimer; // icône cadenas en mode verrouillé

  // ---------------- File de lecture ----------------
  late int _queueIndex;
  int _countdown = 0; // > 0 : overlay "épisode suivant" visible

  /// Position de reprise à appliquer dès que la vidéo est initialisée.
  Duration? _pendingSeek;

  // ---------------- État UI ----------------
  bool _controlsVisible = true;
  bool _locked = false;
  bool _lockHintVisible = false;
  bool _isPlaying = true;
  bool _buffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _speed = 1.0;
  bool _dragging = false; // slider en cours de déplacement
  double _dragValue = 0;

  // ---------------- Gestes ----------------
  _GestureKind _gesture = _GestureKind.none;
  double _gestureValue = 0; // volume / luminosité 0..1
  Duration _seekTarget = Duration.zero; // seek par glissement
  double _volume = 0.5;
  double _brightness = 0.5;

  bool get _hasQueue => widget.args.queue.isNotEmpty;

  PlayerQueueItem get _current => _hasQueue
      ? widget.args.queue[_queueIndex]
      : PlayerQueueItem(
          url: widget.args.url,
          title: widget.args.title,
          progressKey: widget.args.progressKey,
        );

  bool get _hasNext => _hasQueue && _queueIndex < widget.args.queue.length - 1;
  bool get _isLive => widget.args.isLive;

  // ============================================================
  // Cycle de vie
  // ============================================================

  @override
  void initState() {
    super.initState();
    _queueIndex = widget.args.queueIndex;
    _pendingSeek = widget.args.startAt;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _controller = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: true,
        fit: BoxFit.contain,
        handleLifecycle: true,
        allowedScreenSleep: false,
        autoDispose: false,
        // Contrôles natifs désactivés : overlay premium personnalisé.
        controlsConfiguration:
            const BetterPlayerControlsConfiguration(showControls: false),
        eventListener: _onPlayerEvent,
      ),
      betterPlayerDataSource: _dataSource(_current.url),
    );

    _cast.addListener(_onCastChanged);
    widget.args.onItemStarted?.call(_queueIndex);
    _initSystemLevels();

    // Sauvegarde de la position toutes les 10 s (reprise de lecture).
    if (!_isLive) {
      _progressTimer = Timer.periodic(
          const Duration(seconds: 10), (_) => _saveProgress());
    }
    // Rafraîchissement de l'interface (position, durée, buffering).
    _uiTimer =
        Timer.periodic(const Duration(milliseconds: 500), (_) => _tickUi());
    _scheduleHide();

    // Statistiques : +15 s de visionnage tant que la lecture est active.
    ref.read(watchStatsProvider.notifier).registerPlay();
    _statsTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_controller.isPlaying() ?? false) {
        ref.read(watchStatsProvider.notifier).addSeconds(_statsType, 15);
      }
    });
  }

  /// Type de contenu pour les statistiques.
  String get _statsType {
    if (_isLive) return 'live';
    return (_current.progressKey?.startsWith('ep_') ?? false)
        ? 'series'
        : 'vod';
  }

  Future<void> _initSystemLevels() async {
    try {
      // Le volume est ajusté par gestes : on masque l'UI système.
      await FlutterVolumeController.updateShowSystemUI(false);
      _volume = await FlutterVolumeController.getVolume() ?? 0.5;
    } catch (_) {/* plateforme sans contrôle du volume */}
    try {
      _brightness = await ScreenBrightness().current;
    } catch (_) {/* plateforme sans contrôle de luminosité */}
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _progressTimer?.cancel();
    _uiTimer?.cancel();
    _hideTimer?.cancel();
    _countdownTimer?.cancel();
    _lockHintTimer?.cancel();
    _cast.removeListener(_onCastChanged);
    _cast.dispose();

    // Sauvegarde finale de la position au retour (lecture synchrone,
    // persistance déléguée au notifier qui survit à l'écran).
    final key = _current.progressKey;
    if (key != null && !_isLive) {
      final value = _controller.videoPlayerController?.value;
      final position = value?.position;
      final duration = value?.duration;
      if (position != null && duration != null) {
        ref.read(watchProgressProvider.notifier).save(key, position, duration);
      }
    }

    // Restaure la luminosité système d'origine.
    ScreenBrightness().resetScreenBrightness().catchError((_) {});
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller.dispose(forceDispose: true);
    super.dispose();
  }

  // ============================================================
  // Source vidéo — HLS / MPEG-TS / MP4 / MKV (HEVC, 4K, HDR)
  // ============================================================

  BetterPlayerVideoFormat? _detectFormat(String url) {
    final clean = url.split('?').first.toLowerCase();
    if (clean.endsWith('.m3u8')) return BetterPlayerVideoFormat.hls;
    if (clean.endsWith('.mpd')) return BetterPlayerVideoFormat.dash;
    // MPEG-TS, MP4, MKV... : détection automatique par ExoPlayer.
    return null;
  }

  BetterPlayerDataSource _dataSource(String url) => BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        url,
        liveStream: _isLive,
        videoFormat: _detectFormat(url),
        // Pistes HLS : qualités, langues audio et sous-titres intégrés.
        useAsmsTracks: true,
        useAsmsAudioTracks: true,
        useAsmsSubtitles: true,
        // Tampon optimisé : démarrage rapide, stabilité sur les flux 4K.
        bufferingConfiguration: const BetterPlayerBufferingConfiguration(
          minBufferMs: 8000,
          maxBufferMs: 60000,
          bufferForPlaybackMs: 2500,
          bufferForPlaybackAfterRebufferMs: 5000,
        ),
      );

  // ============================================================
  // Progression / reprise
  // ============================================================

  Future<void> _saveProgress() async {
    final key = _current.progressKey;
    if (key == null || _isLive) return;
    final value = _controller.videoPlayerController?.value;
    final position = value?.position;
    final duration = value?.duration;
    if (position == null || duration == null) return;
    await ref
        .read(watchProgressProvider.notifier)
        .save(key, position, duration);
  }

  // ============================================================
  // Événements lecteur & lecture continue
  // ============================================================

  void _onPlayerEvent(BetterPlayerEvent event) {
    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.initialized:
        // Reprise de lecture : seek unique dès l'initialisation.
        final seek = _pendingSeek;
        if (seek != null && seek > const Duration(seconds: 5)) {
          _controller.seekTo(seek);
        }
        _pendingSeek = null;
      case BetterPlayerEventType.bufferingStart:
        if (mounted) setState(() => _buffering = true);
      case BetterPlayerEventType.bufferingEnd:
        if (mounted) setState(() => _buffering = false);
      case BetterPlayerEventType.finished:
        final key = _current.progressKey;
        if (key != null && !_isLive) {
          ref.read(watchProgressProvider.notifier).markCompleted(key);
        }
        if (_hasNext) _startNextCountdown();
      default:
        break;
    }
  }

  void _tickUi() {
    if (!mounted) return;
    final value = _controller.videoPlayerController?.value;
    if (value == null) return;
    final playing = value.isPlaying;
    final position = value.position;
    final duration = value.duration ?? Duration.zero;
    if (playing != _isPlaying ||
        (_controlsVisible && !_dragging) ||
        duration != _duration) {
      setState(() {
        _isPlaying = playing;
        if (!_dragging) _position = position;
        _duration = duration;
      });
    }
  }

  /// Compte à rebours "Épisode suivant dans 5 s" (annulable).
  void _startNextCountdown() {
    _countdownTimer?.cancel();
    setState(() => _countdown = 5);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_countdown <= 1) {
        t.cancel();
        _playNext();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    setState(() => _countdown = 0);
  }

  Future<void> _playNext() async {
    if (!_hasNext) return;
    await _saveProgress();
    _countdownTimer?.cancel();
    setState(() {
      _queueIndex++;
      _countdown = 0;
      _position = Duration.zero;
      _duration = Duration.zero;
    });
    widget.args.onItemStarted?.call(_queueIndex);
    ref.read(watchStatsProvider.notifier).registerPlay();
    await _controller.setupDataSource(_dataSource(_current.url));
    _controller.play();
  }

  // ============================================================
  // Contrôles de base
  // ============================================================

  void _togglePlayPause() {
    if (_controller.isPlaying() ?? false) {
      _controller.pause();
    } else {
      _controller.play();
    }
    _scheduleHide();
  }

  Future<void> _seekRelative(int seconds) async {
    if (_isLive) return;
    final position =
        await _controller.videoPlayerController?.position ?? Duration.zero;
    var target = position + Duration(seconds: seconds);
    if (target.isNegative) target = Duration.zero;
    if (_duration > Duration.zero && target > _duration) target = _duration;
    await _controller.seekTo(target);
    _scheduleHide();
  }

  void _showControls() {
    setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_dragging && _gesture == _GestureKind.none) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleLock() {
    setState(() {
      _locked = !_locked;
      _controlsVisible = !_locked;
      _lockHintVisible = false;
    });
    if (!_locked) _scheduleHide();
  }

  void _showLockHint() {
    setState(() => _lockHintVisible = true);
    _lockHintTimer?.cancel();
    _lockHintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _lockHintVisible = false);
    });
  }

  // ============================================================
  // Gestes tactiles
  // ============================================================

  void _onTap() {
    if (_locked) {
      _showLockHint();
      return;
    }
    _controlsVisible ? setState(() => _controlsVisible = false) : _showControls();
  }

  void _onDoubleTapDown(TapDownDetails details) {
    if (_locked || _isLive) return;
    final width = MediaQuery.sizeOf(context).width;
    final forward = details.globalPosition.dx > width / 2;
    _seekRelative(forward ? 10 : -10);
    setState(() {
      _gesture = _GestureKind.seek;
      _seekTarget = _position + Duration(seconds: forward ? 10 : -10);
    });
    Timer(const Duration(milliseconds: 600), () {
      if (mounted && _gesture == _GestureKind.seek) {
        setState(() => _gesture = _GestureKind.none);
      }
    });
  }

  void _onVerticalDragStart(DragStartDetails details) {
    if (_locked) return;
    final width = MediaQuery.sizeOf(context).width;
    final left = details.globalPosition.dx < width / 2;
    setState(() {
      _gesture = left ? _GestureKind.brightness : _GestureKind.volume;
      _gestureValue = left ? _brightness : _volume;
    });
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_locked || _gesture == _GestureKind.none) return;
    final height = MediaQuery.sizeOf(context).height;
    final delta = -details.delta.dy / (height * 0.6);
    _gestureValue = (_gestureValue + delta).clamp(0.0, 1.0);

    if (_gesture == _GestureKind.brightness) {
      _brightness = _gestureValue;
      ScreenBrightness()
          .setScreenBrightness(_brightness)
          .catchError((_) {});
    } else if (_gesture == _GestureKind.volume) {
      _volume = _gestureValue;
      FlutterVolumeController.setVolume(_volume);
    }
    setState(() {});
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_gesture == _GestureKind.volume ||
        _gesture == _GestureKind.brightness) {
      setState(() => _gesture = _GestureKind.none);
    }
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (_locked || _isLive) return;
    setState(() {
      _gesture = _GestureKind.seek;
      _seekTarget = _position;
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_locked || _gesture != _GestureKind.seek) return;
    final width = MediaQuery.sizeOf(context).width;
    // Balayage complet ≈ ±90 s : précis et rapide à la fois.
    final delta = details.delta.dx / width * 90;
    var target = _seekTarget + Duration(milliseconds: (delta * 1000).round());
    if (target.isNegative) target = Duration.zero;
    if (_duration > Duration.zero && target > _duration) target = _duration;
    setState(() => _seekTarget = target);
  }

  Future<void> _onHorizontalDragEnd(DragEndDetails details) async {
    if (_locked || _gesture != _GestureKind.seek) return;
    await _controller.seekTo(_seekTarget);
    setState(() {
      _position = _seekTarget;
      _gesture = _GestureKind.none;
    });
  }

  // ============================================================
  // Télécommande (Android TV / D-pad)
  // ============================================================

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (_locked) {
      if (key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.enter) {
        _toggleLock();
        return KeyEventResult.handled;
      }
      _showLockHint();
      return KeyEventResult.handled;
    }

    if (_countdown > 0 &&
        (key == LogicalKeyboardKey.escape ||
            key == LogicalKeyboardKey.goBack)) {
      _cancelCountdown();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.space) {
      _countdown > 0 ? _playNext() : _togglePlayPause();
      _showControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaPlay) {
      _controller.play();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaPause) {
      _controller.pause();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.mediaFastForward) {
      _seekRelative(10);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.mediaRewind) {
      _seekRelative(-10);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      _showControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaTrackNext) {
      _playNext();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ============================================================
  // Feuilles de réglages (qualité, audio, sous-titres, vitesse)
  // ============================================================

  Future<void> _showQualitySheet() async {
    final tracks = _controller.betterPlayerAsmsTracks;
    final selected = _controller.betterPlayerAsmsTrack;
    await _showSheet(
      title: 'Qualité',
      children: [
        _sheetTile(
          label: 'Auto (adaptatif)',
          selected: selected == null || selected.height == 0,
          onTap: () =>
              _controller.setTrack(BetterPlayerAsmsTrack.defaultTrack()),
        ),
        for (final t in tracks)
          if ((t.height ?? 0) > 0)
            _sheetTile(
              label:
                  '${t.height}p${(t.bitrate ?? 0) > 0 ? ' · ${((t.bitrate!) / 1000000).toStringAsFixed(1)} Mb/s' : ''}',
              selected: selected?.height == t.height &&
                  selected?.bitrate == t.bitrate,
              onTap: () => _controller.setTrack(t),
            ),
      ],
      emptyMessage: tracks.isEmpty
          ? 'Une seule qualité disponible pour ce flux.'
          : null,
    );
  }

  Future<void> _showAudioSheet() async {
    final tracks = _controller.betterPlayerAsmsAudioTracks ?? const [];
    final selected = _controller.betterPlayerAsmsAudioTrack;
    await _showSheet(
      title: 'Piste audio',
      children: [
        for (final t in tracks)
          _sheetTile(
            label: t.label ?? t.language ?? 'Piste ${t.id ?? ''}',
            selected: selected?.id == t.id,
            onTap: () => _controller.setAudioTrack(t),
          ),
      ],
      emptyMessage:
          tracks.isEmpty ? 'Une seule piste audio disponible.' : null,
    );
  }

  Future<void> _showSubtitlesSheet() async {
    final sources = _controller.betterPlayerSubtitlesSourceList;
    final selected = _controller.betterPlayerSubtitlesSource;
    await _showSheet(
      title: 'Sous-titres',
      children: [
        for (final s in sources)
          _sheetTile(
            label: s.type == BetterPlayerSubtitlesSourceType.none
                ? 'Désactivés'
                : (s.name ?? 'Sous-titres'),
            selected: selected == s,
            onTap: () => _controller.setupSubtitleSource(s),
          ),
      ],
      emptyMessage:
          sources.isEmpty ? 'Aucun sous-titre disponible pour ce flux.' : null,
    );
  }

  Future<void> _showSpeedSheet() async {
    const speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    await _showSheet(
      title: 'Vitesse de lecture',
      children: [
        for (final s in speeds)
          _sheetTile(
            label: s == 1.0 ? 'Normale (1×)' : '$s×',
            selected: _speed == s,
            onTap: () {
              _controller.setSpeed(s);
              setState(() => _speed = s);
            },
          ),
      ],
    );
  }

  Widget _sheetTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(label),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: Colors.white)
          : null,
      onTap: () {
        onTap();
        Navigator.of(context).pop();
      },
    );
  }

  Future<void> _showSheet({
    required String title,
    required List<Widget> children,
    String? emptyMessage,
  }) {
    _hideTimer?.cancel();
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xE6101018),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            if (emptyMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Text(emptyMessage,
                    style: const TextStyle(color: Colors.white60)),
              )
            else
              Flexible(
                child: ListView(shrinkWrap: true, children: children),
              ),
          ],
        ),
      ),
    ).whenComplete(_scheduleHide);
  }

  // ============================================================
  // Picture in Picture
  // ============================================================

  Future<void> _enterPip() async {
    final supported = await _controller.isPictureInPictureSupported();
    if (!supported) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Picture in Picture non pris en charge sur cet appareil')));
      }
      return;
    }
    setState(() => _controlsVisible = false);
    await _controller.enablePictureInPicture(_playerKey);
  }

  // ============================================================
  // Chromecast
  // ============================================================

  void _onCastChanged() {
    if (!mounted) return;
    // Diffusion démarrée → pause locale ; arrêtée → reprise locale.
    if (_cast.isCasting) {
      _controller.pause();
    }
    setState(() {});
  }

  Future<void> _showCastSheet() async {
    _hideTimer?.cancel();
    final devicesFuture = _cast.discover();
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xE6101018),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: FutureBuilder<List<CastDevice>>(
          future: devicesFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Recherche d\'appareils Chromecast...'),
                    ],
                  ),
                ),
              );
            }
            final devices = snapshot.data!;
            if (devices.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                    child: Text(
                        'Aucun appareil trouvé sur le réseau local.')),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text('Diffuser sur',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final d in devices)
                        ListTile(
                          leading: const Icon(Icons.cast_rounded),
                          title: Text(d.name),
                          onTap: () {
                            Navigator.of(context).pop();
                            _cast.startCasting(
                              d,
                              url: _current.url,
                              title: _current.title,
                              imageUrl: widget.args.imageUrl,
                              isLive: _isLive,
                              startAt: _position,
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    _scheduleHide();
  }

  Future<void> _stopCasting() async {
    final resumeAt = _position;
    await _cast.stop();
    if (!_isLive && resumeAt > Duration.zero) {
      await _controller.seekTo(resumeAt);
    }
    _controller.play();
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          onDoubleTapDown: _onDoubleTapDown,
          onDoubleTap: () {}, // requis pour activer onDoubleTapDown
          onVerticalDragStart: _onVerticalDragStart,
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          child: Stack(
            children: [
              // ---------- Vidéo ----------
              Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: BetterPlayer(
                      key: _playerKey, controller: _controller),
                ),
              ),
              if (_buffering && !_cast.isCasting)
                const Center(
                    child:
                        CircularProgressIndicator(color: Colors.white)),
              // ---------- Vue Chromecast ----------
              if (_cast.state == CastState.connecting ||
                  _cast.isCasting)
                _castView(),
              // ---------- Indicateurs de gestes ----------
              if (_gesture != _GestureKind.none && !_cast.isCasting)
                _gestureIndicator(),
              // ---------- Contrôles ----------
              if (!_locked && !_cast.isCasting) _controlsOverlay(),
              // ---------- Mode verrouillé ----------
              if (_locked) _lockOverlay(),
              // ---------- Épisode suivant ----------
              if (_countdown > 0 && _hasNext) _nextEpisodeOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- Overlay des contrôles ----------------

  Widget _controlsOverlay() {
    return AnimatedOpacity(
      opacity: _controlsVisible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !_controlsVisible,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black87, Colors.transparent, Colors.black87],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _topBar(),
                const Spacer(),
                _centerControls(),
                const Spacer(),
                _bottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              _current.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          if (_isLive)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE50914),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('EN DIRECT',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          IconButton(
            tooltip: 'Sous-titres',
            icon: const Icon(Icons.subtitles_outlined, color: Colors.white),
            onPressed: _showSubtitlesSheet,
          ),
          IconButton(
            tooltip: 'Piste audio',
            icon: const Icon(Icons.audiotrack_outlined, color: Colors.white),
            onPressed: _showAudioSheet,
          ),
          IconButton(
            tooltip: 'Qualité',
            icon: const Icon(Icons.high_quality_outlined,
                color: Colors.white),
            onPressed: _showQualitySheet,
          ),
          IconButton(
            tooltip: 'Chromecast',
            icon: const Icon(Icons.cast_rounded, color: Colors.white),
            onPressed: _showCastSheet,
          ),
          IconButton(
            tooltip: 'Picture in Picture',
            icon: const Icon(Icons.picture_in_picture_alt_rounded,
                color: Colors.white),
            onPressed: _enterPip,
          ),
          IconButton(
            tooltip: 'Verrouiller l\'écran',
            icon: const Icon(Icons.lock_open_rounded, color: Colors.white),
            onPressed: _toggleLock,
          ),
        ],
      ),
    );
  }

  Widget _centerControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!_isLive)
          IconButton(
            iconSize: 42,
            icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
            onPressed: () => _seekRelative(-10),
          ),
        const SizedBox(width: 24),
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.15),
            border: Border.all(color: Colors.white30),
          ),
          child: IconButton(
            iconSize: 56,
            icon: Icon(
              _isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: Colors.white,
            ),
            onPressed: _togglePlayPause,
          ),
        ),
        const SizedBox(width: 24),
        if (!_isLive)
          IconButton(
            iconSize: 42,
            icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
            onPressed: () => _seekRelative(10),
          ),
        if (_hasNext) ...[
          const SizedBox(width: 12),
          IconButton(
            iconSize: 42,
            tooltip: 'Épisode suivant',
            icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
            onPressed: _playNext,
          ),
        ],
      ],
    );
  }

  Widget _bottomBar() {
    if (_isLive) return const SizedBox(height: 12);
    final maxSeconds =
        _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1.0;
    final value = _dragging
        ? _dragValue
        : _position.inSeconds.clamp(0, maxSeconds.toInt()).toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
              activeTrackColor: AppColors.seed,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              min: 0,
              max: maxSeconds,
              value: value.clamp(0.0, maxSeconds).toDouble(),
              onChangeStart: (v) {
                _hideTimer?.cancel();
                setState(() {
                  _dragging = true;
                  _dragValue = v;
                });
              },
              onChanged: (v) => setState(() => _dragValue = v),
              onChangeEnd: (v) async {
                await _controller.seekTo(Duration(seconds: v.round()));
                setState(() {
                  _dragging = false;
                  _position = Duration(seconds: v.round());
                });
                _scheduleHide();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Text(
                  Formatters.duration(
                      _dragging ? Duration(seconds: _dragValue.round()) : _position),
                  style:
                      const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _showSpeedSheet,
                  icon: const Icon(Icons.speed_rounded,
                      color: Colors.white70, size: 18),
                  label: Text(
                    _speed == 1.0 ? '1×' : '$_speed×',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12),
                  ),
                ),
                Text(
                  Formatters.duration(_duration),
                  style:
                      const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Indicateurs de gestes ----------------

  Widget _gestureIndicator() {
    late final IconData icon;
    late final String label;
    switch (_gesture) {
      case _GestureKind.volume:
        icon = _gestureValue == 0
            ? Icons.volume_off_rounded
            : Icons.volume_up_rounded;
        label = '${(_gestureValue * 100).round()} %';
      case _GestureKind.brightness:
        icon = Icons.brightness_6_rounded;
        label = '${(_gestureValue * 100).round()} %';
      case _GestureKind.seek:
        icon = Icons.fast_forward_rounded;
        label =
            '${Formatters.duration(_seekTarget)} / ${Formatters.duration(_duration)}';
      case _GestureKind.none:
        return const SizedBox.shrink();
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 34),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
            if (_gesture == _GestureKind.volume ||
                _gesture == _GestureKind.brightness) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: 140,
                child: LinearProgressIndicator(
                  value: _gestureValue,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(4),
                  backgroundColor: Colors.white24,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.seed),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------- Mode verrouillé ----------------

  Widget _lockOverlay() {
    return AnimatedOpacity(
      opacity: _lockHintVisible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !_lockHintVisible,
        child: SafeArea(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: FloatingActionButton.small(
                heroTag: 'unlock',
                backgroundColor: Colors.black87,
                onPressed: _toggleLock,
                child:
                    const Icon(Icons.lock_rounded, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- Vue Chromecast ----------------

  Widget _castView() {
    final connecting = _cast.state == CastState.connecting;
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Text(
                    _current.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.cast_connected_rounded,
                size: 64,
                color: connecting ? Colors.white38 : AppColors.seed),
            const SizedBox(height: 16),
            Text(
              connecting
                  ? 'Connexion à ${_cast.device?.name ?? 'l\'appareil'}...'
                  : 'Diffusion sur ${_cast.device?.name ?? 'Chromecast'}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 24),
            if (!connecting)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_isLive)
                    IconButton(
                      iconSize: 36,
                      icon: const Icon(Icons.replay_30_rounded,
                          color: Colors.white),
                      onPressed: () => _cast.seek(
                          _position - const Duration(seconds: 30)),
                    ),
                  const SizedBox(width: 16),
                  IconButton(
                    iconSize: 52,
                    icon: Icon(
                      _cast.isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_filled_rounded,
                      color: Colors.white,
                    ),
                    onPressed: _cast.togglePlayPause,
                  ),
                  const SizedBox(width: 16),
                  if (!_isLive)
                    IconButton(
                      iconSize: 36,
                      icon: const Icon(Icons.forward_30_rounded,
                          color: Colors.white),
                      onPressed: () => _cast.seek(
                          _position + const Duration(seconds: 30)),
                    ),
                ],
              ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _stopCasting,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Arrêter la diffusion'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  // ---------------- Épisode suivant ----------------

  Widget _nextEpisodeOverlay() {
    return Positioned(
      right: 20,
      bottom: 32,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white24),
          boxShadow: AppColors.softShadow(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Épisode suivant dans $_countdown s',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 220,
              child: Text(
                widget.args.queue[_queueIndex + 1].title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _playNext,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Lire maintenant'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _cancelCountdown,
                  child: const Text('Annuler'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
