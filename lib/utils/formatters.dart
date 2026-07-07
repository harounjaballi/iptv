import 'package:intl/intl.dart';

/// Formatage des dates, durées et nombres (intl).
class Formatters {
  Formatters._();

  static String expiryDate(String? unixTimestamp) {
    if (unixTimestamp == null || unixTimestamp.isEmpty) return 'Illimité';
    final seconds = int.tryParse(unixTimestamp);
    if (seconds == null) return unixTimestamp;
    final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    return DateFormat('dd MMM yyyy', 'fr').format(date);
  }

  static String duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  static String rating(dynamic value) {
    final r = double.tryParse(value?.toString() ?? '');
    if (r == null || r <= 0) return '—';
    return NumberFormat('0.0').format(r);
  }
}
