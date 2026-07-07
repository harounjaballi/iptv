import 'dart:async';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/cache/app_cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/live_channel.dart';
import '../../providers/live_providers.dart';
import '../../providers/stats_providers.dart';
import '../../themes/app_colors.dart';
import '../../widgets/epg_now_next_view.dart';
import '../../widgets/glass_container.dart';

/// Arguments du lecteur live (liste pour le zapping + index de départ).
class LivePlayerArgs {
  final List<LiveChannel> channels;
  final int initialIndex;

  const LivePlayerArgs({required this.channels, required this.initialIndex});
}

/// Lecteur live plein écran avec zapping ultra rapide :
/// - un seul contrôleur ExoPlayer réutilisé (setupDataSource) ;
/// - zapping debouncé : l'UI change instantanément, le flux démarre
///   ~300 ms après le dernier appui (comme TiviMate) ;
/// - ▲/▼ ou glissement vertical = chaîne suivante/précédente ;
/// - OK / tap = bandeau d'infos (chaîne + EPG actuel/suivant) ;
/// - ◀ / bouton liste = liste des chaînes en superposition ;
/// - chaque lecture alimente « Récents » et la reprise de lecture.
class LivePlayerScreen extends ConsumerStatefulWidget {
  final LivePlayerArgs args;

  const LivePlayerScreen({super.key, required this.args});

  @override
  ConsumerState<LivePlayerScreen> createState() => _LivePlayerScreenState();
}

class _LivePlayerScreenState extends ConsumerState<LivePlayerScreen> {
  BetterPlayerController? _controller;
  late int _index;

  bool _overlayVisible = true;
  bool _listVisible = false;
  bool _buffering = false;
  bool _error = false;

  Timer? _zapDebounce;
  Timer? _overlayTimer;
  Timer? _statsTimer;

  LiveChannel get _channel => widget.args.channels[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.args.initialIndex
        .clamp(0, widget.args.channels.length - 1)
        .toInt();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(previewEnabledProvider.notifier).state = false;
      _startPlayback();
      _registerWatch();
      _scheduleOverlayHide();
      // Statistiques : +15 s de visionnage TV tant que la lecture est active.
      ref.read(watchStatsProvider.notifier).registerPlay();
      _statsTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (_controller?.isPlaying() ?? false) {
          ref.read(watchStatsProvider.notifier).addSeconds('live', 15);
        }
      });
    });
  }

  @override
  void dispose() {
    _zapDebounce?.cancel();
    _overlayTimer?.cancel();
    _statsTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller?.dispose(forceDispose: true);
    super.dispose();
  }

  // ---------------- Lecture ----------------

  void _registerWatch() =>
      ref.read(liveRecentsProvider.notifier).registerWatch(_channel.streamId);

  Future<void> _startPlayback() async {
    final url = ref.read(liveUrlResolverProvider)(_channel);
    if (url == null) {
      setState(() => _error = true);
      return;
    }
    setState(() {
      _error = false;
      _buffering = true;
    });

    final source = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      url,
      liveStream: true,
      bufferingConfiguration: const BetterPlayerBufferingConfiguration(
        minBufferMs: 2000,
        maxBufferMs: 30000,
        bufferForPlaybackMs: 900, // démarrage très rapide
        bufferForPlaybackAfterRebufferMs: 2000,
      ),
    );

    try {
      if (_controller == null) {
        _controller = BetterPlayerController(
          const BetterPlayerConfiguration(
            autoPlay: true,
            fit: BoxFit.contain,
            handleLifecycle: true,
            allowedScreenSleep: false,
            autoDispose: false,
            controlsConfiguration:
                BetterPlayerControlsConfiguration(showControls: false),
          ),
          betterPlayerDataSource: source,
        );
        _controller!.addEventsListener(_onPlayerEvent);
        setState(() {});
      } else {
        await _controller!.setupDataSource(source);
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    if (!mounted) return;
    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.bufferingStart:
        setState(() => _buffering = true);
      case BetterPlayerEventType.bufferingEnd:
      case BetterPlayerEventType.play:
        setState(() => _buffering = false);
      case BetterPlayerEventType.exception:
        setState(() {
          _error = true;
          _buffering = false;
        });
      default:
        break;
    }
  }

  // ---------------- Zapping ultra rapide ----------------

  void _zap(int delta) {
    final count = widget.args.channels.length;
    if (count == 0) return;
    setState(() {
      _index = (_index + delta + count) % count;
      _error = false;
      _buffering = true;
    });
    _showOverlay();

    // Debounce : l'UI suit chaque appui, le flux ne démarre
    // qu'après une courte pause (zapping en rafale fluide).
    _zapDebounce?.cancel();
    _zapDebounce = Timer(const Duration(milliseconds: 300), () {
      _startPlayback();
      _registerWatch();
    });
  }

  void _zapTo(int index) {
    if (index == _index) {
      setState(() => _listVisible = false);
      return;
    }
    setState(() {
      _index = index;
      _listVisible = false;
      _error = false;
      _buffering = true;
    });
    _showOverlay();
    _zapDebounce?.cancel();
    _zapDebounce = Timer(const Duration(milliseconds: 150), () {
      _startPlayback();
      _registerWatch();
    });
  }

  // ---------------- Overlay ----------------

  void _showOverlay() {
    setState(() => _overlayVisible = true);
    _scheduleOverlayHide();
  }

  void _scheduleOverlayHide() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_listVisible) setState(() => _overlayVisible = false);
    });
  }

  void _toggleOverlay() {
    if (_overlayVisible) {
      _overlayTimer?.cancel();
      setState(() => _overlayVisible = false);
    } else {
      _showOverlay();
    }
  }

  // ---------------- Entrées (télécommande / gestes) ----------------

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (_listVisible &&
        (key == LogicalKeyboardKey.escape ||
            key == LogicalKeyboardKey.goBack)) {
      setState(() => _listVisible = false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.channelUp) {
      _zap(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.channelDown) {
      _zap(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      setState(() => _listVisible = true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter) {
      _toggleOverlay();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.space) {
      final playing = _controller?.isPlaying() ?? false;
      playing ? _controller?.pause() : _controller?.play();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(liveFavoritesProvider);
    final isFavorite = favorites.contains(_channel.streamId);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleOverlay,
          onVerticalDragEnd: (details) {
            final v = details.primaryVelocity ?? 0;
            if (v < -260) _zap(1); // glisser vers le haut → suivante
            if (v > 260) _zap(-1); // glisser vers le bas → précédente
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ---- Vidéo ----
              if (_controller != null)
                Center(child: BetterPlayer(controller: _controller!)),

              // ---- Chargement / erreur ----
              if (_buffering && !_error)
                const Center(
                  child: CircularProgressIndicator(
                      color: Colors.white70, strokeWidth: 2.6),
                ),
              if (_error)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.white54, size: 52),
                      const SizedBox(height: 10),
                      const Text('Lecture impossible',
                          style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _startPlayback,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),

              // ---- Bandeau d'infos (bas) ----
              AnimatedSlide(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                offset: _overlayVisible ? Offset.zero : const Offset(0, 1.2),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    child: GlassContainer(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      blur: 22,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Logo
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 58,
                              height: 58,
                              child: _channel.logoUrl.isEmpty
                                  ? Container(
                                      color: Colors.white.withValues(alpha: 0.08),
                                      child: const Icon(Icons.live_tv,
                                          color: Colors.white38),
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: _channel.logoUrl,
                                      cacheManager: AppCacheManager.instance,
                                      memCacheWidth: 480, // ~160dp × 3 (compression mémoire)
                                      fit: BoxFit.contain,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Nom + EPG
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (_channel.number > 0) ...[
                                      Text(
                                        '${_channel.number}',
                                        style: const TextStyle(
                                            color: AppColors.cyan,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Expanded(
                                      child: Text(
                                        _channel.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                EpgNowNextView(streamId: _channel.streamId),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            children: [
                              IconButton(
                                onPressed: () => ref
                                    .read(liveFavoritesProvider.notifier)
                                    .toggle(_channel.streamId),
                                icon: Icon(
                                  isFavorite
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: isFavorite
                                      ? Colors.amber
                                      : Colors.white54,
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    setState(() => _listVisible = true),
                                icon: const Icon(Icons.list_rounded,
                                    color: Colors.white54),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ---- Liste des chaînes (superposition latérale) ----
              if (_listVisible)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => _listVisible = false),
                    child: Container(
                      color: Colors.black54,
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () {}, // absorbe les taps sur le panneau
                        child: GlassContainer(
                          margin: const EdgeInsets.all(16),
                          blur: 26,
                          child: SizedBox(
                            width: 330,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              itemCount: widget.args.channels.length,
                              itemExtent: 56,
                              itemBuilder: (context, i) {
                                final c = widget.args.channels[i];
                                final selected = i == _index;
                                return ListTile(
                                  dense: true,
                                  selected: selected,
                                  selectedTileColor:
                                      AppColors.seed.withValues(alpha: 0.25),
                                  autofocus: selected,
                                  leading: SizedBox(
                                    width: 34,
                                    height: 34,
                                    child: c.logoUrl.isEmpty
                                        ? const Icon(Icons.live_tv,
                                            color: Colors.white30, size: 20)
                                        : CachedNetworkImage(
                                            imageUrl: c.logoUrl,
                                            cacheManager: AppCacheManager.instance,
                                            memCacheWidth: 480, // ~160dp × 3 (compression mémoire)
                                            fit: BoxFit.contain,
                                            memCacheHeight: 68,
                                          ),
                                  ),
                                  title: Text(
                                    c.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 13),
                                  ),
                                  onTap: () => _zapTo(i),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(duration: 160.ms),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
