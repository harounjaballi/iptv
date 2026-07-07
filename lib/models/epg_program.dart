import 'dart:convert';

/// Programme EPG (guide TV) d'une chaîne.
class EpgProgram {
  final String title;
  final String description;
  final DateTime start;
  final DateTime end;

  const EpgProgram({
    required this.title,
    required this.description,
    required this.start,
    required this.end,
  });

  bool get isNow {
    final now = DateTime.now();
    return !now.isBefore(start) && now.isBefore(end);
  }

  /// Avancement du programme (0..1) — pour la barre de progression.
  double get progress {
    final total = end.difference(start).inSeconds;
    if (total <= 0) return 0;
    final elapsed = DateTime.now().difference(start).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  /// Les titres/descriptions Xtream sont encodés en Base64.
  static String _decode(dynamic value) {
    final s = value?.toString() ?? '';
    if (s.isEmpty) return '';
    try {
      return utf8.decode(base64.decode(s.replaceAll('\n', '')));
    } catch (_) {
      return s;
    }
  }

  static DateTime _fromTimestamp(dynamic value) {
    final seconds = int.tryParse(value?.toString() ?? '') ?? 0;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  factory EpgProgram.fromXtream(Map<String, dynamic> json) => EpgProgram(
        title: _decode(json['title']),
        description: _decode(json['description']),
        start: _fromTimestamp(json['start_timestamp']),
        end: _fromTimestamp(json['stop_timestamp']),
      );
}

/// Paire « programme actuel / programme suivant » d'une chaîne.
class EpgNowNext {
  final EpgProgram? now;
  final EpgProgram? next;

  const EpgNowNext({this.now, this.next});

  bool get isEmpty => now == null && next == null;

  static const empty = EpgNowNext();

  /// Extrait maintenant/suivant d'une liste de programmes triés.
  factory EpgNowNext.fromPrograms(List<EpgProgram> programs) {
    final nowTime = DateTime.now();
    EpgProgram? current;
    EpgProgram? next;
    for (final p in programs) {
      if (!nowTime.isBefore(p.start) && nowTime.isBefore(p.end)) {
        current = p;
      } else if (p.start.isAfter(nowTime)) {
        next ??= p;
      }
    }
    return EpgNowNext(now: current, next: next);
  }
}
