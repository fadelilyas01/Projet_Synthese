import 'package:call_log/call_log.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/logger.dart';

/// Helper thread-safe pour interroger le journal d'appels natif sans risque
/// de collision d'appels de méthode ou de crash "Reply already submitted" dans sk.fourq.calllog.
class CallLogHelper {
  static Future<Iterable<CallLogEntry>>? _inFlightQuery;
  static List<CallLogEntry>? _cachedEntries;
  static DateTime? _lastFetchTime;

  /// Récupère les entrées du journal d'appels de façon atomique, avec cache mémoire court (10s)
  /// et filtrage par date (30 derniers jours) pour éviter les gels d'interface au démarrage.
  static Future<List<CallLogEntry>> getSafeEntries({int limit = 50, bool forceRefresh = false}) async {
    try {
      final status = await Permission.phone.status;
      if (!status.isGranted) {
        return const [];
      }

      final now = DateTime.now();
      if (!forceRefresh &&
          _cachedEntries != null &&
          _lastFetchTime != null &&
          now.difference(_lastFetchTime!).inSeconds < 10) {
        return _cachedEntries!.take(limit).toList();
      }

      if (_inFlightQuery != null) {
        final existing = await _inFlightQuery!;
        return existing.take(limit).toList();
      }

      // Filtrer sur les 30 derniers jours pour éviter de scanner des années d'appels natifs
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      _inFlightQuery = CallLog.query(dateTimeFrom: thirtyDaysAgo);
      final entries = await _inFlightQuery!;
      _cachedEntries = entries.toList();
      _lastFetchTime = DateTime.now();
      return _cachedEntries!.take(limit).toList();
    } catch (e) {
      AppLogger.log('[CallLogHelper] Erreur sécurisée lors de la lecture du journal d\'appels: $e');
      return _cachedEntries?.take(limit).toList() ?? const [];
    } finally {
      _inFlightQuery = null;
    }
  }

  /// Invalide le cache en mémoire (ex: lors d'un pull-to-refresh)
  static void invalidateCache() {
    _cachedEntries = null;
    _lastFetchTime = null;
  }
}
