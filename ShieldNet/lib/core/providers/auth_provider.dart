import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

import '../network/api_client.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

class AuthNotifier extends StateNotifier<UserModel?> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(null) {
    ApiClient.onUnauthorized = () {
      logout();
    };
    checkCurrentUser();
  }

  Future<void> checkCurrentUser() async {
    final cached = await _authService.getCurrentUser();
    state = cached;

    if (cached != null) {
      final fresh = await _authService.fetchCurrentProfile();
      state = fresh;
    }
  }

  Future<void> validateSession() async {
    final fresh = await _authService.fetchCurrentProfile();
    state = fresh;
  }

  Future<void> login(String email, String password) async {
    final user = await _authService.login(email: email, password: password);
    state = user;
  }

  Future<void> register(
    String email,
    String password, {
    String? name,
    String country = 'CA',
    String provinceOrState = 'QC',
  }) async {
    final user = await _authService.register(
      email: email,
      password: password,
      name: name,
    );
    state = user;
  }

  Future<void> googleLogin(String email, {String? name}) async {
    final user = await _authService.googleLogin(email: email, name: name);
    state = user;
  }

  Future<void> logout() async {
    await _authService.logout();
    state = null;
  }

  Future<void> updateRegion(String country, String provinceOrState) async {
    try {
      final updated = await _authService.updateRegion(country: country, provinceOrState: provinceOrState);
      state = updated;
    } catch (_) {
      // Si hors-ligne ou erreur, mettre à jour localement
      if (state != null) {
        state = state!.copyWith(country: country, provinceOrState: provinceOrState);
      }
    }
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, UserModel?>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});
