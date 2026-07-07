import 'package:flutter/widgets.dart';

/// Mode performance global, initialisé une seule fois au démarrage
/// (voir `main.dart`).
///
/// Sur Android TV / Google TV / Fire TV, le GPU et la RAM sont limités
/// (Fire TV Stick : ~1,5 Go utilisables) et le décodage vidéo doit rester
/// prioritaire. En mode [lowPower], les animations **décoratives**
/// (orbes du fond, fondus d'apparition...) sont désactivées ou raccourcies ;
/// les animations **fonctionnelles** (focus D-pad, transitions de page)
/// restent actives.
class PerfMode {
  PerfMode._();

  /// Vrai sur Android TV / Google TV / Fire TV (FEATURE_LEANBACK).
  static bool isTv = false;

  /// Vrai quand les animations décoratives doivent être évitées :
  /// appareil TV, ou préférence système "réduire les animations".
  static bool get lowPower => isTv;

  /// Faut-il animer les éléments purement décoratifs dans ce [context] ?
  /// Respecte aussi l'accessibilité (`disableAnimations`).
  static bool decorativeAnimations(BuildContext context) =>
      !lowPower && !MediaQuery.disableAnimationsOf(context);

  /// Raccourcit une durée d'animation en mode économie (×0,6).
  static Duration scaled(Duration base) =>
      lowPower ? base * 0.6 : base;
}
