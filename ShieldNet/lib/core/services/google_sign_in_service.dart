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
    serverClientId: '840167295752-blo33h1dmitmo5loks63b7cjrp4ljshj.apps.googleusercontent.com',
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

      // Extraction du jeton d'authentification Google cryptographique (anti-usurpation)
      String? idToken;
      try {
        final auth = await account.authentication;
        idToken = auth.idToken;
      } catch (authError) {
        debugPrint('Google Auth token extraction info: $authError');
      }

      final UserModel user = await _authService.googleLogin(
        email: email,
        name: name,
        idToken: idToken,
      );

      return GoogleSignInResult(
        success: true,
        user: user,
      );
    } catch (e) {
      debugPrint('GoogleSignIn Error: $e');
      final errorStr = e.toString();
      String friendlyMessage;
      if (errorStr.contains('10') || errorStr.contains('DEVELOPER_ERROR') || errorStr.contains('sign_in_failed')) {
        friendlyMessage =
            'La clé SHA-1 de l\'application doit être configurée sur Google Cloud / Firebase. En attendant, connectez-vous directement avec votre courriel ci-dessous.';
      } else if (errorStr.contains('sign_in_canceled')) {
        friendlyMessage = 'Connexion Google annulée.';
      } else if (errorStr.contains('network_error')) {
        friendlyMessage = 'Problème de connexion réseau avec les serveurs Google.';
      } else {
        friendlyMessage = 'Connexion Google indisponible : $errorStr';
      }
      return GoogleSignInResult(
        success: false,
        errorMessage: friendlyMessage,
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

