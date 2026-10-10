import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'biometric_service.dart';

/// Service de gestion de temporisation et verrouillage automatique de session (5 minutes)
/// Détecte la mise en arrière-plan et déclenche le verrouillage sécurisé si l'absence dépasse 5 minutes.
class SessionTimeoutService {
  SessionTimeoutService._internal();
  static final SessionTimeoutService instance = SessionTimeoutService._internal();

  /// Durée d'inactivité ou d'absence maximale avant verrouillage automatique (5 minutes)
  static const Duration timeoutDuration = Duration(minutes: 5);

  static const String _kLastBackgroundTimeKey = 'shieldnet_last_background_time';
  static const String _kSessionLockedKey = 'shieldnet_session_locked';

  DateTime? _lastBackgroundTime;
  bool _isLocked = false;

  /// Notifier réactif permettant à l'UI d'écouter les changements d'état de verrouillage
  final ValueNotifier<bool> isLockedNotifier = ValueNotifier<bool>(false);

  bool get isLocked => _isLocked;

  /// Permet aux tests de configurer l'heure de mise en arrière-plan
  @visibleForTesting
  void setLastBackgroundTimeForTest(DateTime? time) {
    _lastBackgroundTime = time;
  }

  /// Initialise l'état au démarrage de l'application
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isLocked = prefs.getBool(_kSessionLockedKey) ?? false;

    final savedTimestamp = prefs.getInt(_kLastBackgroundTimeKey);
    if (savedTimestamp != null) {
      final lastTime = DateTime.fromMillisecondsSinceEpoch(savedTimestamp);
      final elapsed = DateTime.now().difference(lastTime);
      if (elapsed >= timeoutDuration) {
        _isLocked = true;
        await prefs.setBool(_kSessionLockedKey, true);
        await prefs.remove(_kLastBackgroundTimeKey);
      }
    }

    isLockedNotifier.value = _isLocked;
  }

  /// Appelé lorsque l'application passe en arrière-plan (paused)
  Future<void> onAppPaused() async {
    // Si la session est déjà verrouillée ou si la biométrie est en cours, ne pas toucher au timestamp
    if (BiometricService.isAuthenticating || _isLocked) return;

    // Conserver le premier horodatage de mise en arrière-plan (ne pas l'écraser)
    _lastBackgroundTime ??= DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getInt(_kLastBackgroundTimeKey);
      if (existing == null) {
        await prefs.setInt(_kLastBackgroundTimeKey, _lastBackgroundTime!.millisecondsSinceEpoch);
      }
    } catch (_) {}
  }

  /// Appelé lorsque l'application revient au premier plan (resumed)
  /// Renvoie `true` si la session vient d'être verrouillée suite à une absence >= 5 min.
  Future<bool> onAppResumed() async {
    if (BiometricService.isAuthenticating) return false;

    final now = DateTime.now();
    DateTime? checkTime = _lastBackgroundTime;

    if (checkTime == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedTimestamp = prefs.getInt(_kLastBackgroundTimeKey);
        if (savedTimestamp != null) {
          checkTime = DateTime.fromMillisecondsSinceEpoch(savedTimestamp);
        }
      } catch (_) {}
    }

    // Réinitialisation de l'heure de départ pour éviter toute réutilisation
    _lastBackgroundTime = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kLastBackgroundTimeKey);
    } catch (_) {}

    if (checkTime != null && !_isLocked) {
      final elapsed = now.difference(checkTime);
      if (elapsed >= timeoutDuration) {
        await lockSession();
        return true;
      }
    }

    return false;
  }

  /// Verrouille la session
  Future<void> lockSession() async {
    _isLocked = true;
    _lastBackgroundTime = null;
    isLockedNotifier.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kSessionLockedKey, true);
      await prefs.remove(_kLastBackgroundTimeKey);
    } catch (_) {}
  }

  /// Déverrouille la session (après biométrie réussie, mot de passe validé ou réinitialisation)
  Future<void> unlockSession() async {
    _isLocked = false;
    _lastBackgroundTime = null;
    isLockedNotifier.value = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kSessionLockedKey, false);
      await prefs.remove(_kLastBackgroundTimeKey);
    } catch (_) {}
  }
}
