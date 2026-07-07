import 'dart:async';

/// Anti-rebond : n'exécute [run]'s action qu'après [delay] sans nouvel appel.
///
/// Utilisé pour la recherche : sans debounce, chaque frappe refiltre un
/// catalogue de dizaines de milliers d'éléments et reconstruit la grille,
/// ce qui rend la saisie saccadée (surtout sur Android TV / Fire TV bas de
/// gamme).
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 300)});

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Exécute immédiatement (ex. bouton "effacer") et annule le timer.
  void runNow(void Function() action) {
    _timer?.cancel();
    action();
  }

  void dispose() => _timer?.cancel();
}
