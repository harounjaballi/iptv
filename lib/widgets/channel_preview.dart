import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/live_channel.dart';
import '../providers/live_providers.dart';

/// Aperçu vidéo intégré d'une chaîne (panneau latéral TV / desktop).
/// Réutilise un seul contrôleur : changer de chaîne ne recrée pas le
/// lecteur (setupDataSource), pour un aperçu quasi instantané.
class ChannelPreview extends ConsumerStatefulWidget {
  final LiveChannel channel;

  const ChannelPreview({super.key, required this.channel});

  @override
  ConsumerState<ChannelPreview> createState() => _ChannelPreviewState();
}

class _ChannelPreviewState extends ConsumerState<ChannelPreview> {
  BetterPlayerController? _controller;
  String? _currentUrl;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(ChannelPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel.streamId != widget.channel.streamId) _load();
  }

  Future<void> _load() async {
    final resolver = ref.read(liveUrlResolverProvider);
    final url = resolver(widget.channel);
    if (url == null || url == _currentUrl) return;
    _currentUrl = url;
    setState(() => _error = false);

    final source = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      url,
      liveStream: true,
      bufferingConfiguration: const BetterPlayerBufferingConfiguration(
        minBufferMs: 2500,
        maxBufferMs: 20000,
        bufferForPlaybackMs: 1000,
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
            controlsConfiguration:
                BetterPlayerControlsConfiguration(showControls: false),
          ),
          betterPlayerDataSource: source,
        );
        _controller!.addEventsListener(_onEvent);
        if (mounted) setState(() {});
      } else {
        await _controller!.setupDataSource(source);
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  void _onEvent(BetterPlayerEvent event) {
    if (event.betterPlayerEventType == BetterPlayerEventType.exception &&
        mounted) {
      setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _controller?.removeEventsListener(_onEvent);
    _controller?.dispose(forceDispose: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Coupe l'aperçu quand le plein écran est ouvert (double audio).
    final enabled = ref.watch(previewEnabledProvider);
    ref.listen(previewEnabledProvider, (prev, next) {
      if (next == false) {
        _controller?.pause();
      } else if (prev == false && next == true) {
        _controller?.play();
      }
    });

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.black,
          child: _error
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tv_off, color: Colors.white30, size: 36),
                      SizedBox(height: 8),
                      Text('Aperçu indisponible',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                )
              : (_controller == null || !enabled)
                  ? const Center(
                      child: Icon(Icons.live_tv,
                          color: Colors.white24, size: 48))
                  : BetterPlayer(controller: _controller!),
        ),
      ),
    );
  }
}
