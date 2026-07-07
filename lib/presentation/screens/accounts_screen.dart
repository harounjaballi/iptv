import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/iptv_account.dart';
import '../../providers/auth_provider.dart';
import '../../themes/app_colors.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/premium_background.dart';

/// Gestionnaire de comptes IPTV : liste des comptes enregistrés,
/// changement de compte, suppression, ajout d'un nouveau compte.
class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  String? _switchingId;

  IconData _iconFor(AccountSourceType type) => switch (type) {
        AccountSourceType.xtream => Icons.dns_outlined,
        AccountSourceType.m3uUrl => Icons.link_outlined,
        AccountSourceType.m3uFile => Icons.insert_drive_file_outlined,
        AccountSourceType.mac => Icons.router_outlined,
      };

  Future<void> _switchTo(IptvAccount account) async {
    if (_switchingId != null) return;
    setState(() => _switchingId = account.id);

    final ok =
        await ref.read(authProvider.notifier).switchAccount(account);
    if (!mounted) return;
    setState(() => _switchingId = null);

    if (ok) {
      context.go('/home');
      return;
    }
    final state = ref.read(authProvider);
    if (state is AuthError) {
      if (state.activationPending) {
        context.push('/mac-activation');
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(state.message)));
      }
    }
  }

  Future<void> _confirmDelete(IptvAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce compte ?'),
        content: Text(
            '« ${account.name} » sera définitivement supprimé de cet appareil.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref.read(authProvider.notifier).deleteAccount(account);
    ref.invalidate(savedAccountsProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Compte supprimé')));
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(savedAccountsProvider);
    final active = ref.watch(activeAccountProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        if (context.canPop())
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () => context.pop(),
                          ),
                        Expanded(
                          child: Text(
                            'Mes comptes IPTV',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Ajouter un compte',
                          icon: const Icon(Icons.add_circle_outline,
                              color: Colors.white),
                          onPressed: () => context.push('/login'),
                        ),
                      ],
                    ),
                    if (authState is AuthReconnecting)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Reconnexion automatique '
                          '(${authState.attempt}/${authState.maxAttempts})…',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.amberAccent, fontSize: 13),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: accounts.when(
                        data: (list) => list.isEmpty
                            ? _emptyState(context)
                            : ListView.separated(
                                itemCount: list.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, i) {
                                  final account = list[i];
                                  final isActive =
                                      active?.id == account.id;
                                  final isSwitching =
                                      _switchingId == account.id;
                                  return _accountTile(
                                      account, isActive, isSwitching);
                                },
                              ),
                        loading: () => const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white70)),
                        error: (e, _) => Center(
                          child: Text('Erreur : $e',
                              style:
                                  const TextStyle(color: Colors.white70)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _accountTile(
      IptvAccount account, bool isActive, bool isSwitching) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(18),
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: isActive ? AppColors.brandGradient : null,
            color: isActive ? null : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(_iconFor(account.type),
              color: Colors.white, size: 22),
        ),
        title: Text(
          account.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          account.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSwitching)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white70),
              )
            else if (isActive)
              const Icon(Icons.check_circle,
                  color: Colors.greenAccent, size: 20),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white54),
              onSelected: (value) {
                if (value == 'delete') _confirmDelete(account);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: Colors.red),
                    title: Text('Supprimer'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: isActive && _switchingId == null
            ? () => context.go('/home')
            : () => _switchTo(account),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.account_circle_outlined,
              size: 64, color: Colors.white30),
          const SizedBox(height: 12),
          const Text('Aucun compte enregistré',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.go('/login'),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un compte'),
          ),
        ],
      ),
    );
  }
}
