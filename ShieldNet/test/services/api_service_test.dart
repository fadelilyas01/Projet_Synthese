import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shieldnet/core/network/api_service.dart';
import 'package:shieldnet/core/database/database_helper.dart';

// ==================== MOCKS ====================
class MockDio extends Mock implements Dio {}
class MockDatabaseHelper extends Mock implements DatabaseHelper {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(BlacklistedNumber(
      phoneHash: 'test',
      category: 'test',
      riskScore: 0,
      reportsCount: 1,
      updatedAt: '',
    ));
    registerFallbackValue(PendingSafeDispute(
      phoneHash: 'test',
      maskedNumber: '***',
      reason: 'test',
      createdAt: '',
    ));
  });

  late MockDio mockDio;
  late MockDatabaseHelper mockDb;
  late ApiService apiService;

  setUp(() {
    mockDio = MockDio();
    mockDb = MockDatabaseHelper();

    when(() => mockDb.batchInsertOrUpdateBlacklistedNumbers(any()))
        .thenAnswer((_) async {});
    when(() => mockDb.deleteBatchBlacklistedNumbers(any()))
        .thenAnswer((_) async => 0);
    when(() => mockDb.insertOrUpdateBlacklistedNumber(any()))
        .thenAnswer((_) async {});
    when(() => mockDb.whitelistHashDirect(
          phoneHash: any(named: 'phoneHash'),
          label: any(named: 'label'),
          rawOrMaskedNumber: any(named: 'rawOrMaskedNumber'),
        )).thenAnswer((_) async {});
    when(() => mockDb.insertPendingSafeDispute(any()))
        .thenAnswer((_) async => 1);

    apiService = ApiService(dio: mockDio, databaseHelper: mockDb);
    SharedPreferences.setMockInitialValues({});
  });

  group('ApiService — Synchronisation Delta (syncBlacklistWithBackend)', () {
    test('Sync delta avec payload Map (active + removed) retourne le total synchronisé', () async {
      when(() => mockDio.get('blacklist/', queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response(
                data: {
                  'active': [
                    {
                      'phone_hash': 'hash_abc123',
                      'masked_number': '+1 514 ***-1234',
                      'category': 'fraud',
                      'risk_score': 95,
                      'reports_count': 12,
                      'updated_at': '2026-09-17T07:00:00Z',
                    },
                    {
                      'phone_hash': 'hash_def456',
                      'masked_number': '+1 819 ***-5678',
                      'category': 'robocall',
                      'risk_score': 80,
                      'reports_count': 5,
                      'updated_at': '2026-09-17T07:00:00Z',
                    },
                  ],
                  'removed': ['purged_hash_001', 'purged_hash_002', 'purged_hash_003'],
                  'sync_timestamp': '2026-09-17T08:00:00Z',
                },
                statusCode: 200,
                requestOptions: RequestOptions(path: 'blacklist/'),
              ));

      final count = await apiService.syncBlacklistWithBackend(delta: true);

      // 2 active + 3 removed = 5
      expect(count, 5);

      // Vérifie que le timestamp est persisté
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_sync_timestamp'), '2026-09-17T08:00:00Z');
    });

    test('Sync complète avec payload List retourne le nombre d\'éléments', () async {
      when(() => mockDio.get('blacklist/', queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response(
                data: [
                  {
                    'phone_hash': 'hash_full_001',
                    'masked_number': '+1 613 ***-0001',
                    'category': 'telemarketing',
                    'risk_score': 60,
                    'reports_count': 3,
                    'updated_at': '2026-09-17T06:00:00Z',
                  },
                ],
                statusCode: 200,
                requestOptions: RequestOptions(path: 'blacklist/'),
              ));

      final count = await apiService.syncBlacklistWithBackend(delta: false);
      expect(count, 1);
    });

    test('Sync échouée (erreur réseau) retourne 0 sans lancer d\'exception', () async {
      when(() => mockDio.get('blacklist/', queryParameters: any(named: 'queryParameters')))
          .thenThrow(DioException(
        type: DioExceptionType.connectionError,
        requestOptions: RequestOptions(path: 'blacklist/'),
      ));

      final count = await apiService.syncBlacklistWithBackend();

      expect(count, 0);
    });
  });

  group('ApiService — Signalement (submitSpamReport)', () {
    test('Signalement réussi retourne true', () async {
      when(() => mockDio.post('reports/', data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                data: {'id': 'report_001', 'risk_score': 75, 'reports_count': 4},
                statusCode: 201,
                requestOptions: RequestOptions(path: 'reports/'),
              ));

      final result = await apiService.submitSpamReport(
        rawPhoneNumber: '+18195551234',
        category: 'fraud',
        comment: 'Appel frauduleux',
      );

      expect(result, true);
    });

    test('Signalement échoué retourne false', () async {
      when(() => mockDio.post('reports/', data: any(named: 'data')))
          .thenThrow(DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: 'reports/'),
        response: Response(
          data: {'detail': 'Erreur interne'},
          statusCode: 500,
          requestOptions: RequestOptions(path: 'reports/'),
        ),
      ));

      final result = await apiService.submitSpamReport(
        rawPhoneNumber: '+18195559999',
        category: 'phishing',
      );

      expect(result, false);
    });
  });

  group('ApiService — Vérification de Numéro (checkNumberOnBackend)', () {
    test('Vérification réussie retourne les données du serveur', () async {
      when(() => mockDio.get(any()))
          .thenAnswer((_) async => Response(
                data: {
                  'phone_hash': 'hash_check',
                  'is_spam': true,
                  'is_whitelisted': false,
                  'risk_score': 85,
                  'reports_count': 7,
                  'category': 'fraud',
                },
                statusCode: 200,
                requestOptions: RequestOptions(path: 'check/hash_check/'),
              ));

      final result = await apiService.checkNumberOnBackend('+18195550000');

      expect(result, isNotNull);
      expect(result!['is_spam'], true);
      expect(result['risk_score'], 85);
    });

    test('Vérification hors-ligne retourne null', () async {
      when(() => mockDio.get(any()))
          .thenThrow(DioException(
        type: DioExceptionType.connectionTimeout,
        requestOptions: RequestOptions(path: 'check/hash/'),
      ));

      final result = await apiService.checkNumberOnBackend('+18195550000');
      expect(result, isNull);
    });
  });

  group('ApiService — Vérification Groupée (checkNumbersBatch)', () {
    test('Liste vide retourne une carte vide sans requête réseau', () async {
      final res = await apiService.checkNumbersBatch([]);
      expect(res, isEmpty);
      verifyNever(() => mockDio.post(any(), data: any(named: 'data')));
    });

    test('Requête groupée valide traite et mappe les résultats', () async {
      when(() => mockDio.post('check/batch/', data: any(named: 'data')))
          .thenAnswer((invocation) async {
        final data = invocation.namedArguments[#data] as Map;
        final hashes = (data['hashes'] as List).cast<String>();
        final Map<String, dynamic> results = {};
        for (final h in hashes) {
          results[h] = {
            'is_spam': true,
            'risk_score': 80,
            'category': 'fraud',
          };
        }
        return Response(
          data: {'results': results, 'count': results.length},
          statusCode: 200,
          requestOptions: RequestOptions(path: 'check/batch/'),
        );
      });

      final numbers = ['+18195551111', '+18195552222'];
      final res = await apiService.checkNumbersBatch(numbers);

      expect(res, isNotNull);
      expect(res!.length, 2);
      expect(res['+18195551111']?['is_spam'], true);
      expect(res['+18195552222']?['risk_score'], 80);
    });

    test('Échec réseau retourne null', () async {
      when(() => mockDio.post('check/batch/', data: any(named: 'data')))
          .thenThrow(DioException(
        type: DioExceptionType.connectionError,
        requestOptions: RequestOptions(path: 'check/batch/'),
      ));

      final res = await apiService.checkNumbersBatch(['+18195551111']);
      expect(res, isNull);
    });
  });

  group('ApiService — Contestation Légitime (submitSafeReport)', () {
    test('Envoi avec phoneHash et maskedNumber réussit et blanchit localement', () async {
      when(() => mockDio.post('reports/safe/', data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                data: {
                  'phone_hash': 'h' * 64,
                  'detail': 'Avis enregistré',
                  'auto_whitelisted': true,
                },
                statusCode: 201,
                requestOptions: RequestOptions(path: 'reports/safe/'),
              ));

      final res = await apiService.submitSafeReport(
        phoneHash: 'h' * 64,
        maskedNumber: '+1 819 *** **34',
        reason: 'medical',
        comment: 'Clinique médicale locale',
      );

      expect(res, isNotNull);
      expect(res!['auto_whitelisted'], true);

      // Vérifie l'immunité immédiate locale
      verify(() => mockDb.whitelistHashDirect(
            phoneHash: 'h' * 64,
            label: 'Faux positif (medical)',
            rawOrMaskedNumber: '+1 819 *** **34',
          )).called(1);
    });

    test('Échec réseau bascule en mode hors-ligne sans bloquer l\'utilisateur', () async {
      when(() => mockDio.post('reports/safe/', data: any(named: 'data')))
          .thenThrow(DioException(
        type: DioExceptionType.connectionError,
        requestOptions: RequestOptions(path: 'reports/safe/'),
      ));

      final res = await apiService.submitSafeReport(
        phoneHash: 'f' * 64,
        maskedNumber: '+1 514 *** **99',
        reason: 'personal',
        comment: 'Ami proche',
      );

      expect(res, isNotNull);
      expect(res!['local_only'], true);
      expect(res['offline_queued'], true);

      // Vérifie que l'immunité locale est tout de même accordée
      verify(() => mockDb.whitelistHashDirect(
            phoneHash: 'f' * 64,
            label: 'Faux positif (personal)',
            rawOrMaskedNumber: '+1 514 *** **99',
          )).called(1);

      // Vérifie que la contestation est sauvegardée pour synchronisation ultérieure
      verify(() => mockDb.insertPendingSafeDispute(any())).called(1);
    });
  });
}
