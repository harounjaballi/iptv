import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';

/// Client Dio centralisé et optimisé :
///
/// - **Pool de connexions** : réutilisation des connexions TCP/TLS
///   (keep-alive 30 s, max 6 connexions par hôte) — évite un handshake
///   complet à chaque appel `player_api.php` ;
/// - **Compression** : `Accept-Encoding: gzip` (les catalogues JSON de
///   plusieurs Mo descendent souvent à ~10 % de leur taille) ;
/// - **Retry intelligent** : erreurs réseau transitoires réessayées avec
///   backoff exponentiel + jitter (évite les rafales synchronisées) ;
/// - **Déduplication** : deux appels GET identiques en vol partagent la
///   même réponse (un seul aller-retour serveur) ;
/// - **Logs** en debug uniquement (aucune fuite d'identifiants en release).
class DioClient {
  DioClient._();

  static Dio create() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        responseType: ResponseType.json,
        headers: {
          'User-Agent': 'PremiumIPTVPlayer/1.0',
          'Accept-Encoding': 'gzip',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    // Pool de connexions natif.
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient()
          ..maxConnectionsPerHost = 6
          ..idleTimeout = const Duration(seconds: 30)
          ..connectionTimeout = AppConstants.connectTimeout
          ..autoUncompress = true;
        return client;
      },
    );

    dio.interceptors.add(_DedupeInterceptor());
    dio.interceptors.add(_RetryInterceptor(dio));

    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        requestBody: false,
        responseBody: false,
        requestHeader: false,
      ));
    }
    return dio;
  }
}

/// Déduplique les GET identiques en vol : si la même URL + query est déjà
/// en cours, la seconde requête attend la première au lieu de repartir sur
/// le réseau. Fréquent quand plusieurs providers Riverpod se réveillent en
/// même temps (Home + rangées + héro).
class _DedupeInterceptor extends Interceptor {
  static final Map<String, Completer<Response>> _inFlight = {};

  String _key(RequestOptions o) => '${o.method} ${o.uri}';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.method.toUpperCase() != 'GET') return handler.next(options);

    final key = _key(options);
    final existing = _inFlight[key];
    if (existing != null) {
      // On rejoint la requête déjà en vol.
      existing.future.then(
        (r) => handler.resolve(Response(
          requestOptions: options,
          data: r.data,
          statusCode: r.statusCode,
          headers: r.headers,
        )),
        onError: (Object e) => handler.reject(
          e is DioException
              ? e
              : DioException(requestOptions: options, error: e),
        ),
      );
      return;
    }
    _inFlight[key] = Completer<Response>();
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _settle(_key(response.requestOptions), response: response);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _settle(_key(err.requestOptions), error: err);
    handler.next(err);
  }

  void _settle(String key, {Response? response, DioException? error}) {
    final completer = _inFlight.remove(key);
    if (completer == null || completer.isCompleted) return;
    if (response != null) {
      completer.complete(response);
    } else if (error != null) {
      // Évite un "unhandled exception" si personne n'attendait.
      completer.future.ignore();
      completer.completeError(error);
    }
  }
}

/// Réessaie les GET échoués sur erreur réseau transitoire :
/// 2 tentatives supplémentaires, backoff exponentiel (1 s, 2 s) + jitter.
class _RetryInterceptor extends Interceptor {
  final Dio _dio;
  final int maxRetries;
  final _random = Random();

  _RetryInterceptor(this._dio, {this.maxRetries = 2});

  bool _isTransient(DioException e) =>
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final attempt = (err.requestOptions.extra['retry_attempt'] as int?) ?? 0;
    final isGet = err.requestOptions.method.toUpperCase() == 'GET';

    if (isGet && _isTransient(err) && attempt < maxRetries) {
      final jitterMs = _random.nextInt(400);
      await Future.delayed(
        Duration(milliseconds: (1000 << attempt) + jitterMs),
      );
      final options = err.requestOptions
        ..extra['retry_attempt'] = attempt + 1;
      try {
        final response = await _dio.fetch(options);
        return handler.resolve(response);
      } on DioException catch (e) {
        return handler.next(e);
      }
    }
    handler.next(err);
  }
}
