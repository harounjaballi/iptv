import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/epg_program.dart';
import '../providers/live_providers.dart';
import '../themes/app_colors.dart';

/// Affiche « En ce moment » + « Ensuite » d'une chaîne (avec progression).
class EpgNowNextView extends ConsumerWidget {
  final int streamId;
  final bool compact;

  const EpgNowNextView({
    super.key,
    required this.streamId,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final epg = ref.watch(epgNowNextProvider(streamId));
    final hm = DateFormat.Hm();

    return epg.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (pair) {
        if (pair.isEmpty) {
          return compact
              ? const SizedBox.shrink()
              : const Text('Guide TV indisponible',
                  style: TextStyle(color: Colors.white38, fontSize: 12));
        }
        final now = pair.now;
        final next = pair.next;

        if (compact) {
          // Une ligne : titre du programme + mini barre de progression.
          if (now == null) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                now.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 11.5),
              ),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: now.progress,
                  minHeight: 2.5,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.seed),
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (now != null) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('EN CE MOMENT',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${hm.format(now.start)} – ${hm.format(now.end)}',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11.5),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                now.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: now.progress,
                  minHeight: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.seed),
                ),
              ),
              if (now.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  now.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ],
            if (next != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.skip_next_rounded,
                      color: Colors.white38, size: 16),
                  const SizedBox(width: 4),
                  Text('Ensuite ${hm.format(next.start)} : ',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12)),
                  Expanded(
                    child: Text(
                      next.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
