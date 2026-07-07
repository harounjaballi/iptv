import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../themes/app_colors.dart';
import '../utils/formatters.dart';

/// Navigation Drawer M3 premium : en-tête dégradé avec infos du compte,
/// destinations synchronisées avec la navigation principale.
class AppDrawer extends ConsumerWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const AppDrawer({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final authenticated =
        authState is AuthAuthenticated ? authState : null;
    final account = authenticated?.account;
    final info = authenticated?.info;

    return NavigationDrawer(
      selectedIndex: selectedIndex,
      onDestinationSelected: (i) {
        Navigator.of(context).pop();
        onSelect(i);
      },
      children: [
        // En-tête compte
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppColors.glow(AppColors.seed, blur: 18),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white54),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account?.name ?? 'Invité',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      info != null
                          ? 'Expire : ${Formatters.expiryDate(info.expDate)}'
                          : (account?.type.label ?? ''),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.live_tv_outlined),
          selectedIcon: Icon(Icons.live_tv),
          label: Text('TV en direct'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.movie_outlined),
          selectedIcon: Icon(Icons.movie),
          label: Text('Films'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.video_library_outlined),
          selectedIcon: Icon(Icons.video_library),
          label: Text('Séries'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('Réglages'),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 28, vertical: 10),
          child: Divider(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ListTile(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            leading: const Icon(Icons.switch_account_outlined),
            title: const Text('Mes comptes IPTV'),
            onTap: () {
              Navigator.of(context).pop();
              context.push('/accounts');
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ListTile(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            leading:
                Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
            title: Text('Déconnexion',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () async {
              final notifier = ref.read(authProvider.notifier);
              await notifier.logout();
              final remaining = await notifier.accounts();
              if (context.mounted) {
                context.go(remaining.isNotEmpty ? '/accounts' : '/login');
              }
            },
          ),
        ),
      ],
    );
  }
}
