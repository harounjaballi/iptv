import 'package:flutter/material.dart';

import '../themes/app_colors.dart';

/// Bouton dégradé animé : rebond au clic, halo au focus (D-Pad / souris),
/// état de chargement intégré. Digne d'une application commerciale.
class GradientButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expanded;

  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expanded = true,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _pressed = false;
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    final highlighted = _focused || _hovered;

    final content = Row(
      mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2.4, color: Colors.white),
          )
        else ...[
          if (widget.icon != null) ...[
            Icon(widget.icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
          ],
          Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ],
    );

    return FocusableActionDetector(
      enabled: enabled,
      onShowFocusHighlight: (f) => setState(() => _focused = f),
      onShowHoverHighlight: (h) => setState(() => _hovered = h),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : (highlighted ? 1.03 : 1.0),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: highlighted
                    ? Colors.white.withValues(alpha: 0.9)
                    : Colors.transparent,
                width: 1.6,
              ),
              boxShadow: [
                if (enabled)
                  BoxShadow(
                    color: AppColors.seed
                        .withValues(alpha: highlighted ? 0.65 : 0.35),
                    blurRadius: highlighted ? 26 : 16,
                    offset: const Offset(0, 6),
                  ),
              ],
            ),
            child: Opacity(opacity: enabled ? 1 : 0.6, child: content),
          ),
        ),
      ),
    );
  }
}
