import 'package:flutter_test/flutter_test.dart';
import 'package:shieldnet/core/services/demo_mode_service.dart';
import 'package:shieldnet/core/services/sms_phishing_detector.dart';

void main() {
  group('Regional SMS Phishing Samples Tests', () {
    test('Québec (QC) fournit des scénarios québécois authentiques (SAAQclic, Revenu Québec, Desjardins, Hydro-Québec)', () {
      final samplesFr = DemoModeService.getDemoSmsSamples(isEn: false, country: 'CA', provinceOrState: 'QC');
      expect(samplesFr.length, 5);

      final titlesFr = samplesFr.map((s) => s['title'] as String).toList();
      expect(titlesFr.any((t) => t.contains('SAAQclic')), isTrue);
      expect(titlesFr.any((t) => t.contains('Revenu Québec')), isTrue);
      expect(titlesFr.any((t) => t.contains('Desjardins')), isTrue);
      expect(titlesFr.any((t) => t.contains('Hydro-Québec')), isTrue);

      final samplesEn = DemoModeService.getDemoSmsSamples(isEn: true, country: 'CA', provinceOrState: 'QC');
      expect(samplesEn.length, 5);
      final titlesEn = samplesEn.map((s) => s['title'] as String).toList();
      expect(titlesEn.any((t) => t.contains('SAAQclic')), isTrue);
      expect(titlesEn.any((t) => t.contains('Revenu Québec')), isTrue);
    });

    test('Ontario (ON) fournit des scénarios ontariens réalistes (407 ETR, ServiceOntario, ARC/CRA, TD Canada Trust, Hydro One)', () {
      final samplesEn = DemoModeService.getDemoSmsSamples(isEn: true, country: 'CA', provinceOrState: 'ON');
      expect(samplesEn.length, 5);

      final titlesEn = samplesEn.map((s) => s['title'] as String).toList();
      expect(titlesEn.any((t) => t.contains('407 ETR')), isTrue);
      expect(titlesEn.any((t) => t.contains('ServiceOntario')), isTrue);
      expect(titlesEn.any((t) => t.contains('CRA')), isTrue);
      expect(titlesEn.any((t) => t.contains('Hydro One')), isTrue);

      final samplesFr = DemoModeService.getDemoSmsSamples(isEn: false, country: 'CA', provinceOrState: 'ON');
      expect(samplesFr.length, 5);
      final titlesFr = samplesFr.map((s) => s['title'] as String).toList();
      expect(titlesFr.any((t) => t.contains('407 ETR')), isTrue);
      expect(titlesFr.any((t) => t.contains('ServiceOntario')), isTrue);
    });

    test('Colombie-Britannique (BC) fournit des scénarios réalistes (ICBC, BC Hydro, CRA)', () {
      final samples = DemoModeService.getDemoSmsSamples(isEn: true, country: 'CA', provinceOrState: 'BC');
      expect(samples.length, 5);

      final titles = samples.map((s) => s['title'] as String).toList();
      expect(titles.any((t) => t.contains('ICBC')), isTrue);
      expect(titles.any((t) => t.contains('BC Hydro')), isTrue);
    });

    test('Californie (US-CA) fournit des scénarios californiens (DMV FasTrak, PG&E, Wells Fargo)', () {
      final samples = DemoModeService.getDemoSmsSamples(isEn: true, country: 'US', provinceOrState: 'CA');
      expect(samples.length, 5);

      final titles = samples.map((s) => s['title'] as String).toList();
      expect(titles.any((t) => t.contains('California DMV') || t.contains('FasTrak')), isTrue);
      expect(titles.any((t) => t.contains('PG&E')), isTrue);
      expect(titles.any((t) => t.contains('Wells Fargo')), isTrue);
    });

    test('New York (US-NY) fournit des scénarios new-yorkais (E-ZPass, Con Edison, NY DMV REAL ID, Chase)', () {
      final samples = DemoModeService.getDemoSmsSamples(isEn: true, country: 'US', provinceOrState: 'NY');
      expect(samples.length, 5);

      final titles = samples.map((s) => s['title'] as String).toList();
      expect(titles.any((t) => t.contains('E-ZPass')), isTrue);
      expect(titles.any((t) => t.contains('Con Edison')), isTrue);
      expect(titles.any((t) => t.contains('REAL ID')), isTrue);
    });

    test('Texas (US-TX) et Floride (US-FL) fournissent des scénarios propres à leurs juridictions', () {
      final samplesTx = DemoModeService.getDemoSmsSamples(isEn: true, country: 'US', provinceOrState: 'TX');
      final titlesTx = samplesTx.map((s) => s['title'] as String).toList();
      expect(titlesTx.any((t) => t.contains('TxTag')), isTrue);

      final samplesFl = DemoModeService.getDemoSmsSamples(isEn: true, country: 'US', provinceOrState: 'FL');
      final titlesFl = samplesFl.map((s) => s['title'] as String).toList();
      expect(titlesFl.any((t) => t.contains('SunPass')), isTrue);
      expect(titlesFl.any((t) => t.contains('FPL')), isTrue);
    });

    test('Changement dynamique : deux provinces différentes produisent des listes dissemblables', () {
      final qcSamples = DemoModeService.getDemoSmsSamples(isEn: true, country: 'CA', provinceOrState: 'QC');
      final onSamples = DemoModeService.getDemoSmsSamples(isEn: true, country: 'CA', provinceOrState: 'ON');
      final caSamples = DemoModeService.getDemoSmsSamples(isEn: true, country: 'US', provinceOrState: 'CA');

      // Le texte du premier scénario est différent pour chaque juridiction
      expect(qcSamples[0]['text'], isNot(equals(onSamples[0]['text'])));
      expect(onSamples[0]['text'], isNot(equals(caSamples[0]['text'])));
    });

    test('Analyse SmsPhishingDetector : Les scénarios dangereux et légitimes sont correctement qualifiés', () {
      final onSamples = DemoModeService.getDemoSmsSamples(isEn: true, country: 'CA', provinceOrState: 'ON');
      
      // 407 ETR toll evasion scam
      final dangerous407 = onSamples.firstWhere((s) => (s['title'] as String).contains('407 ETR'));
      final resultDangerous = SmsPhishingDetector.analyze(dangerous407['text'] as String, languageCode: 'en');
      expect(resultDangerous.level, PhishingRiskLevel.dangerous);
      expect(resultDangerous.riskScore, greaterThanOrEqualTo(65));

      // Hydro One safe statement
      final safeHydro = onSamples.firstWhere((s) => s['risk'] == 'SAFE');
      final resultSafe = SmsPhishingDetector.analyze(safeHydro['text'] as String, languageCode: 'en');
      expect(resultSafe.level, PhishingRiskLevel.safe);
      expect(resultSafe.riskScore, lessThanOrEqualTo(25));
    });
  });
}
