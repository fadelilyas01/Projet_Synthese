import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shieldnet/core/services/auth_service.dart';

// ==================== MOCKS ====================
class MockDio extends Mock implements Dio {}
class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}
class FakeRequestOptions extends Fake implements RequestOptions {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDio mockDio;
  late MockFlutterSecureStorage mockStorage;
  late AuthService authService;

  setUpAll(() {
    registerFallbackValue(FakeRequestOptions());
  });

  setUp(() {
    mockDio = MockDio();
    mockStorage = MockFlutterSecureStorage();
    authService = AuthService(dio: mockDio, storage: mockStorage);
    
    // Default stub pour storage.write
    when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((_) async {});
  });

  group('AuthService — Connexion (Login)', () {
    test('Login réussi stocke les tokens et retourne le UserModel', () async {
      when(() => mockDio.post('auth/login/', data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                data: {
                  'user': {'id': 1, 'email': 'test@shieldnet.app', 'name': 'Test User', 'is_staff': false, 'is_superuser': false},
                  'tokens': {'access': 'jwt_access_token', 'refresh': 'jwt_refresh_token'},
                },
                statusCode: 200,
                requestOptions: RequestOptions(path: 'auth/login/'),
              ));

      final user = await authService.login(email: 'test@shieldnet.app', password: 'password123');

      expect(user.id, 1);
      expect(user.email, 'test@shieldnet.app');
      expect(user.name, 'Test User');
      expect(user.isAdmin, false);

      verify(() => mockStorage.write(key: 'auth_access_token', value: 'jwt_access_token')).called(1);
      verify(() => mockStorage.write(key: 'auth_refresh_token', value: 'jwt_refresh_token')).called(1);
      verify(() => mockStorage.write(key: 'auth_user_data', value: any(named: 'value'))).called(1);
    });

    test('Login échoué (identifiants incorrects) lance une exception avec message', () async {
      when(() => mockDio.post('auth/login/', data: any(named: 'data')))
          .thenThrow(DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: 'auth/login/'),
        response: Response(
          data: {'non_field_errors': ['Aucun compte actif avec ces identifiants.']},
          statusCode: 401,
          requestOptions: RequestOptions(path: 'auth/login/'),
        ),
      ));

      expect(
        () => authService.login(email: 'wrong@test.com', password: 'bad'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Aucun compte actif'),
        )),
      );
    });

    test('Login échoué (erreur réseau) lance une exception avec message de connexion', () async {
      when(() => mockDio.post('auth/login/', data: any(named: 'data')))
          .thenThrow(DioException(
        type: DioExceptionType.connectionError,
        requestOptions: RequestOptions(path: 'auth/login/'),
      ));

      expect(
        () => authService.login(email: 'test@test.com', password: 'pass'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Impossible de contacter le serveur'),
        )),
      );
    });
  });

  group('AuthService — Inscription (Register)', () {
    test('Inscription réussie retourne le UserModel et stocke les tokens', () async {
      when(() => mockDio.post('auth/register/', data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                data: {
                  'user': {'id': 2, 'email': 'new@shieldnet.app', 'name': 'Nouvel Utilisateur', 'is_staff': false, 'is_superuser': false},
                  'tokens': {'access': 'new_access', 'refresh': 'new_refresh'},
                },
                statusCode: 201,
                requestOptions: RequestOptions(path: 'auth/register/'),
              ));

      final user = await authService.register(email: 'new@shieldnet.app', password: 'secure123', name: 'Nouvel Utilisateur');

      expect(user.id, 2);
      expect(user.email, 'new@shieldnet.app');
      verify(() => mockStorage.write(key: 'auth_access_token', value: 'new_access')).called(1);
    });

    test('Inscription échouée (email existant) lance une exception détaillée', () async {
      when(() => mockDio.post('auth/register/', data: any(named: 'data')))
          .thenThrow(DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: 'auth/register/'),
        response: Response(
          data: {'email': ['Un compte avec cet email existe déjà.']},
          statusCode: 400,
          requestOptions: RequestOptions(path: 'auth/register/'),
        ),
      ));

      expect(
        () => authService.register(email: 'dup@test.com', password: 'pass'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Un compte avec cet email existe déjà'),
        )),
      );
    });
  });

  group('AuthService — Google Login', () {
    test('Connexion Google réussie retourne le UserModel', () async {
      when(() => mockDio.post('auth/google/', data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                data: {
                  'user': {'id': 3, 'email': 'google@gmail.com', 'name': 'Google User', 'is_staff': false, 'is_superuser': false},
                  'tokens': {'access': 'g_access', 'refresh': 'g_refresh'},
                },
                statusCode: 200,
                requestOptions: RequestOptions(path: 'auth/google/'),
              ));

      final user = await authService.googleLogin(email: 'google@gmail.com', name: 'Google User');

      expect(user.id, 3);
      expect(user.email, 'google@gmail.com');
      verify(() => mockStorage.write(key: 'auth_access_token', value: 'g_access')).called(1);
    });
  });

  group('AuthService — Déconnexion (Logout)', () {
    test('Logout supprime les 3 clés du SecureStorage', () async {
      when(() => mockStorage.delete(key: any(named: 'key')))
          .thenAnswer((_) async {});

      await authService.logout();

      verify(() => mockStorage.delete(key: 'auth_access_token')).called(1);
      verify(() => mockStorage.delete(key: 'auth_refresh_token')).called(1);
      verify(() => mockStorage.delete(key: 'auth_user_data')).called(1);
    });
  });

  group('AuthService — Utilisateur Courant', () {
    test('getCurrentUser retourne un UserModel si les données sont présentes', () async {
      final userData = jsonEncode({
        'id': 1,
        'email': 'cached@test.com',
        'name': 'Cached User',
        'is_staff': true,
        'is_superuser': false,
      });
      when(() => mockStorage.read(key: 'auth_user_data'))
          .thenAnswer((_) async => userData);

      final user = await authService.getCurrentUser();

      expect(user, isNotNull);
      expect(user!.email, 'cached@test.com');
      expect(user.isAdmin, true);
    });

    test('getCurrentUser retourne null si aucune donnée stockée', () async {
      when(() => mockStorage.read(key: 'auth_user_data'))
          .thenAnswer((_) async => null);

      final user = await authService.getCurrentUser();
      expect(user, isNull);
    });
  });

  group('AuthService — Administration', () {
    test('getAdminStats retourne les métriques serveur', () async {
      when(() => mockStorage.read(key: 'auth_access_token'))
          .thenAnswer((_) async => 'admin_jwt');
      when(() => mockDio.get('admin/stats/', options: any(named: 'options')))
          .thenAnswer((_) async => Response(
                data: {'total_blocked': 42, 'total_users': 10, 'total_reports': 7},
                statusCode: 200,
                requestOptions: RequestOptions(path: 'admin/stats/'),
              ));

      final stats = await authService.getAdminStats();

      expect(stats['total_blocked'], 42);
      expect(stats['total_users'], 10);
    });

    test('getAdminAuditLogs parse correctement une réponse paginée (Map avec results)', () async {
      when(() => mockStorage.read(key: 'auth_access_token'))
          .thenAnswer((_) async => 'admin_jwt');
      when(() => mockDio.get('admin/audit-logs/', queryParameters: any(named: 'queryParameters'), options: any(named: 'options')))
          .thenAnswer((_) async => Response(
                data: {
                  'results': [
                    {'id': '1', 'action': 'BLOCK_NUMBER', 'source': 'web', 'user_username': 'admin'},
                    {'id': '2', 'action': 'WHITELIST_NUMBER', 'source': 'mobile', 'user_username': 'admin'},
                  ],
                  'count': 2,
                },
                statusCode: 200,
                requestOptions: RequestOptions(path: 'admin/audit-logs/'),
              ));

      final logs = await authService.getAdminAuditLogs();

      expect(logs.length, 2);
      expect(logs[0]['action'], 'BLOCK_NUMBER');
      expect(logs[1]['source'], 'mobile');
    });

    test('getAdminAuditLogs parse correctement une réponse directe (List)', () async {
      when(() => mockStorage.read(key: 'auth_access_token'))
          .thenAnswer((_) async => 'admin_jwt');
      when(() => mockDio.get('admin/audit-logs/', queryParameters: any(named: 'queryParameters'), options: any(named: 'options')))
          .thenAnswer((_) async => Response(
                data: [
                  {'id': '1', 'action': 'PURGE', 'source': 'web', 'user_username': 'system'},
                ],
                statusCode: 200,
                requestOptions: RequestOptions(path: 'admin/audit-logs/'),
              ));

      final logs = await authService.getAdminAuditLogs();

      expect(logs.length, 1);
      expect(logs[0]['action'], 'PURGE');
    });
  });

  group('AuthService — Modification du mot de passe (changePassword)', () {
    test('changePassword réussi met à jour les tokens JWT', () async {
      when(() => mockStorage.read(key: 'auth_access_token'))
          .thenAnswer((_) async => 'old_jwt_token');
      when(() => mockDio.post('auth/password/change/', data: any(named: 'data'), options: any(named: 'options')))
          .thenAnswer((_) async => Response(
                data: {
                  'detail': 'Votre mot de passe a été modifié avec succès.',
                  'tokens': {
                    'access': 'new_jwt_access',
                    'refresh': 'new_jwt_refresh',
                  },
                },
                statusCode: 200,
                requestOptions: RequestOptions(path: 'auth/password/change/'),
              ));

      await authService.changePassword(
        currentPassword: 'OldPassword123!',
        newPassword: 'NewPassword456!',
        confirmPassword: 'NewPassword456!',
      );

      verify(() => mockStorage.write(key: 'auth_access_token', value: 'new_jwt_access')).called(1);
      verify(() => mockStorage.write(key: 'auth_refresh_token', value: 'new_jwt_refresh')).called(1);
    });

    test('changePassword sans jeton lance une exception session expirée', () async {
      when(() => mockStorage.read(key: 'auth_access_token'))
          .thenAnswer((_) async => null);

      expect(
        () => authService.changePassword(
          currentPassword: 'OldPassword123!',
          newPassword: 'NewPassword456!',
          confirmPassword: 'NewPassword456!',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Session expirée'),
        )),
      );
    });

    test('changePassword rejeté par le serveur extrait l\'erreur métier', () async {
      when(() => mockStorage.read(key: 'auth_access_token'))
          .thenAnswer((_) async => 'valid_token');
      when(() => mockDio.post('auth/password/change/', data: any(named: 'data'), options: any(named: 'options')))
          .thenThrow(DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: 'auth/password/change/'),
        response: Response(
          data: {'old_password': ['Le mot de passe actuel est incorrect.']},
          statusCode: 400,
          requestOptions: RequestOptions(path: 'auth/password/change/'),
        ),
      ));

      expect(
        () => authService.changePassword(
          currentPassword: 'BadPassword!',
          newPassword: 'NewPassword456!',
          confirmPassword: 'NewPassword456!',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Le mot de passe actuel est incorrect'),
        )),
      );
    });
  });

  group('UserModel', () {
    test('isAdmin retourne true quand is_staff ou is_superuser', () {
      final staff = UserModel(id: 1, email: 'a@b.com', name: 'A', isStaff: true, isSuperuser: false);
      final superuser = UserModel(id: 2, email: 'b@b.com', name: 'B', isStaff: false, isSuperuser: true);
      final normal = UserModel(id: 3, email: 'c@b.com', name: 'C', isStaff: false, isSuperuser: false);

      expect(staff.isAdmin, true);
      expect(superuser.isAdmin, true);
      expect(normal.isAdmin, false);
    });

    test('fromJson parse correctement les valeurs nulles', () {
      final user = UserModel.fromJson({'id': 1});

      expect(user.email, '');
      expect(user.name, '');
      expect(user.isStaff, false);
      expect(user.isSuperuser, false);
    });
  });
}
