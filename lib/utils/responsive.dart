import 'package:flutter/material.dart';

/// Points de rupture et helpers responsive (Mobile / Tablette / TV & Desktop).
class Responsive {
  Responsive._();

  static const double mobileMax = 600;
  static const double tabletMax = 1000;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileMax;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= mobileMax && w < tabletMax;
  }

  static bool isLarge(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletMax;

  /// Nombre de colonnes d'une grille de posters selon la largeur.
  static int gridColumns(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 480) return 3;
    if (w < 700) return 4;
    if (w < 1000) return 5;
    if (w < 1400) return 6;
    return 8;
  }

  /// Padding horizontal adaptatif (marges "safe" TV : ~5% overscan).
  static EdgeInsets pagePadding(BuildContext context, {required bool isTv}) {
    final w = MediaQuery.sizeOf(context).width;
    if (isTv) return EdgeInsets.symmetric(horizontal: w * 0.05, vertical: 24);
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  }
}
