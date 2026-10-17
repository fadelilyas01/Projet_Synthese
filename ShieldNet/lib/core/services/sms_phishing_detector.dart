enum PhishingRiskLevel { safe, suspicious, dangerous }

class PhishingAnalysisResult {
  final int riskScore; // 0 à 100
  final PhishingRiskLevel level;
  final String verdictTitle;
  final String verdictDescription;
  final List<String> extractedUrls;
  final List<String> detectedRedFlags;
  final List<String> recommendations;

  const PhishingAnalysisResult({
    required this.riskScore,
    required this.level,
    required this.verdictTitle,
    required this.verdictDescription,
    required this.extractedUrls,
    required this.detectedRedFlags,
    required this.recommendations,
  });
}

class SmsPhishingDetector {
  static final List<String> _urlShorteners = [
    'bit.ly',
    'tinyurl.com',
    'is.gd',
    't.co',
    'cutt.ly',
    'ow.ly',
    'buff.ly',
    'rb.gy',
    'rebrand.ly',
    'shorturl.at',
    'tiny.cc',
  ];

  /// Domaines gouvernementaux et institutionnels nord-américains (Canada / É-U) officiellement vérifiés
  static final Set<String> _verifiedOfficialDomains = {
    // Canada & Québec
    'quebec.ca',
    'gouv.qc.ca',
    'canada.ca',
    'gc.ca',
    'desjardins.com',
    'postescanada.ca',
    'canadapost.ca',
    'canadapost-postescanada.ca',
    'hydroquebec.com',
    'revenuquebec.ca',
    'sq.gouv.qc.ca',
    'rcmp-grc.gc.ca',
    'ramq.gouv.qc.ca',
    'saaq.gouv.qc.ca',
    'ontario.ca',
    'hydroone.com',
    'gov.bc.ca',
    'bchydro.com',
    'alberta.ca',
    // États-Unis
    'usa.gov',
    'irs.gov',
    'usps.com',
    'ssa.gov',
    'fcc.gov',
    'ftc.gov',
    'medicare.gov',
    'dmv.ca.gov',
    'pge.com',
    'dmv.ny.gov',
    'coned.com',
    'texas.gov',
    'myflorida.com',
    'fpl.com',
  };

  /// Marques protégées soumises à la détection de typosquatting et d'usurpation de nom d'hôte
  static const List<String> _protectedBrandKeywords = [
    'desjardins',
    'hydroquebec',
    'interac',
    'postescanada',
    'canadapost',
    'revenuquebec',
    'servicecanada',
    'saaq',
    'serviceontario',
    'icbc',
    'fastrak',
    'ezpass',
    'sunpass',
    'txtag',
    'pge',
    'coned',
    'fpl',
    'hydroone',
    'bchydro',
    'usps',
    'irs',
    'chase',
    'bankofamerica',
    'wellsfargo',
    'citibank',
    'capitalone',
  ];

  static final Map<String, int> _deliveryKeywords = {
    'colis': 20,
    'livraison': 15,
    'chronopost': 25,
    'colissimo': 25,
    'mondial relay': 25,
    'postes canada': 25,
    'canada post': 25,
    'usps': 25,
    'postal service': 25,
    'purolator': 25,
    'ups': 25,
    'fedex': 25,
    'dhl': 25,
    'frais de port': 25,
    'frais de douane': 30,
    'point relais': 15,
    'adresse incorrecte': 25,
  };

  static final Map<String, int> _administrativeKeywords = {
    'revenu quebec': 35,
    'arc': 30,
    'cra': 30,
    'saaq': 35,
    'saaqclic': 35,
    'ramq': 35,
    'service canada': 35,
    'serviceontario': 35,
    'icbc': 35,
    '407 etr': 35,
    'dmv': 35,
    'fastrak': 35,
    'ezpass': 35,
    'e-zpass': 35,
    'sunpass': 35,
    'txtag': 35,
    'peage': 30,
    'toll': 30,
    'irs': 35,
    'internal revenue': 35,
    'social security': 35,
    'ssa': 30,
    'medicare': 35,
    'medicaid': 30,
    'fbi': 35,
    'court warrant': 35,
    'ameli': 35,
    'carte vitale': 35,
    'assurance maladie': 30,
    'impots': 35,
    'impots.gouv': 40,
    'antai': 35,
    'amende': 30,
    'contravention': 30,
    'infraction': 25,
    'remboursement': 20,
    'cpf': 30,
  };

  static final Map<String, int> _bankingKeywords = {
    'interac': 35,
    'virement interac': 35,
    'zelle': 35,
    'venmo': 30,
    'cash app': 30,
    'desjardins': 35,
    'accesd': 35,
    'rbc': 30,
    'td': 25,
    'td canada trust': 35,
    'bmo': 25,
    'cibc': 25,
    'banque nationale': 30,
    'chase': 30,
    'bank of america': 30,
    'wells fargo': 30,
    'citibank': 30,
    'banque': 25,
    'compte bloque': 35,
    'compte suspendu': 35,
    'transaction suspecte': 30,
    'securite': 15,
    'identifiants': 30,
    'mot de passe': 35,
    'carte bancaire': 30,
    'code de confirmation': 25,
  };

  static final Map<String, int> _urgencyKeywords = {
    'urgent': 15,
    'immediat': 15,
    'dans les 24h': 20,
    'derniere relance': 25,
    'action requise': 20,
    'cliquez ici': 20,
    'mettre a jour': 15,
    'coupure': 25,
    'disconnection': 25,
    'interruption': 25,
    'suspension': 25,
  };

  /// Normalise le texte pour la détection insensible aux accents et immunisée contre l'évasion unicode
  static String _normalize(String input) {
    // Suppression des caractères invisibles et séparateurs de contournement (Zero-Width Evasion)
    var str = input.replaceAll(RegExp(r'[\u200B\u200C\u200D\uFEFF\u00AD\u2060]'), '');
    str = str.toLowerCase();
    const withDia = 'àáâãäåèéêëìíîïòóôõöùúûüýñç';
    const withoutDia = 'aaaaaaeeeeiiiiooooouuuuync';
    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    return str;
  }

  /// Convertit les homoglyphes cyrilliques / grecs visuellement identiques vers l'alphabet latin
  static String _canonicalizeHomoglyphs(String text) {
    const homoglyphs = {
      'а': 'a', 'с': 'c', 'е': 'e', 'о': 'o', 'р': 'p', 'х': 'x', 'у': 'y', 'і': 'i', 'ј': 'j', 'ѕ': 's',
    };
    var result = text;
    homoglyphs.forEach((k, v) {
      result = result.replaceAll(k, v);
    });
    return result;
  }

  /// Calcule la distance de Levenshtein entre deux chaînes
  static int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    final List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    final List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        final cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce((a, b) => a < b ? a : b);
      }
      for (int j = 0; j <= t.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v0[t.length];
  }

  /// Extrait l'hôte d'une URL brute
  static String? _extractHost(String rawUrl) {
    try {
      var uriStr = rawUrl.trim().replaceAll(RegExp(r'[\.,;:!?\)]+$'), '');
      if (!uriStr.startsWith('http://') && !uriStr.startsWith('https://')) {
        uriStr = 'https://$uriStr';
      }
      // Regex extraction to preserve non-ASCII / homoglyph characters that Dart Uri.parse would reject
      final hostMatch = RegExp(r'^https?:\/\/([^\/\s:\?#]+)', caseSensitive: false).firstMatch(uriStr);
      if (hostMatch != null) {
        return hostMatch.group(1)!.toLowerCase().replaceAll(RegExp(r'\.+$'), '');
      }
      final uri = Uri.parse(uriStr);
      return uri.host.toLowerCase().replaceAll(RegExp(r'\.+$'), '');
    } catch (_) {
      return null;
    }
  }

  /// Vérifie si un hôte appartient à un domaine institutionnel officiel certifié
  static bool _isVerifiedDomain(String host) {
    for (final domain in _verifiedOfficialDomains) {
      if (host == domain || host.endsWith('.$domain')) {
        return true;
      }
    }
    return false;
  }

  /// Détecte le typosquatting ou l'usurpation de marque dans un nom d'hôte
  static String? _detectTyposquatting(String host, {bool isEn = false}) {
    if (_isVerifiedDomain(host)) {
      return null;
    }

    // Normalisation des homoglyphes (ex: cyrillique 'а' ressemblant au latin 'a')
    final canonicalHost = _canonicalizeHomoglyphs(host);
    final hostClean = canonicalHost.replaceAll(RegExp(r'\.(com|ca|org|net|xyz|top|info|site|online|app)$'), '');
    final tokens = hostClean.split(RegExp(r'[\.\-]'));

    for (final brand in _protectedBrandKeywords) {
      // 1. Usurpation directe par sous-domaine ou nom composé frauduleux
      if (hostClean.contains(brand)) {
        return isEn
            ? 'The link imitates "$brand" but does not lead to their real, verified website.'
            : 'Le lien utilise le nom de "$brand" mais ne mène pas à leur vrai site officiel.';
      }

      // 2. Typosquatting par substitution typographique (Levenshtein distance 1 ou 2)
      for (final token in tokens) {
        if (token.length >= 5 && (token.length - brand.length).abs() <= 2) {
          final dist = _levenshtein(token, brand);
          if (dist > 0 && dist <= 2) {
            return isEn
                ? 'Deceptive link: "$token" imitates the official brand "$brand" with a slight spelling trick.'
                : 'Lien trompeur : "$token" imite le vrai site de "$brand" avec une légère faute d\'orthographe volontaire.';
          }
        }
      }
    }
    return null;
  }

  /// Analyse le contenu d'un SMS ou message
  static PhishingAnalysisResult analyze(String message, {String languageCode = 'fr'}) {
    final isEn = languageCode == 'en';
    if (message.trim().isEmpty) {
      return PhishingAnalysisResult(
        riskScore: 0,
        level: PhishingRiskLevel.safe,
        verdictTitle: isEn ? 'Empty Message' : 'Texte vide',
        verdictDescription: isEn
            ? 'Please enter or paste a message to analyze.'
            : 'Veuillez saisir ou coller un message à analyser.',
        extractedUrls: const [],
        detectedRedFlags: const [],
        recommendations: const [],
      );
    }

    final normalized = _normalize(message);

    // Extraction heuristique des liens (expression régulière non ambiguë immunisée ReDoS)
    final urlRegex = RegExp(
      r'(https?:\/\/[^\s]+|(?:www\.)[^\s]+|(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(?:\/[^\s]*)?)',
      caseSensitive: false,
    );
    final rawMatches = urlRegex.allMatches(message).map((m) => m.group(0)!).toList();
    final urls = rawMatches
        .map((u) => u.replaceAll(RegExp(r'[\.,;:!?\)]+$'), ''))
        .where((u) => u.contains('.'))
        .toList();

    // 1. Classification transactionnelle 2FA/OTP (Protection contre les faux positifs)
    final isOtpPattern = RegExp(r'\b\d{4,8}\b').hasMatch(message) &&
        (normalized.contains('code') || normalized.contains('otp') || normalized.contains('usage unique') || normalized.contains('mot de passe')) &&
        (normalized.contains('confirmation') ||
            normalized.contains('verification') ||
            normalized.contains('securite') ||
            normalized.contains('temporaire') ||
            normalized.contains('ne partagez') ||
            normalized.contains('ne transmettez') ||
            normalized.contains('valide') ||
            normalized.contains('expire'));

    final hasExtortionOrThreat = normalized.contains('carte cadeau') ||
        normalized.contains('bitcoin') ||
        normalized.contains('mandat') ||
        normalized.contains('arrestation') ||
        normalized.contains('amende') ||
        normalized.contains('bloque');

    if (urls.isEmpty && isOtpPattern && !hasExtortionOrThreat) {
      return PhishingAnalysisResult(
        riskScore: 0,
        level: PhishingRiskLevel.safe,
        verdictTitle: isEn
            ? "Legitimate Authentication Code (2FA/OTP)"
            : "Code d'Authentification Légitime (2FA/OTP)",
        verdictDescription: isEn
            ? 'This message is a temporary one-time security code without suspicious links.'
            : 'Ce message correspond à un code temporaire à usage unique sans lien suspect.',
        extractedUrls: const [],
        detectedRedFlags: const [],
        recommendations: isEn
            ? const [
                'Never disclose this security code to any third party.',
                'If you did not initiate this request, secure your accounts immediately.',
              ]
            : const [
                'Ne communiquez jamais ce code de sécurité à un tiers.',
                'Si vous n\'êtes pas à l\'origine de cette demande, sécurisez vos accès.',
              ],
      );
    }

    int totalRisk = 0;
    final redFlags = <String>[];
    final recommendations = <String>[];

    bool hasShortener = false;
    bool hasIpUrl = false;
    bool hasSuspiciousTld = false;
    bool hasTyposquatting = false;
    int verifiedUrlCount = 0;

    for (final url in urls) {
      final lowUrl = url.toLowerCase();
      final host = _extractHost(url);

      if (host != null && _isVerifiedDomain(host)) {
        verifiedUrlCount++;
        continue;
      }

      // Détection de Typosquatting / Usurpation de marque
      if (host != null) {
        final typosquatDesc = _detectTyposquatting(host, isEn: isEn);
        if (typosquatDesc != null) {
          hasTyposquatting = true;
          totalRisk += 55;
          redFlags.add(typosquatDesc);
        }
      }

      // Repérage des services de redirection / raccourcissement
      for (final shortener in _urlShorteners) {
        if (lowUrl.contains(shortener)) {
          hasShortener = true;
          totalRisk += 35;
          redFlags.add(isEn
              ? 'Hidden destination: uses a link shortener ($shortener) to disguise where it leads.'
              : 'Lien masqué : utilise un raccourcisseur ($shortener) pour cacher la véritable destination.');
          break;
        }
      }

      // Adresses IPv4 directes (hôtes éphémères)
      if (RegExp(r'https?:\/\/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}').hasMatch(lowUrl)) {
        hasIpUrl = true;
        totalRisk += 45;
        redFlags.add(isEn
            ? 'Suspicious link: uses numbers instead of a legitimate website address.'
            : 'Lien suspect : utilise une suite de chiffres au lieu d\'un vrai nom de site web.');
      }

      // Extensions de complaisance fréquemment abusées
      final suspiciousExtensions = ['.xyz', '.top', '.club', '.buzz', '.rest', '.sbs', '.cfd', '.click', '.tk', '.ga', '.ml'];
      for (final ext in suspiciousExtensions) {
        if (lowUrl.contains(ext)) {
          hasSuspiciousTld = true;
          totalRisk += 30;
          redFlags.add(isEn
              ? 'Unusual website ending ($ext), commonly used to create short-lived scam traps.'
              : 'Fin d\'adresse web inhabituelle ($ext), très souvent utilisée pour créer des faux sites pièges.');
          break;
        }
      }

      // Usurpation par nom de domaine internationalisé (Punycode xn--)
      if (host != null && (host.startsWith('xn--') || host.contains('.xn--'))) {
        totalRisk += 45;
        redFlags.add(isEn
            ? 'Deceptive website address: disguises characters to mimic a legitimate site.'
            : 'Adresse web trompeuse : imite un vrai site avec des caractères déguisés.');
      }

      // Piège de l'arobase (@) dans l'URL pour tromper sur le domaine hôte
      if (lowUrl.contains('@') && (lowUrl.startsWith('http://') || lowUrl.startsWith('https://'))) {
        totalRisk += 50;
        redFlags.add(isEn
            ? 'Deceptive "@" trick in URL: disguises the destination site by preceding it with misleading text.'
            : 'Piège de l\'arobase (@) dans l\'URL : trompe l\'utilisateur sur le réel site de destination.');
      }
    }

    // Indices de colis / fausse livraison
    for (final entry in _deliveryKeywords.entries) {
      if (normalized.contains(entry.key)) {
        totalRisk += entry.value;
        redFlags.add(isEn
            ? 'Package / delivery scam pattern: "${entry.key}".'
            : 'Mention d\'arnaque au colis / livraison : "${entry.key}".');
      }
    }

    // Indices d'usurpation institutionnelle ou fiscale
    for (final entry in _administrativeKeywords.entries) {
      if (normalized.contains(entry.key)) {
        totalRisk += entry.value;
        redFlags.add(isEn
            ? 'Official agency impersonation: "${entry.key}".'
            : 'Usurpation d\'organisme officiel : "${entry.key}".');
      }
    }

    // Indices de sécurité bancaire et capture d'identifiants
    for (final entry in _bankingKeywords.entries) {
      if (normalized.contains(entry.key)) {
        totalRisk += entry.value;
        redFlags.add(isEn
            ? 'Sensitive banking or security request: "${entry.key}".'
            : 'Demande sensible de sécurité ou bancaire : "${entry.key}".');
      }
    }

    // Formulation incitant à l'urgence immédiate
    for (final entry in _urgencyKeywords.entries) {
      if (normalized.contains(entry.key)) {
        totalRisk += entry.value;
        redFlags.add(isEn
            ? 'High-urgency pressure tactic: "${entry.key}".'
            : 'Incitation pressante à l\'action rapide : "${entry.key}".');
      }
    }

    // Majoration si un lien externe non vérifié est associé à au moins un signal suspect
    final hasUnverifiedUrls = (urls.length - verifiedUrlCount) > 0;
    if (hasUnverifiedUrls && redFlags.isNotEmpty) {
      totalRisk += 20;
    }

    // Atténuation si les seuls liens sont des domaines officiels vérifiés
    if (urls.isNotEmpty && !hasUnverifiedUrls && !hasTyposquatting) {
      totalRisk = (totalRisk * 0.25).round();
      redFlags.removeWhere((flag) =>
          flag.contains('Usurpation d\'organisme officiel') ||
          flag.contains('Official agency impersonation'));
    }

    // Calcul du score plafonné
    final finalScore = totalRisk.clamp(0, 100);

    PhishingRiskLevel level;
    String verdictTitle;
    String verdictDesc;

    final bool hasCriticalRisk = finalScore >= 65 ||
        hasIpUrl ||
        hasTyposquatting ||
        (hasShortener && urls.isNotEmpty && redFlags.length >= 2) ||
        hasSuspiciousTld;

    if (hasCriticalRisk) {
      level = PhishingRiskLevel.dangerous;
      verdictTitle = isEn ? 'High-Risk Phishing Detected' : 'Hameçonnage Très Probable';
      verdictDesc = isEn
          ? 'This message shows clear indicators of an active scam or credential theft attempt.'
          : 'Ce message présente tous les indicateurs d\'une tentative d\'escroquerie ou de vol d\'identifiants.';
      if (isEn) {
        recommendations.add('Do not click any link in this message under any circumstances.');
        recommendations.add('Never disclose your banking details or passwords via text message.');
        recommendations.add('Block the sender immediately and delete the message.');
      } else {
        recommendations.add('Ne cliquez surtout sur aucun lien présent dans ce message.');
        recommendations.add('Ne communiquez jamais vos coordonnées bancaires ou mots de passe par SMS.');
        recommendations.add('Bloquez l\'expéditeur et supprimez le message.');
      }
    } else if (finalScore >= 30 || hasUnverifiedUrls) {
      level = PhishingRiskLevel.suspicious;
      verdictTitle = isEn ? 'Suspicious Message' : 'Message Suspect';
      verdictDesc = isEn
          ? 'This message contains unusual wording or unverified links warranting heightened vigilance.'
          : 'Ce message contient des formulations ou des liens inhabituels justifiant une vigilance accrue.';
      if (isEn) {
        recommendations.add('Verify directly via the official agency app or website without opening the received link.');
        recommendations.add('Beware of unexpected requests for payment or address verification.');
      } else {
        recommendations.add('Vérifiez directement sur le site ou l\'application officielle de l\'organisme sans utiliser le lien reçu.');
        recommendations.add('Prenez garde aux demandes de paiement ou de mise à jour d\'adresse.');
      }
    } else {
      level = PhishingRiskLevel.safe;
      if (isEn) {
        verdictTitle = verifiedUrlCount > 0 ? 'Verified Official Message' : 'Safe Message';
        verdictDesc = verifiedUrlCount > 0
            ? 'This message originates from a recognized official domain with no indicators of fraud.'
            : 'No major scam or phishing indicators were detected in this message.';
        recommendations.add('Stay cautious if an unknown contact asks for money or sensitive information.');
      } else {
        verdictTitle = verifiedUrlCount > 0 ? 'Message Officiel Vérifié' : 'Message Sécuritaire';
        verdictDesc = verifiedUrlCount > 0
            ? 'Ce message provient d\'un domaine officiel reconnu et ne présente aucun indicateur de fraude.'
            : 'Aucun indicateur majeur d\'escroquerie ou de hameçonnage n\'a été détecté dans ce message.';
        recommendations.add('Restez vigilant si un correspondant inconnu vous demande de l\'argent ou des informations privées.');
      }
    }

    return PhishingAnalysisResult(
      riskScore: finalScore,
      level: level,
      verdictTitle: verdictTitle,
      verdictDescription: verdictDesc,
      extractedUrls: urls,
      detectedRedFlags: redFlags.toSet().toList(),
      recommendations: recommendations,
    );
  }
}
