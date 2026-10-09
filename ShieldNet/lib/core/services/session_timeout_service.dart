import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      }
    }

    isLockedNotifier.value = _isLocked;
  }

  /// Appelé lorsque l'application passe en arrière-plan (paused ou inactive)
  Future<void> onAppPaused() async {
    _lastBackgroundTime = DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastBackgroundTimeKey, _lastBackgroundTime!.millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Appelé lorsque l'application revient au premier plan (resumed)
  /// Renvoie `true` si la session a été verrouillée suite à une absence > 5 min.
  Future<bool> onAppResumed() async {
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

    if (checkTime != null) {
      final elapsed = now.difference(checkTime);
      if (elapsed >= timeoutDuration) {
        await lockSession();
        return true;
      }
    }

    // Si moins de 5 minutes, réinitialiser l'heure de départ
    _lastBackgroundTime = null;
    return _isLocked;
  }

  /// Verrouille la session
  Future<void> lockSession() async {
    _isLocked = true;
    isLockedNotifier.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kSessionLockedKey, true);
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
