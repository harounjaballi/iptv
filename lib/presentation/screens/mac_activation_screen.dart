import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../models/iptv_account.dart';
import '../../providers/auth_provider.dart';
import '../../themes/app_colors.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/premium_background.dart';

/// Écran d'activation par adresse MAC : affiche la MAC et le Device ID
/// à enregistrer sur le portail du fournisseur, puis vérifie
/// automatiquement le statut d'activation toutes les 5 secondes.
class MacActivationScreen extends ConsumerStatefulWidget {
  /// Compte MAC en attente. Si null, le compte actif enregistré est utilisé.
  final IptvAccount? account;

  const MacActivationScreen({super.key, this.account});

  @override
  ConsumerState<MacActivationScreen> createState() =>
      _MacActivationScreenState();
}

class _MacActivationScreenState extends ConsumerState<MacActivationScreen> {
  IptvAccount? _account;
  Timer? _timer;
  bool _checking = false;
  int _attempts = 0;
  String _status = 'En attente d\'activation…';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    var account = widget.account;
    if (account == null) {
      final accounts = await ref.read(authProvider.notifier).accounts();
      final repoActive = accounts
          .where((a) => a.type == AccountSourceType.mac)
          .toList();
      if (repoActive.isNotEmpty) account = repoActive.first;
    }
    if (!mounted) return;
    if (account == null) {
      context.go('/login');
      return;
    }
    setState(() => _account = account);
    _timer = Timer.periodic(
        AppConstants.activationPollInterval, (_) => _check(silent: true));
    _check(silent: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check({bool silent = false}) async {
    final account = _account;
    if (account == null || _checking) return;
    setState(() {
      _checking = true;
      if (!silent) _status = 'Vérification en cours…';
    });

    final ok =
        await ref.read(authProvider.notifier).switchAccount(account);
    if (!mounted) return;

    if (ok) {
      _timer?.cancel();
      context.go('/home');
      return;
    }

    final state = ref.read(authProvider);
    setState(() {
      _checking = false;
      _attempts++;
      if (state is AuthError) {
        _status = state.activationPending
            ? 'En attente d\'activation… (vérification n°$_attempts)'
            : state.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;

    return Scaffold(
      body: PremiumBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: GlassContainer(
                padding: const EdgeInsets.all(28),
                child: account == null
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(Icons.tv_outlined,
                                  size: 56, color: Colors.white)
                              .animate(
                                  onPlay: (c) => c.repeat(reverse: true))
                              .scale(
                                begin: const Offset(0.95, 0.95),
                                end: const Offset(1.05, 1.05),
                                duration: 1200.ms,
                              ),
                          const SizedBox(height: 18),
                          Text(
                            'Activation de l\'appareil',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Enregistrez les informations ci-dessous sur le '
                            'portail de votre fournisseur pour activer cet appareil.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white60),
                          ),
                          const SizedBox(height: 24),
                          _bigIdentityCard(
                            label: 'ADRESSE MAC',
                            value: account.mac ?? '—',
                          ),
                          const SizedBox(height: 12),
                          _bigIdentityCard(
                            label: 'DEVICE ID',
                            value: account.deviceId ?? '—',
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Portail : ${account.portalUrl ?? '—'}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _checking
                                      ? Colors.white
                                      : Colors.white30,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  _status,
                                  style: const TextStyle(
                                      color: Colors.amberAccent,
                                      fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          GradientButton(
                            label: 'Vérifier maintenant',
                            icon: Icons.refresh_rounded,
                            loading: _checking,
                            onPressed:
                                _checking ? null : () => _check(),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () => context.go('/login'),
                            child: const Text(
                              'Changer de mode de connexion',
                              style: TextStyle(color: Colors.white70),
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

  Widget _bigIdentityCard({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.seed.withValues(alpha: 0.25),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copier',
            icon: const Icon(Icons.copy_outlined, color: Colors.white54),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label copié')),
              );
            },
          ),
        ],
      ),
    );
  }
}
