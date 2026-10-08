import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'auth_service.dart';

class GoogleSignInResult {
  final bool success;
  final UserModel? user;
  final String? errorMessage;

  GoogleSignInResult({
    required this.success,
    this.user,
    this.errorMessage,
  });
}

class GoogleSignInService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  final AuthService _authService;

  GoogleSignInService({AuthService? authService})
      : _authService = authService ?? AuthService();

  /// Lance l'authentification Google OAuth 2.0 et effectue le SSO sécurisé avec le backend Django
  Future<GoogleSignInResult> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        return GoogleSignInResult(
          success: false,
          errorMessage: 'Connexion Google annulée par l\'utilisateur.',
        );
      }

      final String email = account.email;
      final String name = account.displayName ?? account.email.split('@')[0];

      final UserModel user = await _authService.googleLogin(
        email: email,
        name: name,
      );

      return GoogleSignInResult(
        success: true,
        user: user,
      );
    } catch (e) {
      debugPrint('GoogleSignIn Error: $e');
      return GoogleSignInResult(
        success: false,
        errorMessage: 'Erreur lors de la connexion Google: ${e.toString()}',
      );
    }
  }

  /// Déconnexion du compte Google
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }
}

