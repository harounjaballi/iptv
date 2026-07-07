import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/i18n/app_translations.dart';
import 'providers/settings_providers.dart';
import 'providers/theme_provider.dart';
import 'routes/app_router.dart';
import 'themes/app_theme.dart';

/// Widget racine : MaterialApp.router + thèmes personnalisables + langue.
class PremiumIptvApp extends ConsumerWidget {
  const PremiumIptvApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final language = ref.watch(languageProvider);
    final accent = ref.watch(accentColorProvider);
    final amoled = ref.watch(amoledProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themed(brightness: Brightness.light, seed: accent),
      darkTheme: AppTheme.themed(
          brightness: Brightness.dark, seed: accent, amoled: amoled),
      themeMode: themeMode,
      // Langue de l'application (FR / EN / AR — RTL automatique en arabe).
      locale: language.locale,
      supportedLocales: [for (final l in AppLanguage.values) l.locale],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Défilement utilisable avec tous les types de pointeurs :
      // tactile, souris (Android TV / émulateur), trackpad, stylet.
      scrollBehavior: const _AppScrollBehavior(),
      routerConfig: appRouter,
    );
  }
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
