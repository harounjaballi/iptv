import 'package:cached_network_image/cached_network_image.dart';
import '../core/cache/app_cache_manager.dart';
import 'package:flutter/material.dart';

import '../models/live_channel.dart';
import 'focusable_card.dart';

/// Tuile de chaîne live (logo + nom + numéro), compatible D-Pad.
class ChannelTile extends StatelessWidget {
  final LiveChannel channel;
  final VoidCallback onTap;

  const ChannelTile({super.key, required this.channel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FocusableCard(
      onTap: onTap,
      child: Container(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: channel.logoUrl.isEmpty
                  ? Icon(Icons.live_tv, size: 36, color: scheme.primary)
                  : CachedNetworkImage(
                      imageUrl: channel.logoUrl,
                      cacheManager: AppCacheManager.instance,
                      memCacheWidth: 480, // ~160dp × 3 (compression mémoire)
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) =>
                          Icon(Icons.live_tv, size: 36, color: scheme.primary),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              channel.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
