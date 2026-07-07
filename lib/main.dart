import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/perf/perf_mode.dart';
import 'providers/app_providers.dart';
import 'services/cache_service.dart';
import 'services/tv_detector_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ---- Gestion d'erreurs globale ----
  // Aucune exception non interceptée ne doit faire planter l'application
  // (essentiel pour le Play Store : le taux de crash impacte la visibilité).
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kReleaseMode) {
      // En release : journalisé, jamais fatal.
      debugPrint('FlutterError: ${details.exceptionAsString()}');
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught: $error');
    return true; // consommée : pas de crash
  };

  // ---- Mémoire : borne du cache d'images en RAM ----
  // Par défaut Flutter autorise 100 Mo / 1000 images ; avec des milliers de
  // posters décodés à leur taille d'affichage (OptimizedImage), 80 Mo
  // suffisent largement et laissent la RAM au décodage vidéo — critique sur
  // Fire TV Stick (1 à 1,5 Go de RAM utilisable).
  PaintingBinding.instance.imageCache
    ..maximumSize = 300
    ..maximumSizeBytes = 80 << 20; // 80 Mo

  // ---- Mode performance TV ----
  // Détecté une seule fois au démarrage : sur Android TV / Fire TV, les
  // animations décoratives sont désactivées (le GPU reste disponible pour
  // le décodage vidéo, et le repaint permanent est évité).
  PerfMode.isTv = await TvDetectorService().isTv();

  // Locale française pour intl (dates d'expiration, etc.)
  await initializeDateFormatting('fr');

  // Hive (cache, favoris, préférences)
  final cacheService = CacheService();
  await cacheService.init();

  runApp(
    ProviderScope(
      overrides: [
        cacheServiceProvider.overrideWithValue(cacheService),
      ],
      child: const PremiumIptvApp(),
    ),
  );
}
