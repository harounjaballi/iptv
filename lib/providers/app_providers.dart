import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/dio_client.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../data/repositories/content_repository_impl.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/content_repository.dart';
import '../services/account_storage_service.dart';
import '../services/cache_service.dart';
import '../services/device_identity_service.dart';
import '../services/m3u_parser_service.dart';
import '../services/mac_activation_service.dart';
import '../services/tv_detector_service.dart';
import '../services/xtream_api_service.dart';

/// ---- Infrastructure ----
final dioProvider = Provider<Dio>((ref) => DioClient.create());

final accountStorageProvider =
    Provider<AccountStorageService>((ref) => const AccountStorageService());

final deviceIdentityProvider =
    Provider<DeviceIdentityService>((ref) => const DeviceIdentityService());

/// Initialisé dans main() puis overridé — voir main.dart.
final cacheServiceProvider = Provider<CacheService>(
  (ref) => throw UnimplementedError('CacheService doit être overridé'),
);

final xtreamApiProvider = Provider<XtreamApiService>(
    (ref) => XtreamApiService(ref.watch(dioProvider)));

final m3uParserProvider =
    Provider<M3uParserService>((ref) => M3uParserService(ref.watch(dioProvider)));

final macActivationProvider = Provider<MacActivationService>(
    (ref) => MacActivationService(ref.watch(dioProvider)));

/// Identité de l'appareil (MAC virtuel + Device ID), résolue une fois.
final deviceMacProvider =
    FutureProvider<String>((ref) => ref.watch(deviceIdentityProvider).getMac());

final deviceIdProvider = FutureProvider<String>(
    (ref) => ref.watch(deviceIdentityProvider).getDeviceId());

/// ---- Repositories ----
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    ref.watch(xtreamApiProvider),
    ref.watch(m3uParserProvider),
    ref.watch(macActivationProvider),
    ref.watch(accountStorageProvider),
    ref.watch(cacheServiceProvider),
  ),
);

final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => ContentRepositoryImpl(
    ref.watch(xtreamApiProvider),
    ref.watch(cacheServiceProvider),
  ),
);

/// ---- Détection TV (résolue au démarrage) ----
final isTvProvider = FutureProvider<bool>((ref) => TvDetectorService().isTv());

/// Valeur synchrone pratique (false tant que non résolu).
final isTvValueProvider = Provider<bool>(
  (ref) => ref.watch(isTvProvider).maybeWhen(data: (v) => v, orElse: () => false),
);
