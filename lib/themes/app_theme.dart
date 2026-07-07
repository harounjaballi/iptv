import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Thèmes Material 3 clair et sombre — version Premium
/// (coins arrondis généreux, surfaces translucides, focus visible pour TV).
class AppTheme {
  AppTheme._();

  static ThemeData get light => _base(Brightness.light);

  static ThemeData get dark {
    final theme = _base(Brightness.dark);
    return theme.copyWith(
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: theme.colorScheme.copyWith(
        surface: AppColors.darkSurface,
        surfaceContainerHighest: AppColors.darkSurfaceHigh,
      ),
    );
  }

  /// Thème personnalisable : couleur d'accent + variante noir AMOLED.
  static ThemeData themed({
    required Brightness brightness,
    required Color seed,
    bool amoled = false,
  }) {
    final theme = _base(brightness, seed: seed);
    if (brightness == Brightness.light) return theme;
    return theme.copyWith(
      scaffoldBackgroundColor:
          amoled ? Colors.black : AppColors.darkBackground,
      colorScheme: theme.colorScheme.copyWith(
        surface: amoled ? const Color(0xFF060608) : AppColors.darkSurface,
        surfaceContainerHighest:
            amoled ? const Color(0xFF101014) : AppColors.darkSurfaceHigh,
      ),
    );
  }

  static ThemeData _base(Brightness brightness, {Color seed = AppColors.seed}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.glassBorder(brightness), width: 0.8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.seed, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: AppColors.glassBorder(brightness), width: 0.6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: Colors.transparent,
        indicatorColor: AppColors.seed.withValues(alpha: 0.28),
        elevation: 0,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: AppColors.seed.withValues(alpha: 0.28),
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor:
            isDark ? AppColors.darkSurface.withValues(alpha: 0.96) : null,
        indicatorColor: AppColors.seed.withValues(alpha: 0.28),
      ),
      focusColor: AppColors.seed.withValues(alpha: 0.35),
    );
  }
}
