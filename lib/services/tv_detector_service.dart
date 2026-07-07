import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Détection Android TV / Google TV / Fire TV via canal natif (FEATURE_LEANBACK).
class TvDetectorService {
  static const MethodChannel _channel = MethodChannel('premium_iptv/device');

  Future<bool> isTv() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('isTv');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
}
