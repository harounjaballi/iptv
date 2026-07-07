import 'package:flutter/material.dart';

/// Grille avec **pagination côté rendu** (lazy loading) :
///
/// Les API Xtream renvoient le catalogue complet (souvent 5 000 à 50 000
/// éléments). Construire une grille de cette taille d'un coup provoque du
/// jank et une explosion mémoire (layout + images).
///
/// [PagedGrid] n'attache au sliver que les [pageSize] premiers éléments, puis
/// en révèle une page de plus quand l'utilisateur approche de la fin
/// (déclenchement à 600 px du bas). Le décodage des images reste ainsi
/// strictement proportionnel au défilement réel.
///
/// Compatible tactile **et** D-pad (Android TV / Fire TV) : la navigation au
/// focus fait défiler la grille, ce qui déclenche aussi le chargement.
class PagedGrid<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext, T) itemBuilder;
  final int columns;
  final int pageSize;
  final double childAspectRatio;
  final EdgeInsets padding;
  final double spacing;

  const PagedGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.columns,
    this.pageSize = 60,
    this.childAspectRatio = 2 / 3,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 96),
    this.spacing = 12,
  });

  @override
  State<PagedGrid<T>> createState() => _PagedGridState<T>();
}

class _PagedGridState<T> extends State<PagedGrid<T>> {
  final _controller = ScrollController();
  late int _visible;

  @override
  void initState() {
    super.initState();
    _visible = widget.pageSize;
    _controller.addListener(_maybeLoadMore);
  }

  @override
  void didUpdateWidget(covariant PagedGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Nouvelle liste (changement de catégorie / recherche) : on repart page 1.
    if (!identical(oldWidget.items, widget.items)) {
      _visible = widget.pageSize;
      if (_controller.hasClients) _controller.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_visible >= widget.items.length) return;
    final pos = _controller.position;
    if (pos.pixels >= pos.maxScrollExtent - 600) {
      setState(() {
        _visible =
            (_visible + widget.pageSize).clamp(0, widget.items.length);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _visible.clamp(0, widget.items.length);
    final hasMore = count < widget.items.length;

    return CustomScrollView(
      controller: _controller,
      cacheExtent: 400,
      slivers: [
        SliverPadding(
          padding: widget.padding,
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: widget.columns,
              mainAxisSpacing: widget.spacing,
              crossAxisSpacing: widget.spacing,
              childAspectRatio: widget.childAspectRatio,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => RepaintBoundary(
                child: widget.itemBuilder(context, widget.items[i]),
              ),
              childCount: count,
              addRepaintBoundaries: false, // déjà géré ci-dessus
            ),
          ),
        ),
        if (hasMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: 96),
              child: Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
