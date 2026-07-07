import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/constants/app_constants.dart';

/// Identité stable de l'appareil pour le mode d'activation par MAC :
/// - une **adresse MAC virtuelle** de style MAG (préfixe 00:1A:79),
///   générée une seule fois puis persistée (Android ≥ 6 interdit la lecture
///   de la vraie MAC — c'est la convention utilisée par les players IPTV) ;
/// - un **Device ID** hexadécimal de 12 caractères, lui aussi persistant.
class DeviceIdentityService {
  final FlutterSecureStorage _storage;

  const DeviceIdentityService(
      [this._storage = const FlutterSecureStorage()]);

  /// Adresse MAC virtuelle de l'appareil (créée au premier appel).
  Future<String> getMac() async {
    final existing = await _storage.read(key: AppConstants.keyDeviceMac);
    if (existing != null && existing.isNotEmpty) return existing;

    final rng = Random.secure();
    final suffix = List.generate(
      3,
      (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0').toUpperCase(),
    ).join(':');
    final mac = '${AppConstants.macPrefix}:$suffix';
    await _storage.write(key: AppConstants.keyDeviceMac, value: mac);
    return mac;
  }

  /// Device ID hexadécimal de 12 caractères (créé au premier appel).
  Future<String> getDeviceId() async {
    final existing = await _storage.read(key: AppConstants.keyDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;

    final rng = Random.secure();
    final id = List.generate(
      12,
      (_) => rng.nextInt(16).toRadixString(16).toUpperCase(),
    ).join();
    await _storage.write(key: AppConstants.keyDeviceId, value: id);
    return id;
  }
}
