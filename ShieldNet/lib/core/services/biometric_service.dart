import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  static const String _prefsKey = 'shieldnet_biometric_enabled';

  /// Vérifie si l'appareil supporte la biométrie et qu'au moins une empreinte/visage est configuré
  Future<bool> isBiometricsAvailable() async {
    try {
      final bool canCheckBiometrics = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();
      return canCheckBiometrics && isDeviceSupported;
    } on PlatformException catch (e) {
      debugPrint('BiometricAvailability Error: ${e.message}');
      return false;
    }
  }

  /// Récupère les types de biométrie disponibles sur l'appareil (Face, Fingerprint, etc.)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      debugPrint('GetAvailableBiometrics Error: ${e.message}');
      return <BiometricType>[];
    }
  }

  /// Vérifie si l'utilisateur a activé la protection biométrique dans l'application
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }

  /// Active ou désactive la protection biométrique dans l'application
  Future<bool> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setBool(_prefsKey, enabled);
  }

  static bool _isAuthenticating = false;

  /// Indique si une authentification biométrique est activement en cours
  static bool get isAuthenticating => _isAuthenticating;

  /// Déclenche la vérification biométrique avec sécurité stricte
  Future<bool> authenticate({
    String reason = 'Authentifiez-vous pour déverrouiller ShieldNet',
    bool biometricOnly = true,
  }) async {
    if (_isAuthenticating) return false;
    _isAuthenticating = true;
    try {
      final bool isAvailable = await isBiometricsAvailable();
      if (!isAvailable) {
        // En mode natif mobile, si la biométrie est indisponible ou non enregistrée,
        // c'est un ÉCHEC STRICT. Aucun déverrouillage silencieux !
        if (kIsWeb) return true;
        debugPrint('[Security] Biométrie indisponible ou non configurée sur le matériel');
        return false;
      }

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: biometricOnly,
          useErrorDialogs: true,
        ),
      );

      return didAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('[Security] Erreur biométrique plateforme: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[Security] Erreur biométrique: $e');
      return false;
    } finally {
      _isAuthenticating = false;
    }
  }
}
