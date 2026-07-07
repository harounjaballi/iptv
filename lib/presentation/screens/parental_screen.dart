import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/category_model.dart';
import '../../providers/content_providers.dart';
import '../../providers/parental_providers.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/pin_dialog.dart';

/// Contrôle parental : code PIN (SHA-256) + catégories cachées.
/// L'écran est verrouillé par le PIN s'il est défini.
class ParentalScreen extends ConsumerStatefulWidget {
  const ParentalScreen({super.key});

  @override
  ConsumerState<ParentalScreen> createState() => _ParentalScreenState();
}

class _ParentalScreenState extends ConsumerState<ParentalScreen> {
  bool _unlocked = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _gate());
  }

  Future<void> _gate() async {
    final pinNotifier = ref.read(parentalPinProvider.notifier);
    if (!pinNotifier.isSet) {
      setState(() {
        _unlocked = true;
        _checking = false;
      });
      return;
    }
    final l10n = ref.read(l10nProvider);
    final pin = await showPinInputDialog(context,
        title: l10n.enterPin, cancelLabel: l10n.cancel);
    if (!mounted) return;
    if (pin != null && pinNotifier.verify(pin)) {
      setState(() {
        _unlocked = true;
        _checking = false;
      });
    } else {
      if (pin != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.wrongPin)));
      }
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _setOrChangePin() async {
    final l10n = ref.read(l10nProvider);
    final pinNotifier = ref.read(parentalPinProvider.notifier);
    final first = await showPinInputDialog(context,
        title: l10n.setPin, cancelLabel: l10n.cancel);
    if (first == null || !mounted) return;
    final second = await showPinInputDialog(context,
        title: l10n.confirmPin, cancelLabel: l10n.cancel);
    if (second == null || !mounted) return;
    if (first != second) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.pinMismatch)));
      return;
    }
    await pinNotifier.setPin(first);
  }

  Future<void> _removePin() async {
    final l10n = ref.read(l10nProvider);
    final pinNotifier = ref.read(parentalPinProvider.notifier);
    final pin = await showPinInputDialog(context,
        title: l10n.enterPin, cancelLabel: l10n.cancel);
    if (pin == null || !mounted) return;
    if (!pinNotifier.verify(pin)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.wrongPin)));
      return;
    }
    await pinNotifier.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final pinSet = ref.watch(parentalEnabledProvider);

    if (_checking || !_unlocked) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.parentalControl)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.parentalControl)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---------- Code PIN ----------
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.pin_rounded),
                  title: Text(pinSet ? l10n.changePin : l10n.setPin),
                  onTap: _setOrChangePin,
                ),
                if (pinSet) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.lock_open_rounded,
                        color: Theme.of(context).colorScheme.error),
                    title: Text(l10n.removePin,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                    onTap: _removePin,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ---------- Catégories cachées ----------
          Text(l10n.hiddenCategories,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(l10n.hiddenCategoriesSubtitle,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          _CategorySection(
              title: l10n.channels,
              type: 'live',
              provider: liveCategoriesRawProvider),
          _CategorySection(
              title: l10n.movies,
              type: 'vod',
              provider: vodCategoriesRawProvider),
          _CategorySection(
              title: l10n.series,
              type: 'series',
              provider: seriesCategoriesRawProvider),
        ],
      ),
    );
  }
}

/// Section repliable listant les catégories d'un type avec cases à cocher.
class _CategorySection extends ConsumerWidget {
  final String title;
  final String type;
  final AutoDisposeFutureProvider<List<CategoryModel>> provider;

  const _CategorySection({
    required this.title,
    required this.type,
    required this.provider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(provider);
    final hidden = ref.watch(hiddenCategoriesProvider(type));

    return Card(
      child: ExpansionTile(
        title: Text(title),
        subtitle: hidden.isEmpty ? null : Text('${hidden.length} 🔒'),
        shape: const Border(),
        children: categoriesAsync.when(
          data: (categories) => [
            for (final c in categories)
              CheckboxListTile(
                dense: true,
                title: Text(c.name),
                value: hidden.contains(c.id),
                onChanged: (_) => ref
                    .read(hiddenCategoriesProvider(type).notifier)
                    .toggle(c.id),
              ),
          ],
          loading: () => const [
            Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          ],
          error: (e, _) => [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(e.toString()),
            )
          ],
        ),
      ),
    );
  }
}
