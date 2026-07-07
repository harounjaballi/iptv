import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/iptv_account.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_provider.dart';
import '../../themes/app_colors.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/premium_background.dart';

/// Connexion multi-sources : Xtream Codes, URL M3U, Fichier M3U, Adresse MAC.
/// Toutes les informations sont validées auprès de la source avant d'être
/// enregistrées. Les comptes sont sauvegardés localement (multi-comptes).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  AccountSourceType _mode = AccountSourceType.xtream;

  final _formKey = GlobalKey<FormState>();

  // Champs communs
  final _nameCtrl = TextEditingController();

  // Xtream
  final _hostCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  // M3U URL
  final _m3uUrlCtrl = TextEditingController();

  // M3U fichier
  String? _pickedFilePath;
  String? _pickedFileName;

  // MAC
  final _portalCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _m3uUrlCtrl.dispose();
    _portalCtrl.dispose();
    super.dispose();
  }

  // ---------- Validations ----------

  String? _required(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '$label requis' : null;

  String? _validateServer(String? v) {
    final base = _required(v, 'Serveur');
    if (base != null) return base;
    final value = v!.trim();
    if (value.contains(' ')) return 'Le serveur ne doit pas contenir d\'espace';
    final normalized = value.startsWith('http') ? value : 'http://$value';
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.host.isEmpty) return 'Adresse de serveur invalide';
    return null;
  }

  String? _validateM3uUrl(String? v) {
    final base = _required(v, 'URL de la playlist');
    if (base != null) return base;
    final uri = Uri.tryParse(v!.trim());
    if (uri == null ||
        !uri.hasScheme ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      return 'URL invalide (elle doit commencer par http:// ou https://)';
    }
    return null;
  }

  // ---------- Actions ----------

  Future<void> _pickM3uFile() async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    final file = result?.files.single;
    final path = file?.path;
    if (path == null) return;

    final name = file!.name;
    final lower = name.toLowerCase();
    if (!lower.endsWith('.m3u') &&
        !lower.endsWith('.m3u8') &&
        !lower.endsWith('.txt')) {
      _snack('Sélectionnez un fichier .m3u, .m3u8 ou .txt');
      return;
    }

    // Copie dans le dossier de l'application : le chemin reste valide
    // même si le fichier d'origine est déplacé ou supprimé.
    try {
      final dir = await getApplicationDocumentsDirectory();
      final destPath =
          '${dir.path}/playlist_${DateTime.now().millisecondsSinceEpoch}_$name';
      await File(path).copy(destPath);
      setState(() {
        _pickedFilePath = destPath;
        _pickedFileName = name;
      });
    } catch (_) {
      _snack('Impossible de copier le fichier sélectionné.');
    }
  }

  Future<void> _submit() async {
    if (_mode == AccountSourceType.m3uFile && _pickedFilePath == null) {
      _snack('Sélectionnez d\'abord un fichier M3U.');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final notifier = ref.read(authProvider.notifier);
    final name = _nameCtrl.text;
    bool ok = false;

    switch (_mode) {
      case AccountSourceType.xtream:
        ok = await notifier.loginXtream(
          name: name,
          host: _hostCtrl.text,
          username: _userCtrl.text,
          password: _passCtrl.text,
        );
      case AccountSourceType.m3uUrl:
        ok = await notifier.loginM3uUrl(name: name, url: _m3uUrlCtrl.text);
      case AccountSourceType.m3uFile:
        ok = await notifier.loginM3uFile(name: name, path: _pickedFilePath!);
      case AccountSourceType.mac:
        final mac = await ref.read(deviceMacProvider.future);
        final deviceId = await ref.read(deviceIdProvider.future);
        ok = await notifier.loginMac(
          name: name,
          portalUrl: _portalCtrl.text,
          mac: mac,
          deviceId: deviceId,
        );
        if (!ok && mounted) {
          final state = ref.read(authProvider);
          if (state is AuthError && state.activationPending) {
            // Appareil pas encore activé : écran d'activation avec polling.
            context.push('/mac-activation');
            return;
          }
        }
    }

    if (ok && mounted) context.go('/home');
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState is AuthLoading || authState is AuthReconnecting;
    final savedAccounts = ref.watch(savedAccountsProvider);
    final hasSaved =
        savedAccounts.maybeWhen(data: (l) => l.isNotEmpty, orElse: () => false);

    return Scaffold(
      body: PremiumBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: GlassContainer(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 24),
                      _buildModeSelector(),
                      const SizedBox(height: 22),
                      _buildNameField(),
                      const SizedBox(height: 14),
                      ..._buildModeFields(),
                      const SizedBox(height: 24),
                      _buildStatus(authState),
                      GradientButton(
                        label: _mode == AccountSourceType.mac
                            ? 'Vérifier l\'activation'
                            : 'Se connecter',
                        icon: _mode == AccountSourceType.mac
                            ? Icons.verified_outlined
                            : Icons.login_rounded,
                        loading: isLoading,
                        onPressed: isLoading ? null : _submit,
                      ),
                      if (hasSaved) ...[
                        const SizedBox(height: 14),
                        TextButton.icon(
                          onPressed: () => context.push('/accounts'),
                          icon: const Icon(Icons.switch_account_outlined,
                              color: Colors.white70),
                          label: const Text('Comptes enregistrés',
                              style: TextStyle(color: Colors.white70)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: AppColors.glow(AppColors.seed, blur: 24),
          ),
          child:
              const Icon(Icons.play_arrow_rounded, size: 44, color: Colors.white),
        ).animate().scale(duration: 450.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 18),
        Text(
          'Bienvenue',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
        ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.2),
        const SizedBox(height: 4),
        const Text(
          'Choisissez votre mode de connexion',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60),
        ).animate().fadeIn(delay: 250.ms),
      ],
    );
  }

  /// Sélecteur de mode compatible D-Pad (ChoiceChips focusables).
  Widget _buildModeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final type in AccountSourceType.values)
          ChoiceChip(
            label: Text(type.label),
            selected: _mode == type,
            labelStyle: TextStyle(
              color: _mode == type ? Colors.white : Colors.white70,
              fontWeight:
                  _mode == type ? FontWeight.w700 : FontWeight.w500,
            ),
            selectedColor: AppColors.seed,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            side: BorderSide(
              color: _mode == type ? Colors.white54 : Colors.white24,
            ),
            onSelected: (_) => setState(() => _mode = type),
          ),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildNameField() {
    return _field(
      controller: _nameCtrl,
      label: 'Nom du compte (optionnel)',
      icon: Icons.badge_outlined,
    );
  }

  List<Widget> _buildModeFields() {
    switch (_mode) {
      case AccountSourceType.xtream:
        return [
          _field(
            controller: _hostCtrl,
            label: 'Serveur (http://host:port)',
            icon: Icons.dns_outlined,
            keyboardType: TextInputType.url,
            validator: _validateServer,
          ),
          const SizedBox(height: 14),
          _field(
            controller: _userCtrl,
            label: 'Nom d\'utilisateur',
            icon: Icons.person_outline,
            validator: (v) => _required(v, 'Nom d\'utilisateur'),
          ),
          const SizedBox(height: 14),
          _field(
            controller: _passCtrl,
            label: 'Mot de passe',
            icon: Icons.lock_outline,
            obscure: _obscure,
            onSubmitted: (_) => _submit(),
            suffix: IconButton(
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: Colors.white54,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Mot de passe requis' : null,
          ),
        ];

      case AccountSourceType.m3uUrl:
        return [
          _field(
            controller: _m3uUrlCtrl,
            label: 'URL de la playlist (http://…/liste.m3u)',
            icon: Icons.link_outlined,
            keyboardType: TextInputType.url,
            onSubmitted: (_) => _submit(),
            validator: _validateM3uUrl,
          ),
          const SizedBox(height: 10),
          const Text(
            'La playlist sera téléchargée puis vérifiée avant la connexion.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ];

      case AccountSourceType.m3uFile:
        return [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _pickM3uFile,
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(
              _pickedFileName ?? 'Choisir un fichier M3U',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_pickedFileName != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline,
                    color: Colors.greenAccent, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _pickedFileName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.greenAccent, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ];

      case AccountSourceType.mac:
        return [
          _DeviceIdentityPanel(onCopied: _snack),
          const SizedBox(height: 14),
          _field(
            controller: _portalCtrl,
            label: 'Serveur d\'activation (http://portail.tld)',
            icon: Icons.router_outlined,
            keyboardType: TextInputType.url,
            onSubmitted: (_) => _submit(),
            validator: _validateServer,
          ),
          const SizedBox(height: 10),
          const Text(
            'Enregistrez l\'adresse MAC et le Device ID ci-dessus sur le '
            'portail de votre fournisseur, puis vérifiez l\'activation.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ];
    }
  }

  Widget _buildStatus(AuthState authState) {
    if (authState is AuthReconnecting) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(
          'Connexion impossible, nouvelle tentative '
          '(${authState.attempt}/${authState.maxAttempts})…',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.amberAccent, fontSize: 13),
        ),
      );
    }
    if (authState is AuthError && !authState.activationPending) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(
          authState.message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.red.shade300, fontSize: 13),
        ).animate().shake(),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white54),
        suffixIcon: suffix,
        fillColor: Colors.white.withValues(alpha: 0.07),
      ),
    );
  }
}

/// Panneau affichant l'adresse MAC et le Device ID de l'appareil,
/// avec copie en un clic.
class _DeviceIdentityPanel extends ConsumerWidget {
  final void Function(String message) onCopied;

  const _DeviceIdentityPanel({required this.onCopied});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mac = ref.watch(deviceMacProvider);
    final deviceId = ref.watch(deviceIdProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          _identityRow(
            context,
            label: 'Adresse MAC',
            value: mac.valueOrNull,
            icon: Icons.memory_outlined,
          ),
          const Divider(color: Colors.white12, height: 20),
          _identityRow(
            context,
            label: 'Device ID',
            value: deviceId.valueOrNull,
            icon: Icons.fingerprint_outlined,
          ),
        ],
      ),
    );
  }

  Widget _identityRow(
    BuildContext context, {
    required String label,
    required String? value,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 11)),
              Text(
                value ?? '…',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Copier',
          icon: const Icon(Icons.copy_outlined,
              color: Colors.white54, size: 18),
          onPressed: value == null
              ? null
              : () {
                  Clipboard.setData(ClipboardData(text: value));
                  onCopied('$label copié dans le presse-papiers');
                },
        ),
      ],
    );
  }
}
