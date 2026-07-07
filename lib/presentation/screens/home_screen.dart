import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../providers/settings_providers.dart';
import '../../themes/app_colors.dart';
import '../../widgets/app_drawer.dart';
import 'global_search_tab.dart';
import 'live_tab.dart';
import 'movies_tab.dart';
import 'series_tab.dart';
import 'settings_tab.dart';

/// Écran principal premium :
/// - Mobile  : Navigation Drawer + Bottom Navigation "verre" flottante
/// - TV/Wide : NavigationRail avec marges overscan
/// - Changement d'onglet animé (fondu + glissement).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  /// Onglets déjà visités : construits **paresseusement** à la première
  /// visite, puis conservés vivants dans l'IndexedStack (scroll, recherche
  /// et filtres préservés — aucune reconstruction au changement d'onglet).
  final Set<int> _built = {0};

  static const _tabs = [
    LiveTab(),
    MoviesTab(),
    SeriesTab(),
    GlobalSearchTab(),
    SettingsTab(),
  ];

  /// Destinations traduites (FR / EN / AR).
  List<({IconData icon, IconData selected, String label})> get _destinations {
    final l10n = ref.watch(l10nProvider);
    return [
      (
        icon: Icons.live_tv_outlined,
        selected: Icons.live_tv,
        label: l10n.tabLive
      ),
      (
        icon: Icons.movie_outlined,
        selected: Icons.movie,
        label: l10n.tabMovies
      ),
      (
        icon: Icons.video_library_outlined,
        selected: Icons.video_library,
        label: l10n.tabSeries
      ),
      (
        icon: Icons.search_outlined,
        selected: Icons.search,
        label: l10n.tabSearch
      ),
      (
        icon: Icons.settings_outlined,
        selected: Icons.settings,
        label: l10n.tabSettings
      ),
    ];
  }

  void _select(int i) => setState(() {
        _index = i;
        _built.add(i);
      });

  /// Corps : IndexedStack **paresseux**.
  ///
  /// L'ancien AnimatedSwitcher détruisait puis reconstruisait chaque onglet
  /// à chaque changement (perte du scroll, refiltrage des catalogues,
  /// redécodage d'images). Ici :
  /// - un onglet jamais visité n'est pas construit (lazy loading) ;
  /// - un onglet visité reste vivant hors écran (état conservé) mais n'est
  ///   ni peint ni animé (Offstage géré par IndexedStack).
  Widget _body() {
    return IndexedStack(
      index: _index,
      children: [
        for (var i = 0; i < _tabs.length; i++)
          _built.contains(i) ? _tabs[i] : const SizedBox.shrink(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTv = ref.watch(isTvValueProvider);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final useRail = isTv || wide;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (useRail) {
      // ---- Disposition TV / grand écran ----
      return Scaffold(
        drawer: AppDrawer(selectedIndex: _index, onSelect: _select),
        body: Container(
          decoration: isDark
              ? const BoxDecoration(gradient: AppColors.backgroundGradient)
              : null,
          child: SafeArea(
            child: Row(
              children: [
                Padding(
                  padding: EdgeInsets.only(
                      left: isTv
                          ? MediaQuery.sizeOf(context).width * 0.02
                          : 0),
                  child: NavigationRail(
                    selectedIndex: _index,
                    onDestinationSelected: _select,
                    labelType: NavigationRailLabelType.all,
                    leading: Padding(
                      padding: const EdgeInsets.only(bottom: 16, top: 8),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: AppColors.brandGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: AppColors.glow(AppColors.seed, blur: 14),
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white),
                      ),
                    ),
                    destinations: [
                      for (final d in _destinations)
                        NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selected),
                          label: Text(d.label),
                        ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _body()),
              ],
            ),
          ),
        ),
      );
    }

    // ---- Disposition mobile : drawer + bottom nav flottante en verre ----
    return Scaffold(
      extendBody: true,
      drawer: AppDrawer(selectedIndex: _index, onSelect: _select),
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (b) => AppColors.brandGradient.createShader(b),
          child: const Text(
            'Premium IPTV',
            style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ),
      ),
      body: Container(
        decoration: isDark
            ? const BoxDecoration(gradient: AppColors.backgroundGradient)
            : null,
        child: _body(),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: AppColors.glassBorder(
                      Theme.of(context).brightness),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: _select,
                backgroundColor: Colors.transparent,
                destinations: [
                  for (final d in _destinations)
                    NavigationDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selected),
                      label: d.label,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
