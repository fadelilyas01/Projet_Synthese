import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  static const String _prefsKey = 'shieldnet_biometric_enabled';

  /// Vérifie si l'appareil supporte la biométrie (Face ID, Touch ID, Empreinte digitale)
  Future<bool> isBiometricsAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
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

  /// Déclenche la vérification biométrique avec message personnalisé
  Future<bool> authenticate({
    String reason = 'Authentifiez-vous pour déverrouiller ShieldNet',
  }) async {
    try {
      final bool isAvailable = await isBiometricsAvailable();
      if (!isAvailable) {
        // Fallback en mode web/test si biométrie indisponible
        return true;
      }

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );

      return didAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('Biometric Authentication Error: ${e.message}');
      return false;
    }
  }
}
