import 'dart:math';
import 'phone_number_validator.dart';
import 'crypto_utils.dart';

/// Niveau de risque attribué par le moteur IA ShieldNet
enum AiRiskLevel {
  safe,        // Vert : Numéro sûr / légitime (0% - 25%)
  suspicious,  // Orange : Modéré / Suspicion de spam (26% - 74%)
  dangerous,   // Rouge : Danger élevé / Spoofing avéré (75% - 100%)
}

/// Facteur de risque individuel identifié par le moteur d'IA
class AiRiskFactor {
  final String factorName;
  final int scoreContribution;
  final String description;

  const AiRiskFactor({
    required this.factorName,
    required this.scoreContribution,
    required this.description,
  });
}

/// Résultat détaillé d'une analyse IA sur un numéro
class AiAnalysisResult {
  final String rawNumber;
  final String normalizedNumber;
  final int riskScore; // 0 à 100
  final AiRiskLevel riskLevel;
  final List<String> detectedThreats;
  final List<AiRiskFactor> riskFactors;
  final bool isNeighborSpoofing;
  final bool isTollFreeAbuse;
  final bool isLowEntropyPattern;
  final String recommendation;

  AiAnalysisResult({
    required this.rawNumber,
    required this.normalizedNumber,
    required this.riskScore,
    required this.riskLevel,
    required this.detectedThreats,
    required this.riskFactors,
    required this.isNeighborSpoofing,
    required this.isTollFreeAbuse,
    required this.isLowEntropyPattern,
    required this.recommendation,
  });
}

/// Moteur d'Analyse Prédictive IA Multi-Factoriel On-Device pour ShieldNet
class AiThreatPredictor {
  /// Indicatifs sans frais (Toll-Free) et surtaxés à haut risque d'abus par numéroteurs automatiques
  static const Set<String> _tollFreeAndAbusedAreaCodes = {
    '800', '888', '877', '866', '855', '844', '833', '900', '976'
  };

  /// Détecte l'usurpation de proximité (Neighbor Spoofing) :
  /// Les spammers usurpent les 6 premiers chiffres (Indicatif Régional + Préfixe Central)
  /// du numéro de la victime pour maximiser le taux de réponse.
  static bool isNeighborSpoofing({
    required String incomingNumber,
    required String userOwnNumber,
  }) {
    if (userOwnNumber.isEmpty) return false;

    final normIncoming = CryptoUtils.normalizePhoneNumber(incomingNumber).replaceAll(RegExp(r'\D'), '');
    final normUser = CryptoUtils.normalizePhoneNumber(userOwnNumber).replaceAll(RegExp(r'\D'), '');

    if (normIncoming.length != 11 || normUser.length != 11) return false;

    // Si le numéro est identique à celui de l'utilisateur, ce n'est pas un spoofing voisin
    if (normIncoming == normUser) return false;

    // Comparaison des 6 premiers chiffres du numéro national (+1 XXX YYY)
    final incomingPrefix = normIncoming.substring(1, 7); // Code région + Échange
    final userPrefix = normUser.substring(1, 7);

    return incomingPrefix == userPrefix;
  }

  /// Calcule l'entropie de Shannon de la séquence de chiffres.
  /// Une faible entropie (< 2.2) indique un numéro généré artificiellement (ex: 819-111-2222, 514-990-9900).
  static double calculateDigitEntropy(String nationalDigits) {
    if (nationalDigits.isEmpty) return 0.0;
    
    final frequencyMap = <String, int>{};
    for (int i = 0; i < nationalDigits.length; i++) {
      final char = nationalDigits[i];
      frequencyMap[char] = (frequencyMap[char] ?? 0) + 1;
    }

    double entropy = 0.0;
    final total = nationalDigits.length;
    for (final count in frequencyMap.values) {
      final p = count / total;
      entropy -= p * (log(p) / log(2));
    }

    return entropy;
  }

  /// Détecte si un numéro appartient à la catégorie des numéros séquentiels (Robocall Burst Dialing)
  static bool isSequentialBurstNumber(String incomingNumber, List<String> recentIncomingNumbers) {
    final normIncoming = CryptoUtils.normalizePhoneNumber(incomingNumber).replaceAll(RegExp(r'\D'), '');
    if (normIncoming.length != 11) return false;

    try {
      final currentInt = BigInt.parse(normIncoming);
      for (final prev in recentIncomingNumbers) {
        final normPrev = CryptoUtils.normalizePhoneNumber(prev).replaceAll(RegExp(r'\D'), '');
        if (normPrev.length == 11) {
          final prevInt = BigInt.parse(normPrev);
          final diff = (currentInt - prevInt).abs();
          if (diff >= BigInt.one && diff <= BigInt.from(5)) {
            return true; // Rafale séquentielle à 5 numéros d'écart !
          }
        }
      }
    } catch (_) {}

    return false;
  }

  /// Analyse algorithmique et prédictive complète d'un numéro entrant
  static AiAnalysisResult analyze({
    required String incomingNumber,
    String? userOwnNumber,
    DateTime? callTime,
    List<String> recentIncomingNumbers = const [],
  }) {
    final normalized = CryptoUtils.normalizePhoneNumber(incomingNumber);
    final threats = <String>[];
    final factors = <AiRiskFactor>[];
    int score = 0;
    bool neighborSpoofing = false;
    bool tollFreeAbuse = false;
    bool lowEntropyPattern = false;

    final digitsOnly = normalized.replaceAll(RegExp(r'\D'), '');

    // 1. Analyse du format & NANP (+1)
    if (!normalized.startsWith('+1')) {
      const contribution = 45;
      score += contribution;
      threats.add('Numéro international hors Amérique du Nord (+1)');
      factors.add(const AiRiskFactor(
        factorName: 'Format Hors-Zone NANP',
        scoreContribution: contribution,
        description: 'Origine internationale hors Canada/États-Unis.',
      ));
    }

    // 2. Détection de numéros générés ou invalides
    if (PhoneNumberValidator.isGeneratedOrSpoofedNumber(incomingNumber)) {
      const contribution = 40;
      score += contribution;
      threats.add('Motif numérique invalide / Spoofing VoIP');
      factors.add(const AiRiskFactor(
        factorName: 'Anomalie de Structure',
        scoreContribution: contribution,
        description: 'Séquences répétitives ou préfixes N11/555 non attribuables.',
      ));
    }

    // 3. Détection de Neighbor Spoofing (Usurpation de proximité)
    if (userOwnNumber != null && userOwnNumber.isNotEmpty) {
      neighborSpoofing = isNeighborSpoofing(
        incomingNumber: incomingNumber,
        userOwnNumber: userOwnNumber,
      );
      if (neighborSpoofing) {
        const contribution = 50;
        score += contribution;
        threats.add('Usurpation Voisine (Neighbor Spoofing) : 6 chiffres identiques');
        factors.add(const AiRiskFactor(
          factorName: 'Usurpation Voisine',
          scoreContribution: contribution,
          description: 'Identique aux 6 premiers chiffres de votre propre numéro.',
        ));
      }
    }

    // 4. Analyse des indicatifs sans frais (Toll-Free) & Surtaxés
    if (digitsOnly.length == 11 && digitsOnly.startsWith('1')) {
      final areaCode = digitsOnly.substring(1, 4);
      if (_tollFreeAndAbusedAreaCodes.contains(areaCode)) {
        tollFreeAbuse = true;
        const contribution = 20;
        score += contribution;
        threats.add('Indicatif sans frais / Surtaxé ($areaCode) fréquemment réutilisé par les centres de démarchage');
        factors.add(AiRiskFactor(
          factorName: 'Indicatif à Risque ($areaCode)',
          scoreContribution: contribution,
          description: 'Plage sans frais (800/888/877) couramment exploitée par les numéroteurs automatiques.',
        ));
      }
    }

    // 5. Calcul de l'Entropie Numérique (Faible diversité des chiffres)
    if (digitsOnly.length == 11) {
      final nationalDigits = digitsOnly.substring(1);
      final entropy = calculateDigitEntropy(nationalDigits);
      if (entropy < 2.2) {
        lowEntropyPattern = true;
        const contribution = 25;
        score += contribution;
        threats.add('Faible entropie numérique (Modèle artificiel généré par ordinateur)');
        factors.add(AiRiskFactor(
          factorName: 'Entropie Artificielle (${entropy.toStringAsFixed(2)})',
          scoreContribution: contribution,
          description: 'Diversité de chiffres anormalement basse, typique des générateurs automatiques.',
        ));
      }
    }

    // 6. Détection de Rafales Séquentielles (Burst Dialing)
    if (recentIncomingNumbers.isNotEmpty && isSequentialBurstNumber(incomingNumber, recentIncomingNumbers)) {
      const contribution = 35;
      score += contribution;
      threats.add('Attaque en rafale séquentielle (Robocall Burst Dialing)');
      factors.add(const AiRiskFactor(
        factorName: 'Rafale Séquentielle',
        scoreContribution: contribution,
        description: 'Écart numérique consécutif détecté parmi les récents appels entrants.',
      ));
    }

    // 7. Analyse heuristique horaire (Robocalls tardifs / nocturnes)
    final now = callTime ?? DateTime.now();
    if (now.hour >= 21 || now.hour < 7) {
      const contribution = 15;
      score += contribution;
      threats.add('Appel hors des heures d\'ouverture légales (21h-7h)');
      factors.add(const AiRiskFactor(
        factorName: 'Plage Horaire Nocturne',
        scoreContribution: contribution,
        description: 'Appel émis en dehors du cadre réglementaire habituel.',
      ));
    }

    // Normalisation du score entre 0 et 100
    score = score.clamp(0, 100);

    // Évaluation du niveau de risque
    AiRiskLevel level;
    String recommendation;

    if (score >= 75) {
      level = AiRiskLevel.dangerous;
      recommendation = 'Rejet automatique conseillé. Élevé au rang de spam avéré.';
    } else if (score >= 35) {
      level = AiRiskLevel.suspicious;
      recommendation = 'Prudence recommandée. Répondre uniquement si l\'appel est attendu.';
    } else {
      level = AiRiskLevel.safe;
      recommendation = 'Appel identifié comme légitime et sécurisé.';
    }

    return AiAnalysisResult(
      rawNumber: incomingNumber,
      normalizedNumber: normalized,
      riskScore: score,
      riskLevel: level,
      detectedThreats: threats,
      riskFactors: factors,
      isNeighborSpoofing: neighborSpoofing,
      isTollFreeAbuse: tollFreeAbuse,
      isLowEntropyPattern: lowEntropyPattern,
      recommendation: recommendation,
    );
  }
}
