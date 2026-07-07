import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../models/iptv_account.dart';
import 'account_storage_service.dart';
import 'cache_service.dart';

/// Sauvegarde locale & synchronisation entre appareils (fichier JSON) :
/// réglages, profils, favoris, progression, historique, statistiques,
/// contrôle parental et (optionnellement) comptes IPTV.
///
/// Deux modes d'import :
/// - restauration : remplace les données locales ;
/// - synchronisation : fusion intelligente (favoris = union, progression
///   et historiques = l'entrée la plus récente gagne).
class BackupService {
  final CacheService _cache;
  final AccountStorageService _accounts;

  const BackupService(this._cache, this._accounts);

  // ============ Export ============

  Future<Map<String, dynamic>> _buildBackup({required bool includeAccounts}) async {
    return {
      'app': 'premium_iptv_player',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': _cache.dumpSettings(),
      'favorites': _cache.allFavorites(),
      if (includeAccounts)
        'accounts': [
          for (final a in await _accounts.getAccounts()) a.toJson(),
        ],
    };
  }

  /// Exporte la sauvegarde vers un fichier choisi par l'utilisateur.
  /// Retourne le chemin du fichier, ou null si annulé.
  Future<String?> exportToFile({bool includeAccounts = false}) async {
    final backup = await _buildBackup(includeAccounts: includeAccounts);
    final bytes = Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(backup)));
    final stamp = DateTime.now()
        .toIso8601String()
        .substring(0, 19)
        .replaceAll(':', '-');
    return FilePicker.platform.saveFile(
      dialogTitle: 'Exporter la sauvegarde',
      fileName: 'premium_iptv_backup_$stamp.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: bytes,
    );
  }

  // ============ Import ============

  /// Ouvre un sélecteur de fichier et importe la sauvegarde.
  /// [merge] : true = synchronisation (fusion), false = restauration.
  /// Retourne false si l'utilisateur annule.
  Future<bool> importFromFile({required bool merge}) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: merge ? 'Synchroniser depuis un fichier' : 'Restaurer',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    final bytes = result?.files.firstOrNull?.bytes;
    if (bytes == null) return false;

    final data = jsonDecode(utf8.decode(bytes));
    if (data is! Map || data['app'] != 'premium_iptv_player') {
      throw const FormatException('Fichier de sauvegarde invalide');
    }
    await _apply(Map<String, dynamic>.from(data), merge: merge);
    return true;
  }

  Future<void> _apply(Map<String, dynamic> data, {required bool merge}) async {
    // ---- Favoris : toujours en union (aucune perte possible). ----
    final favorites = (data['favorites'] as List? ?? const [])
        .map((e) => e.toString());
    await _cache.restoreFavorites(favorites);

    // ---- Réglages ----
    final imported = <String, String>{
      if (data['settings'] is Map)
        for (final e in (data['settings'] as Map).entries)
          if (e.value is String) e.key.toString(): e.value as String,
    };

    if (!merge) {
      await _cache.restoreSettings(imported);
    } else {
      final local = _cache.dumpSettings();
      final toWrite = <String, String>{};
      for (final e in imported.entries) {
        final key = e.key;
        final localValue = local[key];
        if (localValue == null) {
          toWrite[key] = e.value; // absent en local → on prend l'import
        } else if (key.startsWith('watch_progress_')) {
          toWrite[key] = _mergeProgress(localValue, e.value);
        } else if (key.startsWith('watch_stats_')) {
          toWrite[key] = _mergeStats(localValue, e.value);
        } else if (key.startsWith('series_history_') ||
            key.startsWith('recent_live_')) {
          toWrite[key] = _mergeIdLists(localValue, e.value);
        }
        // Autres clés (thème, langue, PIN...) : le local est conservé.
      }
      await _cache.restoreSettings(toWrite);
    }

    // ---- Comptes IPTV (ajoutés s'ils n'existent pas déjà) ----
    if (data['accounts'] is List) {
      final existing = await _accounts.getAccounts();
      final existingIds = {for (final a in existing) a.id};
      for (final raw in (data['accounts'] as List).whereType<Map>()) {
        try {
          final account =
              IptvAccount.fromJson(Map<String, dynamic>.from(raw));
          if (!merge || !existingIds.contains(account.id)) {
            await _accounts.upsertAccount(account);
          }
        } catch (_) {/* entrée corrompue : ignorée */}
      }
    }
  }

  /// Fusion des progressions : pour chaque contenu, la plus récente gagne.
  String _mergeProgress(String local, String imported) {
    final result = _decodeMap(local);
    final other = _decodeMap(imported);
    other.forEach((key, value) {
      final localTs = _tsOf(result[key]);
      final importedTs = _tsOf(value);
      if (importedTs > localTs) result[key] = value;
    });
    return jsonEncode(result);
  }

  int _tsOf(dynamic entry) =>
      entry is Map ? int.tryParse(entry['t']?.toString() ?? '') ?? 0 : 0;

  /// Fusion des statistiques : maximum par jour/type (évite le double comptage).
  String _mergeStats(String local, String imported) {
    final a = _decodeMap(local);
    final b = _decodeMap(imported);
    Map<String, int> mergeInts(dynamic x, dynamic y) {
      final result = <String, int>{
        if (x is Map)
          for (final e in x.entries)
            e.key.toString(): int.tryParse(e.value.toString()) ?? 0,
      };
      if (y is Map) {
        for (final e in y.entries) {
          final key = e.key.toString();
          final value = int.tryParse(e.value.toString()) ?? 0;
          if (value > (result[key] ?? 0)) result[key] = value;
        }
      }
      return result;
    }

    final plays = [
      int.tryParse(a['plays']?.toString() ?? '') ?? 0,
      int.tryParse(b['plays']?.toString() ?? '') ?? 0,
    ];
    return jsonEncode({
      'days': mergeInts(a['days'], b['days']),
      'byType': mergeInts(a['byType'], b['byType']),
      'plays': plays.reduce((x, y) => x > y ? x : y),
    });
  }

  /// Fusion de listes d'identifiants ordonnées (récents en tête).
  String _mergeIdLists(String local, String imported) {
    List<dynamic> decode(String raw) {
      try {
        final v = jsonDecode(raw);
        return v is List ? v : const [];
      } catch (_) {
        return const [];
      }
    }

    final seen = <String>{};
    final result = <dynamic>[];
    for (final id in [...decode(local), ...decode(imported)]) {
      if (seen.add(id.toString())) result.add(id);
    }
    return jsonEncode(result);
  }

  Map<String, dynamic> _decodeMap(String raw) {
    try {
      final v = jsonDecode(raw);
      return v is Map ? Map<String, dynamic>.from(v) : {};
    } catch (_) {
      return {};
    }
  }
}
