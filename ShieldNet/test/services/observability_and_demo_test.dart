import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shieldnet/core/services/observability_service.dart';
import 'package:shieldnet/core/services/demo_mode_service.dart';
import 'package:shieldnet/core/network/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ObservabilityService Tests', () {
    test('Enregistrement et lecture des métriques d\'utilisation', () async {
      final obs = ObservabilityService.instance;
      await obs.resetMetrics();

      await obs.recordFeatureUsage('sms_inspection');
      await obs.recordFeatureUsage('sms_inspection');
      await obs.recordFeatureUsage('call_screening_demo');

      final stats = await obs.getFeatureUsageStats();
      expect(stats['sms_inspection'], 2);
      expect(stats['call_screening_demo'], 1);
      expect(stats['compliance_check'], 0);
    });

    test('Soumission et récupération d\'un retour utilisateur structuré', () async {
      final obs = ObservabilityService.instance;
      await obs.resetMetrics();

      await obs.submitStructuredFeedback(
        rating: 5,
        category: 'Satisfaction',
        comment: 'Interface très claire et détection instantanée !',
      );

      final list = await obs.getAllFeedbacks();
      expect(list.length, 1);
      expect(list.first.rating, 5);
      expect(list.first.category, 'Satisfaction');
      expect(list.first.comment, contains('instantanée'));
    });

    test('Réinitialisation complète des métriques d\'observabilité', () async {
      final obs = ObservabilityService.instance;
      await obs.recordFeatureUsage('threat_map_view');
      await obs.submitStructuredFeedback(rating: 4, category: 'Bug', comment: 'Mineur');

      await obs.resetMetrics();
      final stats = await obs.getFeatureUsageStats();
      final list = await obs.getAllFeedbacks();

      expect(stats['threat_map_view'], 0);
      expect(list.isEmpty, true);
    });
  });

  group('DemoModeService Tests', () {
    test('Les scénarios de simulation sont complets et valides', () {
      const scenarios = DemoModeService.demoScenarios;
      expect(scenarios.length, greaterThanOrEqualTo(4));

      for (final s in scenarios) {
        expect(s.containsKey('caller_name'), true);
        expect(s.containsKey('phone_number'), true);
        expect(s.containsKey('is_blocked'), true);
        expect(s.containsKey('risk_score'), true);
        expect(s.containsKey('category'), true);
      }
    });

    test('Les métriques de démonstration de flotte SOC sont cohérentes', () {
      final stats = DemoModeService.getDemoAdminStats();
      expect(stats['active_users'], greaterThan(100));
      expect(stats['total_blocked'], greaterThan(1000));
      expect(stats['false_positives_prevented'], greaterThan(0));
      expect((stats['fraud_categories'] as Map).isNotEmpty, true);
    });
  });

  group('ApiClient Configuration Tests', () {
    test('Candidate URLs contient au moins 3 adresses de repli', () {
      final urls = ApiClient.candidateBaseUrls;
      expect(urls.length, greaterThanOrEqualTo(3));
      expect(urls.any((u) => u.contains('127.0.0.1')), true);
      expect(urls.any((u) => u.contains('10.0.2.2')), true);
    });

    test('InitialBaseUrl retourne la première URL candidate valide', () {
      final initial = ApiClient.initialBaseUrl;
      expect(initial.isNotEmpty, true);
      expect(initial.startsWith('http'), true);
    });
  });
}
