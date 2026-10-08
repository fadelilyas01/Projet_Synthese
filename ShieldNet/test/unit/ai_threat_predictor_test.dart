import 'package:flutter_test/flutter_test.dart';
import 'package:shieldnet/core/security/ai_threat_predictor.dart';

void main() {
  group('AiThreatPredictor — Tests d\'Intelligence Artificielle Avancée', () {
    test('Détection de Neighbor Spoofing quand les 6 premiers chiffres sont identiques', () {
      const userOwnNumber = '+1 (514) 732-1122';
      const spoofedCall = '+1 (514) 732-9988';

      final isSpoof = AiThreatPredictor.isNeighborSpoofing(
        incomingNumber: spoofedCall,
        userOwnNumber: userOwnNumber,
      );

      expect(isSpoof, isTrue);
    });

    test('Non détection de Neighbor Spoofing pour un indicatif différent', () {
      const userOwnNumber = '+1 (514) 732-1122';
      const normalCall = '+1 (418) 522-3344';

      final isSpoof = AiThreatPredictor.isNeighborSpoofing(
        incomingNumber: normalCall,
        userOwnNumber: userOwnNumber,
      );

      expect(isSpoof, isFalse);
    });

    test('Analyse d\'un numéro hautement suspect avec Neighbor Spoofing', () {
      const userOwnNumber = '+1 (514) 732-1122';
      const spoofedCall = '+1 (514) 732-9988';

      final analysis = AiThreatPredictor.analyze(
        incomingNumber: spoofedCall,
        userOwnNumber: userOwnNumber,
      );

      expect(analysis.isNeighborSpoofing, isTrue);
      expect(analysis.riskScore, greaterThanOrEqualTo(50));
      expect(analysis.riskFactors.any((f) => f.factorName == 'Usurpation Voisine'), isTrue);
    });

    test('Détection d\'abus sur les indicatifs sans frais (Toll-Free 800/888/877)', () {
      final analysis = AiThreatPredictor.analyze(
        incomingNumber: '+1 800 555 0199',
      );

      expect(analysis.isTollFreeAbuse, isTrue);
      expect(analysis.riskFactors.any((f) => f.factorName.contains('800')), isTrue);
    });

    test('Calcul d\'entropie de Shannon et détection des motifs artificiels', () {
      // Numéro répétitif à faible diversité de chiffres (1112222)
      final lowEntropy = AiThreatPredictor.calculateDigitEntropy('8191112222');
      expect(lowEntropy, lessThan(2.2));

      final analysis = AiThreatPredictor.analyze(
        incomingNumber: '+1 819 111 2222',
      );

      expect(analysis.isLowEntropyPattern, isTrue);
      expect(analysis.riskFactors.any((f) => f.factorName.contains('Entropie')), isTrue);
    });

    test('Détection d\'attaque en rafale séquentielle (Burst Dialing)', () {
      const recentCalls = ['+1 514 555 0101', '+1 514 555 0102'];
      const incoming = '+1 514 555 0103';

      final isBurst = AiThreatPredictor.isSequentialBurstNumber(incoming, recentCalls);
      expect(isBurst, isTrue);

      final analysis = AiThreatPredictor.analyze(
        incomingNumber: incoming,
        recentIncomingNumbers: recentCalls,
      );

      expect(analysis.detectedThreats.any((t) => t.contains('rafale séquentielle')), isTrue);
    });

    test('Analyse d\'un numéro international hors NANP (+33)', () {
      final analysis = AiThreatPredictor.analyze(
        incomingNumber: '+33 6 12 34 56 78',
      );

      expect(analysis.riskLevel, equals(AiRiskLevel.dangerous));
      expect(analysis.detectedThreats.any((t) => t.contains('international')), isTrue);
    });

    test('Analyse d\'un numéro valide nord-américain (+1 514 800 1234)', () {
      final analysis = AiThreatPredictor.analyze(
        incomingNumber: '+1 514 800 1234',
        userOwnNumber: '+1 819 555 9999',
        callTime: DateTime(2026, 10, 8, 14, 30),
      );

      expect(analysis.riskScore, equals(0));
      expect(analysis.riskLevel, equals(AiRiskLevel.safe));
      expect(analysis.detectedThreats, isEmpty);
      expect(analysis.riskFactors, isEmpty);
    });
  });
}
