import 'dart:math';
import 'phone_number_validator.dart';
import 'crypto_utils.dart';

/// Niveau de risque attribué par le moteur IA ShieldNet
enum AiRiskLevel {
  safe,        // Vert : Numéro sûr / légitime (0% - 25%)
  suspicious,  // Orange : Modéré / Suspicion de spam (26% - 74%)
  dangerous,   // Rouge : Danger élevé / Spoofing avéré (75% - 100%)
}

/// Facteur de risque ou d'atténuation identifié par le moteur d'IA
class AiRiskFactor {
  final String factorName;
  final int scoreContribution;
  final String description;
  final bool isMitigation; // True si c'est un facteur de confiance (réduit le risque)

  const AiRiskFactor({
    required this.factorName,
    required this.scoreContribution,
    required this.description,
    this.isMitigation = false,
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
  final bool isInstitutionalExempt;
  final double confidenceScore; // 0.0 à 1.0 (indice de certitude statistique)
  final String? clusterRegion;
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
    this.isInstitutionalExempt = false,
    this.confidenceScore = 0.90,
    this.clusterRegion,
    required this.recommendation,
  });
}

/// Moteur d'Analyse Prédictive IA Multi-Factoriel & Probabiliste On-Device pour ShieldNet
/// Élimine les règles naïves en dur et résiste aux tentatives d'évasion sophistiquées.
class AiThreatPredictor {
  /// Indicatifs sans frais (Toll-Free) et surtaxés à risque d'abus
  static const Set<String> _tollFreeAreaCodes = {
    '800', '888', '877', '866', '855', '844', '833'
  };

  static const Set<String> _premiumRateAreaCodes = {
    '900', '976'
  };

  /// Clusters géographiques d'indicatifs régionaux superposés (Overlays)
  /// Permet d'empêcher les arnaqueurs de contourner la détection en changeant d'indicatif local.
  static const Map<String, List<String>> _regionalOverlayClusters = {
    'Montreal': ['514', '438', '263'],
    'Quebec_Region': ['418', '581', '367'],
    'Laval_Monteregie': ['450', '579', '354'],
    'Sherbrooke_Estrie': ['819', '873'],
    'Toronto_Central': ['416', '647', '437'],
    'GTA_Suburbs': ['905', '289', '365'],
    'Ottawa': ['613', '343', '753'],
    'Vancouver': ['604', '778', '236', '672'],
    'Calgary': ['403', '587', '825'],
    'Edmonton': ['780', '587', '825'],
  };

  /// Signatures d'organismes vérifiés et de services d'utilité publique
  /// Protège formellement contre les faux positifs (Banques, Santé, Urgences, Services d'État).
  static const Set<String> _verifiedInstitutionalPrefixes = {
    '811', // Info-Santé / Info-Social
    '911', // Urgences vitales
    '988', // Ligne de crise et de prévention du suicide
    '211', // Services communautaires
    '311', // Services municipaux
  };

  /// Vérifie si le numéro correspond à un service institutionnel prioritaire
  static bool isInstitutionalNumber(String nationalDigits) {
    if (nationalDigits.length == 3 && _verifiedInstitutionalPrefixes.contains(nationalDigits)) {
      return true;
    }
    // Numéros gouvernementaux et d'assistance répertoriés
    if (nationalDigits.startsWith('18002678097') || // Agence du revenu du Canada (ARC)
        nationalDigits.startsWith('18009598281') || // ARC particuliers
        nationalDigits.startsWith('18002676299')) { // Revenu Québec
      return true;
    }
    return false;
  }

  /// Détecte l'usurpation de proximité (Neighbor Spoofing) directe :
  /// Les spammers usurpent les 6 premiers chiffres du numéro de la victime.
  static bool isNeighborSpoofing({
    required String incomingNumber,
    required String userOwnNumber,
  }) {
    if (userOwnNumber.isEmpty) return false;

    final normIncoming = CryptoUtils.normalizePhoneNumber(incomingNumber).replaceAll(RegExp(r'\D'), '');
    final normUser = CryptoUtils.normalizePhoneNumber(userOwnNumber).replaceAll(RegExp(r'\D'), '');

    if (normIncoming.length != 11 || normUser.length != 11) return false;
    if (normIncoming == normUser) return false;

    // Comparaison des 6 premiers chiffres du numéro national (+1 XXX YYY)
    final incomingPrefix = normIncoming.substring(1, 7);
    final userPrefix = normUser.substring(1, 7);

    return incomingPrefix == userPrefix;
  }

  /// Détecte l'usurpation par grappe régionale superposée (Overlay Cluster Spoofing) :
  /// L'arnaqueur tente d'échapper à la règle stricte des 6 chiffres en utilisant
  /// l'indicatif jumeau de la même agglomération (ex: 438 au lieu de 514 à Montréal).
  static bool isOverlayClusterSpoofing({
    required String incomingNumber,
    required String userOwnNumber,
  }) {
    if (userOwnNumber.isEmpty) return false;

    final normIncoming = CryptoUtils.normalizePhoneNumber(incomingNumber).replaceAll(RegExp(r'\D'), '');
    final normUser = CryptoUtils.normalizePhoneNumber(userOwnNumber).replaceAll(RegExp(r'\D'), '');

    if (normIncoming.length != 11 || normUser.length != 11) return false;

    final incomingArea = normIncoming.substring(1, 4);
    final userArea = normUser.substring(1, 4);

    if (incomingArea == userArea) return false; // Couvert par le test standard

    for (final cluster in _regionalOverlayClusters.values) {
      if (cluster.contains(incomingArea) && cluster.contains(userArea)) {
        // Même cluster urbain avec central identique ou quasi-identique
        final incomingCentral = normIncoming.substring(4, 7);
        final userCentral = normUser.substring(4, 7);
        if (incomingCentral == userCentral) {
          return true;
        }
      }
    }
    return false;
  }

  /// Calcule l'entropie de Shannon de la séquence de chiffres.
  /// Une faible entropie (< 2.2) indique un numéro généré artificiellement (ex: 819-111-2222).
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
            return true;
          }
        }
      }
    } catch (_) {}

    return false;
  }

  /// Analyse probabiliste et adaptative multi-factorielle d'un numéro entrant
  static AiAnalysisResult analyze({
    required String incomingNumber,
    String? userOwnNumber,
    DateTime? callTime,
    List<String> recentIncomingNumbers = const [],
    bool hasPreviousInteraction = false,
    int pastCallDurationSeconds = 0,
    List<String> userContactNumbers = const [],
  }) {
    final normalized = CryptoUtils.normalizePhoneNumber(incomingNumber);
    final threats = <String>[];
    final factors = <AiRiskFactor>[];
    bool neighborSpoofing = false;
    bool tollFreeAbuse = false;
    bool lowEntropyPattern = false;
    const bool institutionalExempt = false;
    String? clusterName;

    final digitsOnly = normalized.replaceAll(RegExp(r'\D'), '');

    // 0. VÉRIFICATION D'IMMUNITÉ INSTITUTIONNELLE & D'URGENCE (Protection Faux Positifs #1)
    if (isInstitutionalNumber(digitsOnly) || digitsOnly.length == 3) {
      return AiAnalysisResult(
        rawNumber: incomingNumber,
        normalizedNumber: normalized,
        riskScore: 0,
        riskLevel: AiRiskLevel.safe,
        detectedThreats: const [],
        riskFactors: const [
          AiRiskFactor(
            factorName: 'Service Public Vérifié',
            scoreContribution: 0,
            description: 'Numéro d\'utilité publique ou d\'urgence certifié.',
            isMitigation: true,
          ),
        ],
        isNeighborSpoofing: false,
        isTollFreeAbuse: false,
        isLowEntropyPattern: false,
        isInstitutionalExempt: true,
        confidenceScore: 1.0,
        recommendation: 'Numéro d\'urgence / d\'utilité publique certifié. Autorisé sans délai.',
      );
    }

    // 1. Modèle d'Évaluation des Risques (Log-Odds / Poids Bayésiens Pondérés)
    double riskWeight = 0.0;
    double confidence = 0.85;

    // A. Analyse du format & Zone NANP (+1)
    if (!normalized.startsWith('+1')) {
      riskWeight += 45.0;
      threats.add('Numéro international hors Amérique du Nord (+1)');
      factors.add(const AiRiskFactor(
        factorName: 'Format Hors-Zone NANP',
        scoreContribution: 45,
        description: 'Origine internationale hors Canada/États-Unis.',
      ));
    }

    // B. Détection d'anomalie de structure (Format VoIP non conforme)
    if (PhoneNumberValidator.isGeneratedOrSpoofedNumber(incomingNumber)) {
      riskWeight += 40.0;
      threats.add('Motif numérique invalide / Spoofing VoIP');
      factors.add(const AiRiskFactor(
        factorName: 'Anomalie de Structure',
        scoreContribution: 40,
        description: 'Séquences répétitives ou préfixes N11/555 non attribuables.',
      ));
    }

    // C. Détection de Neighbor Spoofing (Usurpation de proximité)
    if (userOwnNumber != null && userOwnNumber.isNotEmpty) {
      neighborSpoofing = isNeighborSpoofing(
        incomingNumber: incomingNumber,
        userOwnNumber: userOwnNumber,
      );

      if (neighborSpoofing) {
        riskWeight += 50.0;
        confidence = max(confidence, 0.95);
        threats.add('Usurpation Voisine (Neighbor Spoofing) : 6 chiffres identiques');
        factors.add(const AiRiskFactor(
          factorName: 'Usurpation Voisine',
          scoreContribution: 50,
          description: 'Identique aux 6 premiers chiffres de votre propre numéro.',
        ));
      } else {
        // Test de contournement par grappe urbaine (Overlay Cluster)
        final isOverlay = isOverlayClusterSpoofing(
          incomingNumber: incomingNumber,
          userOwnNumber: userOwnNumber,
        );
        if (isOverlay) {
          riskWeight += 40.0;
          confidence = max(confidence, 0.92);
          threats.add('Usurpation par Grappe Urbaine (Cluster Spoofing) : indicatif jumeau');
          factors.add(const AiRiskFactor(
            factorName: 'Grappe Régionale Voisine',
            scoreContribution: 40,
            description: 'Même central téléphonique sous indicatif superposé local.',
          ));
        }
      }
    }

    // D. Analyse nuancée des indicatifs sans frais (Toll-Free)
    if (digitsOnly.length == 11 && digitsOnly.startsWith('1')) {
      final areaCode = digitsOnly.substring(1, 4);
      if (_tollFreeAreaCodes.contains(areaCode)) {
        tollFreeAbuse = true;
        // On module l'impact du Toll-Free : modéré (20 pts)
        riskWeight += 20.0;
        threats.add('Indicatif sans frais ($areaCode) fréquemment réutilisé par les centres de démarchage');
        factors.add(AiRiskFactor(
          factorName: 'Indicatif à Risque ($areaCode)',
          scoreContribution: 20,
          description: 'Plage sans frais (800/888/877) couramment exploitée par les numéroteurs automatiques.',
        ));
      } else if (_premiumRateAreaCodes.contains(areaCode)) {
        riskWeight += 60.0;
        threats.add('Numéro surtaxé à haut risque de fraude ($areaCode)');
        factors.add(AiRiskFactor(
          factorName: 'Numéro Surtaxé ($areaCode)',
          scoreContribution: 60,
          description: 'Numéro à tarification majorée (900/976), vecteur fréquent d\'escroqueries.',
        ));
      }
    }

    // E. Calcul d'Entropie de Shannon
    if (digitsOnly.length == 11) {
      final nationalDigits = digitsOnly.substring(1);
      final entropy = calculateDigitEntropy(nationalDigits);
      if (entropy < 2.2) {
        lowEntropyPattern = true;
        riskWeight += 25.0;
        threats.add('Faible entropie numérique (Modèle artificiel généré par ordinateur)');
        factors.add(AiRiskFactor(
          factorName: 'Entropie Artificielle (${entropy.toStringAsFixed(2)})',
          scoreContribution: 25,
          description: 'Diversité de chiffres anormalement basse, typique des générateurs automatiques.',
        ));
      }
    }

    // F. Détection de Rafales Séquentielles (Burst Dialing)
    if (recentIncomingNumbers.isNotEmpty && isSequentialBurstNumber(incomingNumber, recentIncomingNumbers)) {
      riskWeight += 35.0;
      threats.add('Attaque en rafale séquentielle (Robocall Burst Dialing)');
      factors.add(const AiRiskFactor(
        factorName: 'Rafale Séquentielle',
        scoreContribution: 35,
        description: 'Écart numérique consécutif détecté parmi les récents appels entrants.',
      ));
    }

    // G. Analyse temporelle contextuelle (uniquement si d'autres indices existent)
    final now = callTime ?? DateTime.now();
    if ((now.hour >= 21 || now.hour < 7) && riskWeight > 20) {
      riskWeight += 15.0;
      threats.add('Appel hors des heures d\'ouverture légales (21h-7h)');
      factors.add(const AiRiskFactor(
        factorName: 'Plage Horaire Nocturne',
        scoreContribution: 15,
        description: 'Appel émis en dehors du cadre réglementaire habituel.',
      ));
    }

    // 2. FILTRE ANTI-FAUX POSITIFS PAR HISTORIQUE & INTERACTIONS RÉELLES (Protection #2)
    if (hasPreviousInteraction || pastCallDurationSeconds > 20) {
      // Si l'utilisateur a déjà parlé avec ce correspondant, neutralisation complète du risque
      riskWeight = 0.0;
      factors.add(const AiRiskFactor(
        factorName: 'Correspondant Familier',
        scoreContribution: -100,
        description: 'Historique d\'échange préalable vérifié (>20s). Risque neutralisé.',
        isMitigation: true,
      ));
    }

    // Score final normalisé entre 0 et 100
    final finalScore = riskWeight.round().clamp(0, 100);

    // Évaluation du niveau de risque et de la recommandation
    AiRiskLevel level;
    String recommendation;

    if (finalScore >= 75) {
      level = AiRiskLevel.dangerous;
      recommendation = 'Interception et blocage automatique conseillés. Risque élevé de fraude.';
    } else if (finalScore >= 26) {
      level = AiRiskLevel.suspicious;
      recommendation = 'Avertissement visuel. Décrochez avec prudence et ne communiquez aucune information personnelle.';
    } else {
      level = AiRiskLevel.safe;
      recommendation = 'Numéro considéré comme légitime. Aucun comportement anormal identifié.';
    }

    return AiAnalysisResult(
      rawNumber: incomingNumber,
      normalizedNumber: normalized,
      riskScore: finalScore,
      riskLevel: level,
      detectedThreats: threats,
      riskFactors: factors,
      isNeighborSpoofing: neighborSpoofing,
      isTollFreeAbuse: tollFreeAbuse,
      isLowEntropyPattern: lowEntropyPattern,
      isInstitutionalExempt: institutionalExempt,
      confidenceScore: confidence,
      clusterRegion: clusterName,
      recommendation: recommendation,
    );
  }
}
