import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_profile.dart';
import '../../providers/parental_providers.dart';
import '../../providers/profile_providers.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/pin_dialog.dart';

/// Palette d'avatars des profils.
const profileColors = <Color>[
  Color(0xFF7C3AED),
  Color(0xFFDB2777),
  Color(0xFF2563EB),
  Color(0xFF059669),
  Color(0xFFEA580C),
  Color(0xFF0891B2),
  Color(0xFFDC2626),
  Color(0xFFCA8A04),
];

/// Gestion des profils utilisateurs (façon Netflix) :
/// chaque profil a ses favoris, son historique, sa progression
/// et ses statistiques. Les profils enfants appliquent le contrôle parental.
class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  Color _colorOf(UserProfile p) =>
      profileColors[p.colorIndex % profileColors.length];

  Future<bool> _checkPin(BuildContext context, WidgetRef ref) async {
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

  Future<void> _editProfile(BuildContext context, WidgetRef ref,
      {UserProfile? profile}) async {
    final l10n = ref.read(l10nProvider);
    // La création/modification de profils est protégée par le PIN
    // (empêche un enfant de sortir de son profil restreint).
    if (ref.read(activeProfileProvider).isKids &&
        !await _checkPin(context, ref)) {
      return;
    }
    if (!context.mounted) return;

    final nameCtrl = TextEditingController(text: profile?.name ?? '');
    var colorIndex = profile?.colorIndex ?? 0;
    var isKids = profile?.isKids ?? false;
    final isMain = profile?.id == UserProfile.main.id;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(profile == null ? l10n.addProfile : l10n.editProfile),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: profile == null,
                maxLength: 20,
                decoration: InputDecoration(
                    labelText: l10n.profileName, counterText: ''),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < profileColors.length; i++)
                    GestureDetector(
                      onTap: () => setState(() => colorIndex = i),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: profileColors[i],
                        child: colorIndex == i
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 18)
                            : null,
                      ),
                    ),
                ],
              ),
              if (!isMain)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.kidsProfile),
                  subtitle: Text(l10n.kidsProfileSubtitle,
                      style: const TextStyle(fontSize: 12)),
                  value: isKids,
                  onChanged: (v) => setState(() => isKids = v),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final notifier = ref.read(profilesProvider.notifier);
                if (profile == null) {
                  await notifier.add(name,
                      colorIndex: colorIndex, isKids: isKids);
                } else {
                  await notifier.update(profile.copyWith(
                      name: name, colorIndex: colorIndex, isKids: isKids));
                }
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final profiles = ref.watch(profilesProvider);
    final activeId = ref.watch(activeProfileIdProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profiles)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final p in profiles)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _colorOf(p),
                  child: Text(p.initial,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
                title: Text(p.name),
                subtitle: p.isKids ? Text(l10n.kidsProfile) : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (p.id == activeId)
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.greenAccent)
                    else
                      IconButton(
                        icon: const Icon(Icons.login_rounded),
                        tooltip: l10n.activeProfile,
                        onPressed: () async {
                          // Quitter un profil enfant demande le PIN.
                          if (ref.read(activeProfileProvider).isKids &&
                              !await _checkPin(context, ref)) {
                            return;
                          }
                          await ref
                              .read(activeProfileIdProvider.notifier)
                              .select(p.id);
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () =>
                          _editProfile(context, ref, profile: p),
                    ),
                    if (p.id != UserProfile.main.id)
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          if (!await _checkPin(context, ref)) return;
                          await ref
                              .read(profilesProvider.notifier)
                              .remove(p.id);
                        },
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _editProfile(context, ref),
            icon: const Icon(Icons.person_add_alt_rounded),
            label: Text(l10n.addProfile),
          ),
        ],
      ),
    );
  }
}
