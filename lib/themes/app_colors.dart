import 'package:flutter/material.dart';

/// Palette de marque Premium IPTV — design "commercial" inspiré
/// des lecteurs IPTV premium (fonds profonds, dégradés violet→fuchsia, verre).
class AppColors {
  AppColors._();

  // Marque
  static const Color seed = Color(0xFF7C3AED); // violet
  static const Color accent = Color(0xFFDB2777); // fuchsia
  static const Color cyan = Color(0xFF22D3EE); // accent secondaire

  // Fonds sombres profonds
  static const Color darkBackground = Color(0xFF07070E);
  static const Color darkSurface = Color(0xFF12121D);
  static const Color darkSurfaceHigh = Color(0xFF1A1A28);

  // Dégradé de marque
  static const LinearGradient brandGradient = LinearGradient(
    colors: [seed, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dégradé de fond plein écran (splash / login / TV).
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF13082A), Color(0xFF07070E), Color(0xFF1A0518)],
    stops: [0.0, 0.55, 1.0],
  );

  /// Voile de verre (glassmorphism) selon le mode.
  static Color glassTint(Brightness b) => b == Brightness.dark
      ? Colors.white.withValues(alpha: 0.07)
      : Colors.white.withValues(alpha: 0.60);

  static Color glassBorder(Brightness b) => b == Brightness.dark
      ? Colors.white.withValues(alpha: 0.14)
      : Colors.white.withValues(alpha: 0.65);

  /// Ombre douce standard des cartes.
  static List<BoxShadow> softShadow([Color? color]) => [
        BoxShadow(
          color: (color ?? Colors.black).withValues(alpha: 0.25),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];

  /// Halo lumineux (focus TV / boutons).
  static List<BoxShadow> glow(Color color, {double blur = 22}) => [
        BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: blur),
      ];
}
