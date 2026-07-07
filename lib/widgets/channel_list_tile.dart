import 'package:cached_network_image/cached_network_image.dart';
import '../core/cache/app_cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/live_channel.dart';
import '../providers/live_providers.dart';
import '../themes/app_colors.dart';
import 'epg_now_next_view.dart';

/// Rangée de chaîne façon TiviMate : numéro, logo, nom,
/// programme en cours (EPG) + progression, étoile favori.
/// Compatible D-Pad (focus visible) et très légère (hauteur fixe).
class ChannelListTile extends ConsumerStatefulWidget {
  final LiveChannel channel;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<bool>? onFocus;

  const ChannelListTile({
    super.key,
    required this.channel,
    required this.onTap,
    this.selected = false,
    this.onFocus,
  });

  @override
  ConsumerState<ChannelListTile> createState() => _ChannelListTileState();
}

class _ChannelListTileState extends ConsumerState<ChannelListTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final channel = widget.channel;
    final isFavorite =
        ref.watch(liveFavoritesProvider).contains(channel.streamId);
    final highlighted = _focused || widget.selected;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: highlighted
              ? AppColors.seed.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlighted ? AppColors.seed : Colors.transparent,
            width: 1.6,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onFocusChange: (f) {
              setState(() => _focused = f);
              widget.onFocus?.call(f);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  // Numéro
                  SizedBox(
                    width: 36,
                    child: Text(
                      channel.number > 0 ? '${channel.number}' : '·',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  // Logo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: channel.logoUrl.isEmpty
                          ? Container(
                              color: Colors.white.withValues(alpha: 0.06),
                              child: const Icon(Icons.live_tv,
                                  color: Colors.white30, size: 22),
                            )
                          : CachedNetworkImage(
                              imageUrl: channel.logoUrl,
                              cacheManager: AppCacheManager.instance,
                              memCacheWidth: 360, // ~120dp × 3 (compression mémoire)
                              fit: BoxFit.contain,
                              memCacheHeight: 88,
                              fadeInDuration:
                                  const Duration(milliseconds: 120),
                              errorWidget: (_, __, ___) => Container(
                                color: Colors.white.withValues(alpha: 0.06),
                                child: const Icon(Icons.live_tv,
                                    color: Colors.white30, size: 22),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Nom + EPG compact
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          channel.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        EpgNowNextView(
                            streamId: channel.streamId, compact: true),
                      ],
                    ),
                  ),
                  // Favori
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => ref
                        .read(liveFavoritesProvider.notifier)
                        .toggle(channel.streamId),
                    icon: Icon(
                      isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: isFavorite ? Colors.amber : Colors.white30,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
