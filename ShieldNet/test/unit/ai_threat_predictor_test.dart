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

    test('Détection d\'usurpation par grappe régionale superposée (Overlay Cluster Spoofing)', () {
      // Victime a un 514-732-xxxx à Montréal, le spammer tente d'esquiver avec 438-732-xxxx
      const userOwnNumber = '+1 (514) 732-1122';
      const overlaySpoofedCall = '+1 (438) 732-9988';

      final isOverlaySpoof = AiThreatPredictor.isOverlayClusterSpoofing(
        incomingNumber: overlaySpoofedCall,
        userOwnNumber: userOwnNumber,
      );

      expect(isOverlaySpoof, isTrue);

      final analysis = AiThreatPredictor.analyze(
        incomingNumber: overlaySpoofedCall,
        userOwnNumber: userOwnNumber,
      );

      expect(analysis.riskScore, greaterThanOrEqualTo(40));
      expect(analysis.riskFactors.any((f) => f.factorName.contains('Grappe Régionale')), isTrue);
    });

    test('Immunité absolue et garantie anti-faux positifs pour les services institutionnels (811, 911, 988)', () {
      final analysis811 = AiThreatPredictor.analyze(incomingNumber: '811');
      expect(analysis811.riskScore, equals(0));
      expect(analysis811.riskLevel, equals(AiRiskLevel.safe));
      expect(analysis811.isInstitutionalExempt, isTrue);

      final analysis911 = AiThreatPredictor.analyze(incomingNumber: '911');
      expect(analysis911.riskScore, equals(0));
      expect(analysis911.isInstitutionalExempt, isTrue);

      // Agence du revenu du Canada (ARC 1-800 officiel)
      final analysisCRA = AiThreatPredictor.analyze(incomingNumber: '+1 800 267 8097');
      expect(analysisCRA.riskScore, equals(0));
      expect(analysisCRA.isInstitutionalExempt, isTrue);
    });

    test('Atténuation anti-faux positifs par historique d\'interaction réelle (>20s)', () {
      // Un numéro 1-800 normalement considéré comme démarchage (score 20)
      // mais avec lequel l'utilisateur a un historique d'appel de 45 secondes
      final analysisWithHistory = AiThreatPredictor.analyze(
        incomingNumber: '+1 800 555 0199',
        hasPreviousInteraction: true,
        pastCallDurationSeconds: 45,
      );

      expect(analysisWithHistory.riskScore, equals(0));
      expect(analysisWithHistory.riskLevel, equals(AiRiskLevel.safe));
      expect(analysisWithHistory.riskFactors.any((f) => f.factorName == 'Correspondant Familier'), isTrue);
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
