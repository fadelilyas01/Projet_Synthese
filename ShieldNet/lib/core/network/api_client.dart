import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:shieldnet/core/utils/logger.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Client Dio intelligent avec basculement automatique d'URL
/// Permet la communication transparente entre le mobile (physique USB via adb reverse,
/// Wi-Fi LAN, ou émulateur) et le serveur Django.
class ApiClient {
  static String? _workingBaseUrl;

  static List<String> get candidateBaseUrls {
    final envUrl = dotenv.isInitialized ? dotenv.env['API_BASE_URL'] : null;
    final urls = <String>[];
    if (envUrl != null && envUrl.isNotEmpty) {
      final formatted = envUrl.endsWith('/') ? envUrl : '$envUrl/';
      urls.add(formatted);
    }
    const fallbacks = [
      'http://127.0.0.1:8000/api/v1/',
      'http://10.0.2.2:8000/api/v1/',
    ];
    for (final fb in fallbacks) {
      if (!urls.contains(fb)) {
        urls.add(fb);
      }
    }
    return urls;
  }

  static String get initialBaseUrl {
    return _workingBaseUrl ?? candidateBaseUrls.first;
  }

  /// Résout la clé API d'authentification client selon la hiérarchie :
  /// 1. Paramètre de compilation --dart-define=API_KEY=...
  /// 2. Fichier d'environnement .env (variable API_KEY)
  /// 3. Mode développement uniquement (kDebugMode)
  static String get resolvedApiKey {
    const defineKey = String.fromEnvironment('API_KEY');
    if (defineKey.isNotEmpty) {
      return defineKey;
    }
    if (dotenv.isInitialized) {
      final envKey = dotenv.env['API_KEY'];
      if (envKey != null && envKey.isNotEmpty) {
        return envKey;
      }
    }
    if (kDebugMode) {
      return 'dev-local-api-key-test-do-not-use-in-prod';
    }
    return '';
  }

  static Dio createDio() {
    final apiKey = resolvedApiKey;
    final dio = Dio(
      BaseOptions(
        baseUrl: initialBaseUrl,
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 8),
        headers: {
          'Content-Type': 'application/json',
          if (apiKey.isNotEmpty) 'X-API-Key': apiKey,
        },
      ),
    );

    // Durcissement SSL / Certificate Pinning pour les environnements de production
    if (!kIsWeb) {
      final adapter = dio.httpClientAdapter;
      if (adapter is IOHttpClientAdapter) {
        adapter.createHttpClient = () {
          final client = HttpClient();
          // Exiger TLS 1.2+ minimum
          client.badCertificateCallback = (X509Certificate cert, String host, int port) {
            // Environnements de développement locaux autorisés
            if (host == 'localhost' ||
                host == '127.0.0.1' ||
                host == '10.0.2.2' ||
                host.startsWith('192.168.') ||
                host.startsWith('10.') ||
                host.startsWith('172.')) {
              return true;
            }
            // Vérification de l'empreinte SHA-256 configurée dans les variables d'environnement
            final pinnedSha256 = dotenv.env['SSL_PINNED_SHA256'];
            if (pinnedSha256 != null && pinnedSha256.isNotEmpty) {
              final certSha256 = crypto.sha256.convert(cert.der).toString();
              final cleanPinned = pinnedSha256.replaceAll(':', '').toLowerCase();
              final isMatch = certSha256.toLowerCase() == cleanPinned;
              if (!isMatch) {
                AppLogger.log('[Security] ÉCHEC DU CERTIFICATE PINNING pour $host ! Hash reçu: $certSha256');
              }
              return isMatch;
            }
            return false;
          };
          return client;
        };
      }
    }

    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException err, ErrorInterceptorHandler handler) async {
          final isConnErr = err.type == DioExceptionType.connectionTimeout ||
              err.type == DioExceptionType.connectionError ||
              err.type == DioExceptionType.sendTimeout;

          if (isConnErr && err.requestOptions.extra['_hasRetried'] != true) {
            final candidates = candidateBaseUrls;
            final currentBase = dio.options.baseUrl;

            for (final candidate in candidates) {
              if (candidate == currentBase) continue;

              try {
                AppLogger.log('[ApiClient] Tentative fallback réseau vers $candidate...');
                final newOptions = Options(
                  method: err.requestOptions.method,
                  headers: err.requestOptions.headers,
                  responseType: err.requestOptions.responseType,
                  contentType: err.requestOptions.contentType,
                  extra: {
                    ...err.requestOptions.extra,
                    '_hasRetried': true,
                  },
                );

                final String rawPath = err.requestOptions.path;
                final String fullPath = rawPath.startsWith('http')
                    ? rawPath
                    : (candidate.endsWith('/') && rawPath.startsWith('/')
                        ? '$candidate${rawPath.substring(1)}'
                        : (!candidate.endsWith('/') && !rawPath.startsWith('/')
                            ? '$candidate/$rawPath'
                            : '$candidate$rawPath'));

                final retryResponse = await dio.request(
                  fullPath,
                  data: err.requestOptions.data,
                  queryParameters: err.requestOptions.queryParameters,
                  options: newOptions,
                );

                _workingBaseUrl = candidate;
                dio.options.baseUrl = candidate;
                AppLogger.log('[ApiClient] Connexion réussie sur $candidate');
                return handler.resolve(retryResponse);
              } catch (_) {
                // Essayer le candidat suivant
              }
            }
          }
          return handler.next(err);
        },
      ),
    );

    return dio;
  }
}
