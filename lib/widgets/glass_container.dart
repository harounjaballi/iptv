import 'dart:ui';
import 'package:flutter/material.dart';

import '../themes/app_colors.dart';

/// Conteneur glassmorphism : flou d'arrière-plan + voile translucide
/// + fine bordure lumineuse + ombre douce.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? tint;
  final bool shadow;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 18,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.padding,
    this.margin,
    this.tint,
    this.shadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadow ? AppColors.softShadow() : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: tint ?? AppColors.glassTint(brightness),
              borderRadius: borderRadius,
              border: Border.all(
                color: AppColors.glassBorder(brightness),
                width: 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 
                      brightness == Brightness.dark ? 0.10 : 0.65),
                  Colors.white.withValues(alpha: 
                      brightness == Brightness.dark ? 0.03 : 0.35),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
