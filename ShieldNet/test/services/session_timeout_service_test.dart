
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shieldnet/core/services/session_timeout_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionTimeoutService.instance.initialize();
    await SessionTimeoutService.instance.unlockSession();
  });

  group('SessionTimeoutService Tests', () {
    test('Par défaut, la session est déverrouillée', () {
      expect(SessionTimeoutService.instance.isLocked, isFalse);
      expect(SessionTimeoutService.instance.isLockedNotifier.value, isFalse);
    });

    test('lockSession verrouille la session et notifie les listeners', () async {
      await SessionTimeoutService.instance.lockSession();
      expect(SessionTimeoutService.instance.isLocked, isTrue);
      expect(SessionTimeoutService.instance.isLockedNotifier.value, isTrue);
    });

    test('unlockSession déverrouille la session', () async {
      await SessionTimeoutService.instance.lockSession();
      expect(SessionTimeoutService.instance.isLocked, isTrue);

      await SessionTimeoutService.instance.unlockSession();
      expect(SessionTimeoutService.instance.isLocked, isFalse);
      expect(SessionTimeoutService.instance.isLockedNotifier.value, isFalse);
    });

    test('Absence inférieure à 5 minutes ne verrouille pas la session', () async {
      await SessionTimeoutService.instance.onAppPaused();

      // Retour immédiat (moins de 5 min)
      final locked = await SessionTimeoutService.instance.onAppResumed();
      expect(locked, isFalse);
      expect(SessionTimeoutService.instance.isLocked, isFalse);
    });

    test('Absence supérieure ou égale à 5 minutes verrouille la session', () async {
      final prefs = await SharedPreferences.getInstance();
      // Simule une mise en pause il y a 6 minutes
      final sixMinutesAgo = DateTime.now().subtract(const Duration(minutes: 6));
      await prefs.setInt('shieldnet_last_background_time', sixMinutesAgo.millisecondsSinceEpoch);

      final locked = await SessionTimeoutService.instance.onAppResumed();
      expect(locked, isTrue);
      expect(SessionTimeoutService.instance.isLocked, isTrue);
      expect(SessionTimeoutService.instance.isLockedNotifier.value, isTrue);
    });

    test('Initialisation au démarrage avec timestamp expiré restaure le verrouillage', () async {
      final prefs = await SharedPreferences.getInstance();
      final tenMinutesAgo = DateTime.now().subtract(const Duration(minutes: 10));
      await prefs.setInt('shieldnet_last_background_time', tenMinutesAgo.millisecondsSinceEpoch);

      await SessionTimeoutService.instance.initialize();
      expect(SessionTimeoutService.instance.isLocked, isTrue);
    });
  });
}
