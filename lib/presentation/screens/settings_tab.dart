import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_translations.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/parental_providers.dart';
import '../../providers/profile_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/theme_provider.dart';
import '../../services/backup_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/pin_dialog.dart';
import 'profiles_screen.dart' show profileColors;
import '../../core/cache/app_cache_manager.dart';

/// Réglages complets : profils, apparence (thème, AMOLED, accent),
/// langue, contrôle parental, statistiques, cache,
/// sauvegarde locale & synchronisation, comptes.
class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  /// Les réglages sensibles sont protégés par le PIN pour un profil enfant.
  Future<bool> _guard(BuildContext context, WidgetRef ref) async {
    if (!ref.read(activeProfileProvider).isKids) return true;
    final pinNotifier = ref.read(parentalPinProvider.notifier);
    if (!pinNotifier.isSet) return true;
    final l10n = ref.read(l10nProvider);
    final pin = await showPinInputDialog(context,
        title: l10n.enterPin, cancelLabel: l10n.cancel);
    if (pin == null) return false;
    final ok = pinNotifier.verify(pin);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.wrongPin)));
    }
    return ok;
  }

  void _snack(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = ref.read(l10nProvider);
    var includeAccounts = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.exportBackup),
          content: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.includeAccounts),
            value: includeAccounts,
            onChanged: (v) => setState(() => includeAccounts = v),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel)),
            FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.confirm)),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    final service = BackupService(
        ref.read(cacheServiceProvider), ref.read(accountStorageProvider));
    try {
      final path =
          await service.exportToFile(includeAccounts: includeAccounts);
      if (path != null && context.mounted) _snack(context, l10n.backupDone);
    } catch (e) {
      if (context.mounted) _snack(context, e.toString());
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref,
      {required bool merge}) async {
    final l10n = ref.read(l10nProvider);
    final service = BackupService(
        ref.read(cacheServiceProvider), ref.read(accountStorageProvider));
    try {
      final done = await service.importFromFile(merge: merge);
      if (done && context.mounted) {
        _snack(context, l10n.importDone);
        // Recharge les providers persistés (favoris, progression, profils...).
        ref.invalidate(profilesProvider);
      }
    } catch (e) {
      if (context.mounted) _snack(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final themeMode = ref.watch(themeModeProvider);
    final language = ref.watch(languageProvider);
    final amoled = ref.watch(amoledProvider);
    final accentIndex = ref.watch(accentProvider);
    final authState = ref.watch(authProvider);
    final profile = ref.watch(activeProfileProvider);
    final cache = ref.watch(cacheServiceProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.settings,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // ---------- Profil actif ----------
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    profileColors[profile.colorIndex % profileColors.length],
                child: Text(profile.initial,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              title: Text(profile.name),
              subtitle: Text(
                  profile.isKids ? l10n.kidsProfile : l10n.activeProfile),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/profiles'),
            ),
          ),
          const SizedBox(height: 16),

          // ---------- Compte ----------
          if (authState is AuthAuthenticated) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(l10n.account,
                              style:
                                  Theme.of(context).textTheme.titleMedium),
                        ),
                        if (authState.offline)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: const Icon(Icons.cloud_off, size: 16),
                            label: Text(l10n.offline),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('${authState.account.name} · '
                        '${authState.account.type.label}'),
                    if (authState.info != null)
                      Text(
                          'Exp. : ${Formatters.expiryDate(authState.info!.expDate)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ---------- Apparence ----------
          Card(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.appearance,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(
                          value: ThemeMode.system,
                          label: Text(l10n.themeSystem),
                          icon: const Icon(Icons.brightness_auto_rounded)),
                      ButtonSegment(
                          value: ThemeMode.light,
                          label: Text(l10n.themeLight),
                          icon: const Icon(Icons.light_mode_rounded)),
                      ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text(l10n.themeDark),
                          icon: const Icon(Icons.dark_mode_rounded)),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (s) =>
                        ref.read(themeModeProvider.notifier).setMode(s.first),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.amoled),
                    subtitle: Text(l10n.amoledSubtitle,
                        style: const TextStyle(fontSize: 12)),
                    value: amoled,
                    onChanged: (v) =>
                        ref.read(amoledProvider.notifier).toggle(v),
                  ),
                  Text(l10n.accentColor,
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: [
                      for (var i = 0; i < accentOptions.length; i++)
                        GestureDetector(
                          onTap: () =>
                              ref.read(accentProvider.notifier).setIndex(i),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: accentOptions[i].color,
                            child: accentIndex == i
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 16)
                                : null,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ---------- Langue ----------
          Card(
            child: ListTile(
              leading: const Icon(Icons.language_rounded),
              title: Text(l10n.language),
              trailing: DropdownButton<AppLanguage>(
                value: language,
                underline: const SizedBox.shrink(),
                items: [
                  for (final lang in AppLanguage.values)
                    DropdownMenuItem(
                        value: lang, child: Text(lang.label)),
                ],
                onChanged: (lang) {
                  if (lang != null) {
                    ref.read(languageProvider.notifier).setLanguage(lang);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ---------- Parental / Statistiques ----------
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: Text(l10n.parentalControl),
                  subtitle: ref.watch(parentalEnabledProvider)
                      ? Text(l10n.pinCode)
                      : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/parental'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.insights_rounded),
                  title: Text(l10n.statistics),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/stats'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---------- Cache ----------
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.storage_rounded),
                  title: Text(l10n.cache),
                  subtitle: Text(
                      '${cache.cacheEntryCount + cache.settingsEntryCount + cache.favoritesEntryCount} entrées'),
                ),
                const Divider(height: 1),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.video_library_outlined),
                  title: Text(l10n.clearCatalogs),
                  onTap: () async {
                    await cache.clearCatalogCache();
                    if (context.mounted) _snack(context, l10n.cacheCleared);
                  },
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.image_outlined),
                  title: Text(l10n.clearImages),
                  onTap: () async {
                    await DefaultCacheManager().emptyCache();
                    await AppCacheManager.clear();
                    PaintingBinding.instance.imageCache.clear();
                    if (context.mounted) _snack(context, l10n.cacheCleared);
                  },
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.delete_sweep_outlined),
                  title: Text(l10n.clearAll),
                  onTap: () async {
                    await cache.clearCache();
                    await cache.compact();
                    await DefaultCacheManager().emptyCache();
                    await AppCacheManager.clear();
                    PaintingBinding.instance.imageCache.clear();
                    if (context.mounted) _snack(context, l10n.cacheCleared);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---------- Sauvegarde & synchronisation ----------
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.save_alt_rounded),
                  title: Text(l10n.exportBackup),
                  onTap: () async {
                    if (await _guard(context, ref) && context.mounted) {
                      await _export(context, ref);
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sync_rounded),
                  title: Text(l10n.importMerge),
                  subtitle: Text(l10n.importMergeSubtitle,
                      style: const TextStyle(fontSize: 12)),
                  onTap: () async {
                    if (await _guard(context, ref) && context.mounted) {
                      await _import(context, ref, merge: true);
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings_backup_restore_rounded),
                  title: Text(l10n.restoreBackup),
                  subtitle: Text(l10n.restoreBackupSubtitle,
                      style: const TextStyle(fontSize: 12)),
                  onTap: () async {
                    if (await _guard(context, ref) && context.mounted) {
                      await _import(context, ref, merge: false);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---------- Comptes / Déconnexion ----------
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.switch_account_outlined),
                  title: Text(l10n.myAccounts),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    if (await _guard(context, ref) && context.mounted) {
                      context.push('/accounts');
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.logout,
                      color: Theme.of(context).colorScheme.error),
                  title: Text(l10n.logout,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                  onTap: () async {
                    if (!await _guard(context, ref) || !context.mounted) {
                      return;
                    }
                    final notifier = ref.read(authProvider.notifier);
                    await notifier.logout();
                    final remaining = await notifier.accounts();
                    if (context.mounted) {
                      context
                          .go(remaining.isNotEmpty ? '/accounts' : '/login');
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
