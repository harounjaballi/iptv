import 'package:flutter/material.dart';

import '../themes/app_colors.dart';

/// Carte compatible D-Pad / souris / tactile :
/// zoom + bordure + halo au focus (TV), ombre douce au repos.
class FocusableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool autofocus;

  const FocusableCard({
    super.key,
    required this.child,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  State<FocusableCard> createState() => _FocusableCardState();
}

class _FocusableCardState extends State<FocusableCard> {
  bool _focused = false;
  bool _hovered = false;

  bool get _highlighted => _focused || _hovered;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _highlighted ? 1.06 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _highlighted ? scheme.primary : Colors.transparent,
              width: 2.4,
            ),
            boxShadow: _highlighted
                ? AppColors.glow(scheme.primary)
                : AppColors.softShadow(),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              autofocus: widget.autofocus,
              onTap: widget.onTap,
              onFocusChange: (f) => setState(() => _focused = f),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
