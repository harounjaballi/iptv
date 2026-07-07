import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/app_translations.dart';
import 'app_providers.dart';

/// ---------------- Langue (FR / EN / AR) ----------------
class LanguageNotifier extends Notifier<AppLanguage> {
  static const _key = 'app_language';

  @override
  AppLanguage build() =>
      AppLanguage.fromCode(ref.read(cacheServiceProvider).getSetting(_key));

  Future<void> setLanguage(AppLanguage language) async {
    state = language;
    await ref
        .read(cacheServiceProvider)
        .putSetting(_key, language.locale.languageCode);
  }
}

final languageProvider =
    NotifierProvider<LanguageNotifier, AppLanguage>(LanguageNotifier.new);

/// Chaînes traduites pour la langue active.
final l10nProvider = Provider<L10n>((ref) => L10n.of(ref.watch(languageProvider)));

/// ---------------- Noir AMOLED ----------------
class AmoledNotifier extends Notifier<bool> {
  static const _key = 'theme_amoled';

  @override
  bool build() => ref.read(cacheServiceProvider).getSetting(_key) == '1';

  Future<void> toggle(bool value) async {
    state = value;
    await ref.read(cacheServiceProvider).putSetting(_key, value ? '1' : '0');
  }
}

final amoledProvider = NotifierProvider<AmoledNotifier, bool>(AmoledNotifier.new);

/// ---------------- Couleur d'accent ----------------
class AccentOption {
  final String name;
  final Color color;
  const AccentOption(this.name, this.color);
}

const accentOptions = <AccentOption>[
  AccentOption('Violet', Color(0xFF7C3AED)), // défaut (identité de l'app)
  AccentOption('Fuchsia', Color(0xFFDB2777)),
  AccentOption('Bleu', Color(0xFF2563EB)),
  AccentOption('Cyan', Color(0xFF0891B2)),
  AccentOption('Vert', Color(0xFF059669)),
  AccentOption('Orange', Color(0xFFEA580C)),
  AccentOption('Rouge', Color(0xFFDC2626)),
];

class AccentNotifier extends Notifier<int> {
  static const _key = 'theme_accent';

  @override
  int build() {
    final raw = ref.read(cacheServiceProvider).getSetting(_key);
    final index = int.tryParse(raw ?? '') ?? 0;
    return index.clamp(0, accentOptions.length - 1);
  }

  Future<void> setIndex(int index) async {
    state = index.clamp(0, accentOptions.length - 1);
    await ref.read(cacheServiceProvider).putSetting(_key, state.toString());
  }
}

final accentProvider = NotifierProvider<AccentNotifier, int>(AccentNotifier.new);

final accentColorProvider =
    Provider<Color>((ref) => accentOptions[ref.watch(accentProvider)].color);
