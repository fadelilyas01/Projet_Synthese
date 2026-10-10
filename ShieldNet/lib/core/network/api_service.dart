import 'package:shared_preferences/shared_preferences.dart';
import 'package:shieldnet/core/utils/logger.dart';
import 'package:dio/dio.dart';
import '../database/database_helper.dart';
import '../security/crypto_utils.dart';
import '../security/bloom_filter_client.dart';
import '../models/regional_threat.dart';
import 'api_client.dart';

class ApiService {
  final Dio _dio;
  final DatabaseHelper _databaseHelper;

  ApiService({Dio? dio, DatabaseHelper? databaseHelper})
      : _dio = dio ?? ApiClient.createDio(),
        _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  /// Synchronise la liste noire globale depuis le serveur backend vers la base SQLite locale.
  /// Prend en charge la synchronisation différentielle (delta sync) et la purge locale
  /// des faux-positifs débloqués ou blanchis par les administrateurs.
  Future<int> syncBlacklistWithBackend({bool delta = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic>? queryParams;

      if (delta) {
        final lastSync = prefs.getString('last_sync_timestamp');
        if (lastSync != null && lastSync.isNotEmpty) {
          queryParams = {'since': lastSync};
        }
      }

      final response = await _dio.get('blacklist/', queryParameters: queryParams);

      if (response.statusCode == 200 && response.data != null) {
        // Cas 1 : Réponse Delta (Dictionnaire avec 'active' et 'removed')
        if (response.data is Map) {
          final map = response.data as Map;
          final List rawActive = (map['active'] as List?) ?? [];
          final List<String> removedHashes = ((map['removed'] as List?) ?? [])
              .map((e) => e.toString())
              .toList();

          // Insertion ou rafraîchissement des entrées signalées actives
          final activeNumbers = rawActive.map((item) {
            return BlacklistedNumber.fromMap({
              'phone_hash': item['phone_hash'],
              'masked_number': item['masked_number'],
              'category': item['category'],
              'risk_score': item['risk_score'],
              'reports_count': item['reports_count'],
              'updated_at': item['updated_at'] ?? DateTime.now().toIso8601String(),
            });
          }).toList();

          if (activeNumbers.isNotEmpty) {
            await _databaseHelper.batchInsertOrUpdateBlacklistedNumbers(activeNumbers);
          }

          // Nettoyage immédiat du cache pour les numéros réhabilités ou blanchis côté serveur
          if (removedHashes.isNotEmpty) {
            final purgedCount = await _databaseHelper.deleteBatchBlacklistedNumbers(removedHashes);
            AppLogger.log("[Sync] Purge de $purgedCount faux-positifs réussie.");
          }

          // Horodatage fourni par le backend pour le prochain delta
          final serverSyncTime = map['sync_timestamp'] as String? ?? DateTime.now().toIso8601String();
          await prefs.setString('last_sync_timestamp', serverSyncTime);

          return activeNumbers.length + removedHashes.length;
        }

        // Cas 2 : Réponse Liste Complète standard
        if (response.data is List) {
          final List data = response.data;
          final numbers = data.map((item) {
            return BlacklistedNumber.fromMap({
              'phone_hash': item['phone_hash'],
              'masked_number': item['masked_number'],
              'category': item['category'],
              'risk_score': item['risk_score'],
              'reports_count': item['reports_count'],
              'updated_at': item['updated_at'] ?? DateTime.now().toIso8601String(),
            });
          }).toList();

          if (numbers.isNotEmpty) {
            await _databaseHelper.batchInsertOrUpdateBlacklistedNumbers(numbers);
          }

          await prefs.setString('last_sync_timestamp', DateTime.now().toIso8601String());
          return numbers.length;
        }
      }
      return 0;
    } catch (e) {
      AppLogger.log("Erreur de synchronisation réseau: $e");
      return 0;
    }
  }

  /// Récupère le statut global de synchronisation et la version actuelle
  Future<Map<String, dynamic>?> getSyncStatus() async {
    try {
      final response = await _dio.get('sync/status/');
      if (response.statusCode == 200 && response.data is Map) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      AppLogger.log("Erreur récupération statut synchronisation: $e");
      return null;
    }
  }

  /// Soumet un nouveau signalement indésirable au backend
  Future<bool> submitSpamReport({
    required String rawPhoneNumber,
    required String category,
    String? comment,
  }) async {
    final phoneHash = await CryptoUtils.hashPhoneNumberAsync(rawPhoneNumber);
    final maskedNumber = CryptoUtils.maskPhoneNumber(rawPhoneNumber);

    try {
      final response = await _dio.post(
        'reports/',
        data: {
          'phone_hash': phoneHash,
          'masked_number': maskedNumber,
          'category': category,
          'comment': comment ?? '',
        },
      );
      
      if (response.statusCode == 201) {
        // Mettre à jour le cache local immédiatement
        await _databaseHelper.insertOrUpdateBlacklistedNumber(
          BlacklistedNumber(
            phoneHash: phoneHash,
            maskedNumber: maskedNumber,
            category: category,
            riskScore: response.data['risk_score'] ?? 50,
            reportsCount: response.data['reports_count'] ?? 1,
            updatedAt: DateTime.now().toIso8601String(),
          ),
        );
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.log("Erreur envoi signalement: $e");
      return false;
    }
  }

  /// Vérifie le score de risque d'un numéro auprès du serveur
  Future<Map<String, dynamic>?> checkNumberOnBackend(String rawPhoneNumber) async {
    final phoneHash = await CryptoUtils.hashPhoneNumberAsync(rawPhoneNumber);
    try {
      final response = await _dio.get('check/$phoneHash/');
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      AppLogger.log("Erreur vérification numéro: $e");
      return null;
    }
  }

  /// Vérifie en une seule requête HTTP un ensemble de numéros (jusqu'à 100).
  /// Reçoit une liste de numéros bruts, calcule leurs empreintes SHA-256 localement,
  /// et interroge l'endpoint `/api/v1/check/batch/`.
  /// Retourne un dictionnaire : { rawPhoneNumber: { 'is_spam': bool, 'risk_score': int, ... } }
  Future<Map<String, Map<String, dynamic>>?> checkNumbersBatch(List<String> rawPhoneNumbers) async {
    if (rawPhoneNumbers.isEmpty) return {};

    try {
      // Dédoublonnage et limitation à 100 numéros max
      final uniqueNumbers = rawPhoneNumbers.toSet().take(100).toList();
      final Map<String, String> hashToRawMap = {};

      for (final raw in uniqueNumbers) {
        final hash = await CryptoUtils.hashPhoneNumberAsync(raw);
        hashToRawMap[hash] = raw;
      }

      final response = await _dio.post(
        'check/batch/',
        data: {
          'hashes': hashToRawMap.keys.toList(),
        },
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        final rawResults = (data['results'] as Map?) ?? {};
        final Map<String, Map<String, dynamic>> finalResult = {};

        rawResults.forEach((key, val) {
          final hashStr = key.toString();
          final rawNum = hashToRawMap[hashStr] ?? hashStr;
          if (val is Map) {
            finalResult[rawNum] = Map<String, dynamic>.from(val);
          }
        });

        return finalResult;
      }
      return null;
    } catch (e) {
      AppLogger.log("Erreur vérification groupée de numéros: $e");
      return null;
    }
  }

  /// Soumet un avis favorable ou une contestation de faux-positif au serveur Django.
  /// Accepte soit un numéro brut (qui sera haché/masqué), soit directement son empreinte et numéro masqué.
  Future<Map<String, dynamic>?> submitSafeReport({
    String? rawPhoneNumber,
    String? phoneHash,
    String? maskedNumber,
    required String reason,
    String? comment,
  }) async {
    final computedHash = phoneHash ?? (rawPhoneNumber != null ? await CryptoUtils.hashPhoneNumberAsync(rawPhoneNumber) : null);
    if (computedHash == null) {
      AppLogger.log("submitSafeReport: phoneHash ou rawPhoneNumber requis.");
      return null;
    }
    final computedMasked = maskedNumber ?? (rawPhoneNumber != null ? CryptoUtils.maskPhoneNumber(rawPhoneNumber) : '***');

    // 1. Blanchiment immédiat sur l'appareil (Immunité native 0ms pour CallScreeningService)
    await _databaseHelper.whitelistHashDirect(
      phoneHash: computedHash,
      label: 'Faux positif ($reason)',
      rawOrMaskedNumber: computedMasked,
    );

    try {
      final response = await _dio.post(
        'reports/safe/',
        data: {
          'phone_hash': computedHash,
          'masked_number': computedMasked,
          'reason': reason,
          'comment': comment ?? '',
        },
      );
      if ((response.statusCode == 200 || response.statusCode == 201) && response.data is Map) {
        return response.data as Map<String, dynamic>;
      }
      // Réponse non-200 : Sauvegarder dans la file d'attente hors-ligne
      await _databaseHelper.insertPendingSafeDispute(
        PendingSafeDispute(
          phoneHash: computedHash,
          rawNumber: rawPhoneNumber,
          maskedNumber: computedMasked,
          reason: reason,
          comment: comment,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      return {'local_only': true, 'offline_queued': true};
    } catch (e) {
      AppLogger.log("Erreur envoi contestation légitime: $e — Enregistrement hors-ligne.");
      await _databaseHelper.insertPendingSafeDispute(
        PendingSafeDispute(
          phoneHash: computedHash,
          rawNumber: rawPhoneNumber,
          maskedNumber: computedMasked,
          reason: reason,
          comment: comment,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      return {'local_only': true, 'offline_queued': true};
    }
  }

  /// Récupère l'état d'alerte et l'analyse des menaces téléphoniques régionales
  Future<RegionalThreatSummary?> getRegionalThreats() async {
    try {
      final response = await _dio.get('threats/regional/');
      if (response.statusCode == 200 && response.data is Map) {
        return RegionalThreatSummary.fromJson(Map<String, dynamic>.from(response.data as Map));
      }
      return null;
    } catch (e) {
      AppLogger.log("Erreur récupération menaces régionales: $e");
      return null;
    }
  }

  /// Télécharge le filtre de Bloom compressé pour vérification ultra-rapide en mémoire vive
  Future<BloomFilterClient?> downloadBloomFilter({int sizeBits = 65536}) async {
    try {
      final response = await _dio.get('sync/bloom/', queryParameters: {'size_bits': sizeBits});
      if (response.statusCode == 200 && response.data is Map) {
        final filter = BloomFilterClient.fromJson(Map<String, dynamic>.from(response.data as Map));
        BloomFilterClient.activeFilter = filter;
        return filter;
      }
      return null;
    } catch (e) {
      AppLogger.log("Erreur téléchargement filtre de Bloom: $e");
      return null;
    }
  }
}

