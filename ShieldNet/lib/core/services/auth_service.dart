import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../network/api_client.dart';
import '../utils/logger.dart';

class UserModel {
  final int id;
  final String email;
  final String name;
  final bool isStaff;
  final bool isSuperuser;
  final String role;
  final String country;
  final String provinceOrState;
  final String? countryName;
  final String? provinceName;
  final Map<String, dynamic>? complianceNorm;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.isStaff = false,
    this.isSuperuser = false,
    this.role = 'CITIZEN',
    this.country = 'CA',
    this.provinceOrState = 'QC',
    this.countryName,
    this.provinceName,
    this.complianceNorm,
  });

  bool get isAdmin => isStaff || isSuperuser || role == 'ADMIN';
  bool get isSuperAdmin => isSuperuser || role == 'ADMIN';
  bool get isManager => (role == 'MANAGER' || isStaff) && !isSuperuser && role != 'ADMIN';
  bool get canModerate => isAdmin || isManager;

  String get countryFlag => country == 'CA' ? '🇨🇦' : (country == 'US' ? '🇺🇸' : '');
  String get resolvedCountryName => countryName ?? (country == 'CA' ? 'Canada' : 'États-Unis');
  String get resolvedProvinceName =>
      provinceName ?? (country == 'CA' && provinceOrState == 'QC' ? 'Québec' : provinceOrState);
  String get normTitle =>
      complianceNorm?['norm_name'] as String? ??
      (country == 'CA' && provinceOrState == 'QC'
          ? 'Loi 25 du Québec'
          : (country == 'CA' ? 'LPRPDE / PIPEDA & LCAP' : 'TCPA & FCC'));

  UserModel copyWith({
    int? id,
    String? email,
    String? name,
    bool? isStaff,
    bool? isSuperuser,
    String? role,
    String? country,
    String? provinceOrState,
    String? countryName,
    String? provinceName,
    Map<String, dynamic>? complianceNorm,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      isStaff: isStaff ?? this.isStaff,
      isSuperuser: isSuperuser ?? this.isSuperuser,
      role: role ?? this.role,
      country: country ?? this.country,
      provinceOrState: provinceOrState ?? this.provinceOrState,
      countryName: countryName ?? this.countryName,
      provinceName: provinceName ?? this.provinceName,
      complianceNorm: complianceNorm ?? this.complianceNorm,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final staff = json['is_staff'] as bool? ?? false;
    final superuser = json['is_superuser'] as bool? ?? false;
    final rawRole = json['role'] as String?;
    final resolvedRole = rawRole ?? (superuser ? 'ADMIN' : (staff ? 'MANAGER' : 'CITIZEN'));
    final country = (json['country'] as String? ?? 'CA').toUpperCase();
    final prov = (json['province_or_state'] as String? ?? 'QC').toUpperCase();

    return UserModel(
      id: json['id'] as int,
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isStaff: staff,
      isSuperuser: superuser,
      role: resolvedRole,
      country: country,
      provinceOrState: prov,
      countryName: json['country_name'] as String?,
      provinceName: json['province_name'] as String?,
      complianceNorm: json['compliance_norm'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'is_staff': isStaff,
    'is_superuser': isSuperuser,
    'role': role,
    'country': country,
    'province_or_state': provinceOrState,
    'country_name': countryName,
    'province_name': provinceName,
    'compliance_norm': complianceNorm,
  };
}

class AuthService {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  static const String _kAccessToken = 'auth_access_token';
  static const String _kRefreshToken = 'auth_refresh_token';
  static const String _kUserData = 'auth_user_data';

  AuthService({Dio? dio, FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(),
        _dio = dio ?? ApiClient.createDio();

  /// Connexion avec Email et Mot de passe
  Future<UserModel> login({required String email, required String password}) async {
    try {
      final response = await _dio.post(
        'auth/login/',
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
        final tokens = data['tokens'] as Map<String, dynamic>;

        await _storage.write(key: _kAccessToken, value: tokens['access'] as String);
        await _storage.write(key: _kRefreshToken, value: tokens['refresh'] as String);
        await _storage.write(key: _kUserData, value: jsonEncode(user.toJson()));

        return user;
      }
      throw Exception("Réponse invalide du serveur");
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
        throw Exception("Impossible de contacter le serveur ShieldNet. Vérifiez que le serveur Django est démarré.");
      }
      final detail = e.response?.data;
      if (detail is Map && detail['non_field_errors'] != null) {
        throw Exception((detail['non_field_errors'] as List).join(', '));
      }
      throw Exception(e.response?.data?['detail'] ?? "Email ou mot de passe incorrect.");
    }
  }

  /// Inscription avec Email et Mot de passe
  Future<UserModel> register({
    required String email,
    required String password,
    String? name,
    String? country,
    String? provinceOrState,
  }) async {
    try {
      final response = await _dio.post(
        'auth/register/',
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
          'name': name ?? '',
          'country': ?country,
          'province_or_state': ?provinceOrState,
        },
      );

      if (response.statusCode == 201 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
        final tokens = data['tokens'] as Map<String, dynamic>;

        await _storage.write(key: _kAccessToken, value: tokens['access'] as String);
        await _storage.write(key: _kRefreshToken, value: tokens['refresh'] as String);
        await _storage.write(key: _kUserData, value: jsonEncode(user.toJson()));

        return user;
      }
      throw Exception("Échec de la création de compte");
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
        throw Exception("Impossible de contacter le serveur ShieldNet. Vérifiez que le serveur Django est démarré.");
      }
      final detail = e.response?.data;
      if (detail is Map) {
        final errors = detail.values.expand((v) => v is List ? v : [v]).join(', ');
        throw Exception(errors.isNotEmpty ? errors : "Erreur d'inscription.");
      }
      throw Exception("Erreur lors de l'inscription.");
    }
  }

  /// Connexion transparente avec un compte Google (adresse email et jeton d'authentification)
  Future<UserModel> googleLogin({required String email, String? name, String? idToken}) async {
    try {
      final response = await _dio.post(
        'auth/google/',
        data: {
          'email': email.trim().toLowerCase(),
          if (name != null && name.isNotEmpty) 'name': name.trim(),
          if (idToken != null && idToken.isNotEmpty) 'id_token': idToken,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
        final tokens = data['tokens'] as Map<String, dynamic>;

        await _storage.write(key: _kAccessToken, value: tokens['access'] as String);
        await _storage.write(key: _kRefreshToken, value: tokens['refresh'] as String);
        await _storage.write(key: _kUserData, value: jsonEncode(user.toJson()));

        return user;
      }
      throw Exception("Réponse invalide du serveur");
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
        throw Exception("Impossible de contacter le serveur ShieldNet. Vérifiez que le serveur Django est démarré.");
      }
      final detail = e.response?.data;
      if (detail is Map && detail['detail'] != null) {
        throw Exception(detail['detail']);
      }
      throw Exception("Erreur lors de la connexion Google.");
    }
  }

  /// Envoie un code OTP à 6 chiffres par courriel pour la réinitialisation de mot de passe
  Future<String> sendPasswordResetOtp(String email) async {
    try {
      final response = await _dio.post(
        'auth/email/send-otp/',
        data: {'email': email.trim().toLowerCase()},
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        return data['detail'] as String? ?? 'Code de vérification envoyé.';
      }
      throw Exception("Réponse invalide du serveur");
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
        throw Exception("Impossible de contacter le serveur ShieldNet. Vérifiez votre connexion.");
      }
      final detail = e.response?.data?['detail'];
      throw Exception(detail ?? "Échec de l'envoi du code de réinitialisation.");
    }
  }

  /// Vérifie le code OTP et enregistre le nouveau mot de passe
  Future<UserModel> resetPasswordWithOtp({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.post(
        'auth/email/verify-otp/',
        data: {
          'email': email.trim().toLowerCase(),
          'code': code.trim(),
          'new_password': newPassword,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
        final tokens = data['tokens'] as Map<String, dynamic>;

        await _storage.write(key: _kAccessToken, value: tokens['access'] as String);
        await _storage.write(key: _kRefreshToken, value: tokens['refresh'] as String);
        await _storage.write(key: _kUserData, value: jsonEncode(user.toJson()));

        return user;
      }
      throw Exception("Échec de la réinitialisation du mot de passe.");
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
        throw Exception("Impossible de contacter le serveur ShieldNet.");
      }
      final detail = e.response?.data?['detail'];
      throw Exception(detail ?? "Code invalide ou expiré.");
    }
  }

  /// Déconnexion
  Future<void> logout() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
    await _storage.delete(key: _kUserData);
  }

  /// Récupère l'utilisateur en mémoire sécurisée s'il est déjà connecté
  Future<UserModel?> getCurrentUser() async {
    try {
      final userStr = await _storage.read(key: _kUserData);
      if (userStr != null) {
        final map = jsonDecode(userStr) as Map<String, dynamic>;
        return UserModel.fromJson(map);
      }
    } catch (_) {}
    return null;
  }

  /// Valide et rafraîchit le profil utilisateur directement auprès du serveur Django (/api/v1/auth/me/).
  /// Si le compte a été supprimé ou révoqué (HTTP 401 / 403 / 404), purge la session locale et renvoie null.
  Future<UserModel?> fetchCurrentProfile() async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) {
      await logout();
      return null;
    }

    try {
      final response = await _dio.get(
        'auth/me/',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final user = UserModel.fromJson(response.data as Map<String, dynamic>);
        await _storage.write(key: _kUserData, value: jsonEncode(user.toJson()));
        return user;
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403 || status == 404) {
        AppLogger.log('[AuthService] Compte utilisateur révoqué ou supprimé ($status). Déconnexion immédiate.');
        await logout();
        return null;
      }
    } catch (_) {}

    return getCurrentUser();
  }

  /// Récupère le jeton JWT
  Future<String?> getAccessToken() async {
    return _storage.read(key: _kAccessToken);
  }

  /// Rafraîchit le jeton d'accès JWT expiré à l'aide du jeton de rafraîchissement
  Future<String?> refreshToken() async {
    final refresh = await _storage.read(key: _kRefreshToken);
    if (refresh == null || refresh.isEmpty) {
      return null;
    }
    try {
      final response = await _dio.post(
        'auth/token/refresh/',
        data: {'refresh': refresh},
      );
      if (response.statusCode == 200 && response.data != null) {
        final newAccess = response.data['access'] as String?;
        if (newAccess != null && newAccess.isNotEmpty) {
          await _storage.write(key: _kAccessToken, value: newAccess);
          return newAccess;
        }
      }
    } catch (e) {
      AppLogger.log('[AuthService] Échec du rafraîchissement JWT: $e');
    }
    return null;
  }

  /// Récupère les métriques globales du système (Réservé aux administrateurs)
  Future<Map<String, dynamic>> getAdminStats() async {
    final token = await getAccessToken();
    final response = await _dio.get(
      'admin/stats/',
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    if (response.statusCode == 200 && response.data != null) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Impossible de récupérer les métriques administrateur.');
  }

  /// Blanchit ou bloque un numéro (Réservé aux administrateurs)
  Future<String> moderateNumber({required String phoneHash, required String action}) async {
    final token = await getAccessToken();
    final response = await _dio.post(
      'admin/moderate/',
      data: {
        'phone_hash': phoneHash,
        'action': action, // 'whitelist' ou 'block'
      },
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    if (response.statusCode == 200 && response.data != null) {
      return (response.data as Map<String, dynamic>)['detail'] as String? ?? 'Action effectuée';
    }
    throw Exception('Échec de la modération');
  }

  /// Récupère la liste noire globale (avec filtres et recherche et pagination)
  Future<List<Map<String, dynamic>>> getAdminBlacklist({
    String? query,
    String? filter,
    String? category,
    int page = 1,
    int limit = 50,
  }) async {
    final token = await getAccessToken();
    final response = await _dio.get(
      'admin/blacklist/',
      queryParameters: {
        if (query != null && query.isNotEmpty) 'q': query,
        if (filter != null && filter != 'all') 'filter': filter,
        if (category != null && category.isNotEmpty) 'category': category,
        'page': page,
        'limit': limit,
      },
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    if (response.statusCode == 200 && response.data != null) {
      return (response.data as List).map((e) => e as Map<String, dynamic>).toList();
    }
    throw Exception('Impossible de récupérer la liste noire administrateur.');
  }

  /// Ajoute ou modifie directement un numéro dans la liste noire
  Future<Map<String, dynamic>> addAdminBlacklistNumber({
    String? phoneNumber,
    String? phoneHash,
    required String category,
    required int riskScore,
    required bool isBlocked,
    required bool isWhitelisted,
  }) async {
    final token = await getAccessToken();
    final response = await _dio.post(
      'admin/blacklist/',
      data: {
        if (phoneNumber != null && phoneNumber.isNotEmpty) 'phone_number': phoneNumber,
        if (phoneHash != null && phoneHash.isNotEmpty) 'phone_hash': phoneHash,
        'category': category,
        'risk_score': riskScore,
        'is_blocked': isBlocked,
        'is_whitelisted': isWhitelisted,
      },
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception("Impossible d'ajouter le numéro à la liste noire.");
  }

  /// Supprime définitivement un numéro de la liste noire
  Future<void> deleteAdminBlacklistNumber(String phoneHash) async {
    final token = await getAccessToken();
    final response = await _dio.delete(
      'admin/blacklist/$phoneHash/',
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Impossible de supprimer ce numéro.');
    }
  }

  /// Récupère la liste de tous les utilisateurs enregistrés
  Future<List<Map<String, dynamic>>> getAdminUsers() async {
    final token = await getAccessToken();
    final response = await _dio.get(
      'admin/users/',
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    if (response.statusCode == 200 && response.data != null) {
      return (response.data as List).map((e) => e as Map<String, dynamic>).toList();
    }
    throw Exception('Impossible de récupérer la liste des utilisateurs.');
  }

  /// Récupère la liste de tous les signalements utilisateurs
  Future<List<Map<String, dynamic>>> getAdminReports() async {
    final token = await getAccessToken();
    final response = await _dio.get(
      'admin/reports/',
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    if (response.statusCode == 200 && response.data != null) {
      return (response.data as List).map((e) => e as Map<String, dynamic>).toList();
    }
    throw Exception('Impossible de récupérer les signalements.');
  }

  /// Supprime un signalement utilisateur
  Future<void> deleteAdminReport(String reportId) async {
    final token = await getAccessToken();
    final response = await _dio.delete(
      'admin/reports/$reportId/',
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Impossible de supprimer ce signalement.');
    }
  }

  /// Déclenche la purge et le nettoyage automatique de la base de données
  Future<Map<String, dynamic>> purgeDatabase() async {
    final token = await getAccessToken();
    final response = await _dio.post(
      'admin/purge/',
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    if (response.statusCode == 200 && response.data != null) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Échec de la purge de la base.');
  }

  /// Récupère l'historique complet d'audit des actions administratives (Web & Mobile)
  Future<List<Map<String, dynamic>>> getAdminAuditLogs({int page = 1, int limit = 50}) async {
    final token = await getAccessToken();
    final response = await _dio.get(
      'admin/audit-logs/',
      queryParameters: {
        'page': page,
        'limit': limit,
      },
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    if (response.statusCode == 200 && response.data != null) {
      if (response.data is Map && response.data['results'] is List) {
        return (response.data['results'] as List).map((e) => e as Map<String, dynamic>).toList();
      }
      if (response.data is List) {
        return (response.data as List).map((e) => e as Map<String, dynamic>).toList();
      }
    }
    throw Exception('Impossible de récupérer le journal d\'audit.');
  }

  /// Récupère le statut global de synchronisation et la version active
  Future<Map<String, dynamic>> getSyncStatus() async {
    final token = await getAccessToken();
    final response = await _dio.get(
      'sync/status/',
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    if (response.statusCode == 200 && response.data != null) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Impossible de récupérer l\'état de synchronisation.');
  }

  /// Déclenche l'audit et la réévaluation automatique par consensualité de tous les faux positifs
  Future<Map<String, dynamic>> runConsensusAudit() async {
    final token = await getAccessToken();
    final response = await _dio.post(
      'admin/consensus-audit/',
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    if (response.statusCode == 200 && response.data != null) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Échec de l\'audit de consensualité.');
  }

  /// Récupère la liste des avis favorables / contestations de faux positifs
  Future<List<Map<String, dynamic>>> getAdminSafeReports() async {
    final token = await getAccessToken();
    final response = await _dio.get(
      'admin/safe-reports/',
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    if (response.statusCode == 200 && response.data != null) {
      return (response.data as List).map((e) => e as Map<String, dynamic>).toList();
    }
    throw Exception('Impossible de récupérer les contestations légitimes.');
  }

  /// Met à jour la région et juridiction de l'utilisateur (Pays & Province/État)
  Future<UserModel> updateRegion({
    required String country,
    required String provinceOrState,
  }) async {
    final token = await getAccessToken();
    final response = await _dio.post(
      'auth/region/',
      data: {
        'country': country.trim().toUpperCase(),
        'province_or_state': provinceOrState.trim().toUpperCase(),
      },
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    if (response.statusCode == 200 && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final updatedUser = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      await _storage.write(key: _kUserData, value: jsonEncode(updatedUser.toJson()));
      return updatedUser;
    }
    throw Exception('Échec de la mise à jour de la région.');
  }

  /// Récupère le détail des normes réglementaires pour une juridiction
  Future<Map<String, dynamic>> getComplianceNorms({
    required String country,
    required String provinceOrState,
  }) async {
    final response = await _dio.get(
      'compliance/norms/',
      queryParameters: {
        'country': country.trim().toUpperCase(),
        'province': provinceOrState.trim().toUpperCase(),
      },
    );
    if (response.statusCode == 200 && response.data != null) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Impossible de récupérer les normes réglementaires.');
  }

  /// Récupère la liste des pays et subdivisions supportées
  Future<Map<String, dynamic>> getAvailableRegions() async {
    final response = await _dio.get('compliance/regions/');
    if (response.statusCode == 200 && response.data != null) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Impossible de récupérer les régions supportées.');
  }
}

