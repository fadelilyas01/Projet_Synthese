import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../security/crypto_utils.dart';

/// Service de gestion du Mode Démonstration (Jury / Présentation)
/// Injecte des données réalistes (utilisateurs, numéros bloqués, signalements,
/// historique d'appels et statistiques) sans impacter la production.
class DemoModeService {
  DemoModeService._internal();
  static final DemoModeService instance = DemoModeService._internal();

  static const String _kDemoModeKey = 'shieldnet_demo_mode_active';

  final ValueNotifier<bool> isDemoActiveNotifier = ValueNotifier<bool>(false);

  bool get isDemoActive => isDemoActiveNotifier.value;

  /// Initialise l'état du mode démo au démarrage
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    isDemoActiveNotifier.value = prefs.getBool(_kDemoModeKey) ?? false;
  }

  /// Active le mode démo et peuple le cache local avec un jeu de données réaliste
  Future<void> enableDemoMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDemoModeKey, true);
    isDemoActiveNotifier.value = true;

    await _seedDemoDatabase();
  }

  /// Désactive le mode démo et nettoie les données fictives
  Future<void> disableDemoMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDemoModeKey, false);
    isDemoActiveNotifier.value = false;

    await _cleanDemoDatabase();
  }

  /// Scénarios d'appels entrants pour la démonstration interactive devant le jury
  static List<Map<String, dynamic>> getDemoScenarios({bool isEn = false}) {
    if (isEn) {
      return const [
        {
          'id': 'cra_scam',
          'caller_name': 'Revenue Agency (Impostor)',
          'phone_number': '+1 514 999 1234',
          'category': 'CRA_IMPOSTOR',
          'risk_score': 96,
          'is_blocked': true,
          'expected_action': 'REJECT',
          'reason': 'Arrest warrant tax scam (Gift cards / e-Transfer)',
          'processing_time_ms': 2.4,
        },
        {
          'id': 'neighbor_spoofing',
          'caller_name': 'Spoofed Local Number',
          'phone_number': '+1 514 840 9988',
          'category': 'NEIGHBOR_SPOOFING',
          'risk_score': 88,
          'is_blocked': true,
          'expected_action': 'REJECT',
          'reason': 'Regional overlay cluster spoofing (Same prefix)',
          'processing_time_ms': 2.7,
        },
        {
          'id': 'hospital_legit',
          'caller_name': 'MUHC Montreal General Hospital',
          'phone_number': '+1 514 934 1934',
          'category': 'HEALTHCARE',
          'risk_score': 0,
          'is_blocked': false,
          'expected_action': 'ALLOW',
          'reason': 'Guaranteed institutional immunity (Healthcare services)',
          'processing_time_ms': 1.8,
        },
        {
          'id': 'info_sante_811',
          'caller_name': 'Info-Health / 811 Emergency',
          'phone_number': '811',
          'category': 'EMERGENCY',
          'risk_score': 0,
          'is_blocked': false,
          'expected_action': 'ALLOW',
          'reason': 'Inviolable national emergency service (811, 911, 988)',
          'processing_time_ms': 1.2,
        },
        {
          'id': 'delivery_phish',
          'caller_name': 'Fake Postal Delivery Notice',
          'phone_number': '+1 438 888 5678',
          'category': 'DELIVERY_SCAM',
          'risk_score': 91,
          'is_blocked': true,
          'expected_action': 'REJECT',
          'reason': 'Phishing SMS package held (\$2.35 customs fee)',
          'processing_time_ms': 2.5,
        },
      ];
    }
    return const [
      {
        'id': 'cra_scam',
        'caller_name': 'Agence du Revenu (Imposteur)',
        'phone_number': '+1 514 999 1234',
        'category': 'CRA_IMPOSTOR',
        'risk_score': 96,
        'is_blocked': true,
        'expected_action': 'REJECT',
        'reason': 'Arnaque mandat d\'arrêt impôt impayé (Interac)',
        'processing_time_ms': 2.4,
      },
      {
        'id': 'neighbor_spoofing',
        'caller_name': 'Numéro Local Usurpé (Spoofing)',
        'phone_number': '+1 514 840 9988',
        'category': 'NEIGHBOR_SPOOFING',
        'risk_score': 88,
        'is_blocked': true,
        'expected_action': 'REJECT',
        'reason': 'Grappe d\'usurpation régionale superposée (Overlay Cluster)',
        'processing_time_ms': 2.7,
      },
      {
        'id': 'hospital_legit',
        'caller_name': 'CUSM Hôpital Général de Montréal',
        'phone_number': '+1 514 934 1934',
        'category': 'HEALTHCARE',
        'risk_score': 0,
        'is_blocked': false,
        'expected_action': 'ALLOW',
        'reason': 'Immunité institutionnelle garantie (Services de santé)',
        'processing_time_ms': 1.8,
      },
      {
        'id': 'info_sante_811',
        'caller_name': 'Info-Santé / Urgence Québec',
        'phone_number': '811',
        'category': 'EMERGENCY',
        'risk_score': 0,
        'is_blocked': false,
        'expected_action': 'ALLOW',
        'reason': 'Service d\'urgence public inviolable (811, 911, 988)',
        'processing_time_ms': 1.2,
      },
      {
        'id': 'delivery_phish',
        'caller_name': 'Faux Avis Postes Canada',
        'phone_number': '+1 438 888 5678',
        'category': 'DELIVERY_SCAM',
        'risk_score': 91,
        'is_blocked': true,
        'expected_action': 'REJECT',
        'reason': 'SMS hameçonnage colis bloqué (frais de 2.35\$)',
        'processing_time_ms': 2.5,
      },
    ];
  }

  static List<Map<String, dynamic>> get demoScenarios => getDemoScenarios(isEn: false);

  /// Exemples de SMS frauduleux réalistes calibrés selon la province/état et la langue
  static List<Map<String, dynamic>> getDemoSmsSamples({
    bool isEn = false,
    String country = 'CA',
    String provinceOrState = 'QC',
  }) {
    final c = country.trim().toUpperCase();
    final p = provinceOrState.trim().toUpperCase();

    if (c == 'CA') {
      if (p == 'ON') {
        return _getOntarioSmsSamples(isEn);
      } else if (p == 'BC') {
        return _getBritishColumbiaSmsSamples(isEn);
      } else if (p == 'AB' || p == 'MB' || p == 'SK' || p == 'NS' || p == 'NB' || p == 'NL' || p == 'PE' || p == 'NT' || p == 'YT' || p == 'NU') {
        return _getOtherCanadaSmsSamples(isEn, province: p);
      }
      return _getQuebecSmsSamples(isEn);
    } else {
      // États-Unis
      if (p == 'CA') {
        return _getCaliforniaSmsSamples(isEn);
      } else if (p == 'NY') {
        return _getNewYorkSmsSamples(isEn);
      } else if (p == 'TX') {
        return _getTexasSmsSamples(isEn);
      } else if (p == 'FL') {
        return _getFloridaSmsSamples(isEn);
      }
      return _getGenericUsSmsSamples(isEn, stateCode: p);
    }
  }

  // --- Scénarios Régionaux Canada ---

  static List<Map<String, dynamic>> _getQuebecSmsSamples(bool isEn) {
    if (isEn) {
      return const [
        {
          'title': 'Fake SAAQclic Licence Refund',
          'category': 'SAAQ Phishing Impersonation',
          'text': 'SAAQclic: An overpayment refund of \$142.80 CAD for your driver licence is ready. Accept your transfer before midnight: https://saaqclic-remboursement-portail.info/login',
          'risk': 'DANGEROUS',
          'score': 96,
          'dangerous_keywords': ['SAAQclic', 'overpayment refund', 'before midnight'],
          'suspect_links': ['https://saaqclic-remboursement-portail.info/login'],
        },
        {
          'title': 'Fake Revenu Québec Refund',
          'category': 'Tax Refund Phishing',
          'text': 'Revenu Québec: A tax credit refund of \$485.20 CAD is pending. Deposit via secure Interac e-Transfer before October 15: http://rq-remboursement-interac.top/claim',
          'risk': 'DANGEROUS',
          'score': 95,
          'dangerous_keywords': ['refund', 'Interac transfer', 'before October 15'],
          'suspect_links': ['http://rq-remboursement-interac.top/claim'],
        },
        {
          'title': 'Desjardins AccèsD Security Alert',
          'category': 'Banking Impersonation',
          'text': 'Desjardins Alert: AccèsD temporarily locked due to suspicious activity in Montreal. Verify your identity now: https://accesd-desjardins-auth.net/login',
          'risk': 'DANGEROUS',
          'score': 98,
          'dangerous_keywords': ['AccèsD', 'temporarily locked', 'suspicious activity'],
          'suspect_links': ['https://accesd-desjardins-auth.net/login'],
        },
        {
          'title': 'Canada Post Held Parcel (Montreal)',
          'category': 'Delivery Fee Scam',
          'text': 'Canada Post: Parcel #CA-902188 is held at the Montreal sorting facility. \$2.45 handling fee required for delivery: https://postescan-douane-frais.xyz/suivi',
          'risk': 'DANGEROUS',
          'score': 92,
          'dangerous_keywords': ['parcel', 'sorting facility', 'handling fee'],
          'suspect_links': ['https://postescan-douane-frais.xyz/suivi'],
        },
        {
          'title': 'Hydro-Québec Bill Notice (Safe)',
          'category': 'Legitimate Utility Notice',
          'text': 'Hydro-Québec: Your September monthly bill is ready in your official Customer Space at https://www.hydroquebec.com. No payment required by SMS.',
          'risk': 'SAFE',
          'score': 5,
          'dangerous_keywords': [],
          'suspect_links': [],
        },
      ];
    }
    return const [
      {
        'title': 'Faux Remboursement SAAQclic',
        'category': 'SAAQ Phishing Impersonation',
        'text': 'SAAQclic : Un trop-perçu de 142.80\$ pour le renouvellement de votre permis est disponible. Réclamez votre virement avant minuit : https://saaqclic-remboursement-portail.info/login',
        'risk': 'DANGEROUS',
        'score': 96,
        'dangerous_keywords': ['SAAQclic', 'trop-perçu', 'virement', 'avant minuit'],
        'suspect_links': ['https://saaqclic-remboursement-portail.info/login'],
      },
      {
        'title': 'Faux Remboursement Revenu Québec',
        'category': 'Tax Refund Phishing',
        'text': 'Revenu Québec : Un remboursement de 485.20\$ CAD vous attend. Veuillez accepter votre virement Interac sécurisé avant le 15 octobre : http://rq-remboursement-interac.top/claim',
        'risk': 'DANGEROUS',
        'score': 95,
        'dangerous_keywords': ['remboursement', 'virement Interac', 'avant le 15 octobre'],
        'suspect_links': ['http://rq-remboursement-interac.top/claim'],
      },
      {
        'title': 'Alerte Sécurité Desjardins AccèsD',
        'category': 'Banking Impersonation',
        'text': 'Alerte Desjardins : AccèsD temporairement verrouillé suite à une tentative suspecte à Montréal. Réactivez votre compte sécurisé ici : https://accesd-desjardins-auth.net/login',
        'risk': 'DANGEROUS',
        'score': 98,
        'dangerous_keywords': ['AccèsD', 'temporairement verrouillé', 'tentative suspecte'],
        'suspect_links': ['https://accesd-desjardins-auth.net/login'],
      },
      {
        'title': 'Colis Bloqué Postes Canada (Montréal)',
        'category': 'Delivery Fee Scam',
        'text': 'Postes Canada : Votre colis #CA-902188 est en attente au centre de tri de Montréal. Frais de douane impayés de 2.45\$. Réglez immédiatement pour livraison : https://postescan-douane-frais.xyz/suivi',
        'risk': 'DANGEROUS',
        'score': 92,
        'dangerous_keywords': ['colis', 'centre de tri', 'frais de douane', 'immédiatement'],
        'suspect_links': ['https://postescan-douane-frais.xyz/suivi'],
      },
      {
        'title': 'Rappel de Facture Hydro-Québec (Légitime)',
        'category': 'Legitimate Utility Notice',
        'text': 'Hydro-Québec : Votre facture mensuelle de septembre est disponible dans votre Espace client officiel sur https://www.hydroquebec.com. Aucun paiement requis par SMS.',
        'risk': 'SAFE',
        'score': 5,
        'dangerous_keywords': [],
        'suspect_links': [],
      },
    ];
  }

  static List<Map<String, dynamic>> _getOntarioSmsSamples(bool isEn) {
    if (isEn) {
      return const [
        {
          'title': 'Fake 407 ETR Highway Toll Notice',
          'category': 'Toll Evasion Phishing',
          'text': '407 ETR Notice: Outstanding toll charge of \$42.75 detected for vehicle on Highway 407. Avoid court penalty and licence plate suspension: https://407etr-ontario-tollsettle.org/pay',
          'risk': 'DANGEROUS',
          'score': 96,
          'dangerous_keywords': ['407 ETR', 'toll charge', 'licence plate suspension', 'Highway 407'],
          'suspect_links': ['https://407etr-ontario-tollsettle.org/pay'],
        },
        {
          'title': 'Fake ServiceOntario Plate Renewal',
          'category': 'Government Impersonation',
          'text': 'ServiceOntario Alert: Your vehicle registration sticker has expired. Immediate renewal required to prevent police fines: https://serviceontario-licence-portal.cc/renew',
          'risk': 'DANGEROUS',
          'score': 94,
          'dangerous_keywords': ['ServiceOntario', 'vehicle registration', 'immediate renewal', 'fines'],
          'suspect_links': ['https://serviceontario-licence-portal.cc/renew'],
        },
        {
          'title': 'CRA Carbon Rebate Interac Refund',
          'category': 'Tax Refund Phishing',
          'text': 'Canada Revenue Agency (CRA): You have an uncashed carbon rebate refund of \$380.00 CAD. Deposit your e-Transfer here: https://cra-arc-rebate-deposit.com/claim',
          'risk': 'DANGEROUS',
          'score': 96,
          'dangerous_keywords': ['Canada Revenue Agency', 'CRA', 'rebate refund', 'e-Transfer'],
          'suspect_links': ['https://cra-arc-rebate-deposit.com/claim'],
        },
        {
          'title': 'TD Canada Trust Security Alert',
          'category': 'Banking Impersonation',
          'text': 'TD Canada Trust: Unusual login detected from Toronto ON. EasyWeb banking is restricted. Restore access: https://tdcanadatrust-easyweb-verify.net/auth',
          'risk': 'DANGEROUS',
          'score': 98,
          'dangerous_keywords': ['TD Canada Trust', 'EasyWeb', 'restricted', 'Unusual login'],
          'suspect_links': ['https://tdcanadatrust-easyweb-verify.net/auth'],
        },
        {
          'title': 'Hydro One Statement (Safe)',
          'category': 'Legitimate Utility Notice',
          'text': 'Hydro One: Your monthly electricity statement is ready. Review your account securely at https://www.hydroone.com. Hydro One never demands immediate payment via SMS.',
          'risk': 'SAFE',
          'score': 5,
          'dangerous_keywords': [],
          'suspect_links': [],
        },
      ];
    }
    return const [
      {
        'title': 'Fausse Infraction Autoroute 407 ETR',
        'category': 'Toll Evasion Phishing',
        'text': 'Avis 407 ETR : Péage impayé de 42.75\$ détecté sur l\'Autoroute 407. Évitez la suspension de votre permis et des frais de cour : https://407etr-ontario-tollsettle.org/pay',
        'risk': 'DANGEROUS',
        'score': 96,
        'dangerous_keywords': ['407 ETR', 'péage', 'suspension', 'Autoroute 407'],
        'suspect_links': ['https://407etr-ontario-tollsettle.org/pay'],
      },
      {
        'title': 'Faux Renouvellement ServiceOntario',
        'category': 'Government Impersonation',
        'text': 'ServiceOntario : L\'immatriculation de votre véhicule a expiré. Régularisez votre dossier immédiatement en ligne : https://serviceontario-licence-portal.cc/renew',
        'risk': 'DANGEROUS',
        'score': 94,
        'dangerous_keywords': ['ServiceOntario', 'immatriculation', 'immédiatement'],
        'suspect_links': ['https://serviceontario-licence-portal.cc/renew'],
      },
      {
        'title': 'Faux Remboursement ARC Interac',
        'category': 'Tax Refund Phishing',
        'text': 'Agence du Revenu du Canada (ARC) : Un remboursement de taxe carbone de 380.00\$ vous attend. Déposez votre virement : https://cra-arc-rebate-deposit.com/claim',
        'risk': 'DANGEROUS',
        'score': 96,
        'dangerous_keywords': ['ARC', 'remboursement', 'taxe carbone', 'virement'],
        'suspect_links': ['https://cra-arc-rebate-deposit.com/claim'],
      },
      {
        'title': 'Alerte Sécurité TD Canada Trust',
        'category': 'Banking Impersonation',
        'text': 'TD Canada Trust : Activité suspecte détectée à Toronto. Accès EasyWeb restreint. Confirmez votre identité : https://tdcanadatrust-easyweb-verify.net/auth',
        'risk': 'DANGEROUS',
        'score': 98,
        'dangerous_keywords': ['TD Canada Trust', 'EasyWeb', 'restreint', 'Activité suspecte'],
        'suspect_links': ['https://tdcanadatrust-easyweb-verify.net/auth'],
      },
      {
        'title': 'Facture Hydro One (Légitime)',
        'category': 'Legitimate Utility Notice',
        'text': 'Hydro One : Votre relevé mensuel d\'électricité est prêt. Consultez-le sur le portail officiel https://www.hydroone.com. Aucun paiement direct requis par SMS.',
        'risk': 'SAFE',
        'score': 5,
        'dangerous_keywords': [],
        'suspect_links': [],
      },
    ];
  }

  static List<Map<String, dynamic>> _getBritishColumbiaSmsSamples(bool isEn) {
    if (isEn) {
      return const [
        {
          'title': 'Fake ICBC Fuel Relief Rebate',
          'category': 'Government Impersonation',
          'text': 'ICBC Alert: Your relief rebate cheque of \$110.00 CAD was returned. Accept your Interac e-Transfer directly: https://icbc-rebates-britishcolumbia.top/direct',
          'risk': 'DANGEROUS',
          'score': 95,
          'dangerous_keywords': ['ICBC', 'rebate cheque', 'Interac e-Transfer'],
          'suspect_links': ['https://icbc-rebates-britishcolumbia.top/direct'],
        },
        {
          'title': 'BC Hydro Urgent Power Disconnection',
          'category': 'Utility Scam',
          'text': 'BC Hydro Alert: Final overdue disconnection notice for Vancouver address. Pay \$89.40 within 45 minutes to avoid power cut: https://bchydro-power-emergency.com/pay',
          'risk': 'DANGEROUS',
          'score': 97,
          'dangerous_keywords': ['BC Hydro', 'disconnection', 'power cut', 'within 45 minutes'],
          'suspect_links': ['https://bchydro-power-emergency.com/pay'],
        },
        {
          'title': 'CRA Interac GST Refund',
          'category': 'Tax Refund Phishing',
          'text': 'CRA: Your GST/HST credit refund of \$275.50 CAD is awaiting deposit. Complete verification: https://cra-arc-rebate-deposit.com/claim',
          'risk': 'DANGEROUS',
          'score': 95,
          'dangerous_keywords': ['CRA', 'credit refund', 'awaiting deposit'],
          'suspect_links': ['https://cra-arc-rebate-deposit.com/claim'],
        },
        {
          'title': 'Canada Post Held Parcel (Richmond Depot)',
          'category': 'Delivery Fee Scam',
          'text': 'Canada Post: Parcel #BC-490211 is held at the Richmond sorting depot. \$2.45 handling fee required for delivery: https://postescan-douane-frais.xyz/suivi',
          'risk': 'DANGEROUS',
          'score': 92,
          'dangerous_keywords': ['parcel', 'sorting depot', 'handling fee'],
          'suspect_links': ['https://postescan-douane-frais.xyz/suivi'],
        },
        {
          'title': 'BC Hydro Statement (Safe)',
          'category': 'Legitimate Utility Notice',
          'text': 'BC Hydro: Your monthly power bill is available in MyHydro at https://www.bchydro.com. BC Hydro never cuts power without prior written notice.',
          'risk': 'SAFE',
          'score': 5,
          'dangerous_keywords': [],
          'suspect_links': [],
        },
      ];
    }
    return const [
      {
        'title': 'Faux Remboursement ICBC',
        'category': 'Government Impersonation',
        'text': 'ICBC : Votre chèque de remboursement de carburant de 110.00\$ CAD est en attente. Acceptez votre virement Interac officiel : https://icbc-rebates-britishcolumbia.top/direct',
        'risk': 'DANGEROUS',
        'score': 95,
        'dangerous_keywords': ['ICBC', 'remboursement', 'virement Interac'],
        'suspect_links': ['https://icbc-rebates-britishcolumbia.top/direct'],
      },
      {
        'title': 'Menace de Coupure BC Hydro',
        'category': 'Utility Scam',
        'text': 'BC Hydro : Avis final d\'interruption d\'électricité à Vancouver pour facture impayée de 89.40\$. Payez sous 45 min pour éviter la coupure : https://bchydro-power-emergency.com/pay',
        'risk': 'DANGEROUS',
        'score': 97,
        'dangerous_keywords': ['BC Hydro', 'interruption', 'coupure', 'sous 45 min'],
        'suspect_links': ['https://bchydro-power-emergency.com/pay'],
      },
      {
        'title': 'Faux Remboursement TPS/TVH ARC',
        'category': 'Tax Refund Phishing',
        'text': 'ARC : Votre crédit de taxe TPS/TVH de 275.50\$ CAD vous attend. Déposez votre virement : https://cra-arc-rebate-deposit.com/claim',
        'risk': 'DANGEROUS',
        'score': 95,
        'dangerous_keywords': ['ARC', 'crédit de taxe', 'virement'],
        'suspect_links': ['https://cra-arc-rebate-deposit.com/claim'],
      },
      {
        'title': 'Colis Bloqué Postes Canada (Richmond)',
        'category': 'Delivery Fee Scam',
        'text': 'Postes Canada : Colis #BC-490211 retenu au centre de tri de Richmond. Frais de douane impayés de 2.45\$ : https://postescan-douane-frais.xyz/suivi',
        'risk': 'DANGEROUS',
        'score': 92,
        'dangerous_keywords': ['colis', 'centre de tri', 'frais de douane'],
        'suspect_links': ['https://postescan-douane-frais.xyz/suivi'],
      },
      {
        'title': 'Facture Officielle BC Hydro (Légitime)',
        'category': 'Legitimate Utility Notice',
        'text': 'BC Hydro : Votre relevé mensuel est accessible sur https://www.bchydro.com. BC Hydro n\'exige aucun paiement urgent par texto.',
        'risk': 'SAFE',
        'score': 5,
        'dangerous_keywords': [],
        'suspect_links': [],
      },
    ];
  }

  static List<Map<String, dynamic>> _getOtherCanadaSmsSamples(bool isEn, {required String province}) {
    if (isEn) {
      return [
        {
          'title': 'Fake Traffic Radar Fine ($province)',
          'category': 'Government Impersonation',
          'text': 'Traffic Enforcement ($province): Unpaid photo radar speeding ticket #TR-9941. Settle fee within 24h to avoid licence points: https://provincial-traffic-tickets-portal.cc/pay',
          'risk': 'DANGEROUS',
          'score': 96,
          'dangerous_keywords': ['Traffic Enforcement', 'photo radar', 'speeding ticket', 'licence points'],
          'suspect_links': ['https://provincial-traffic-tickets-portal.cc/pay'],
        },
        {
          'title': 'CRA Carbon Tax Rebate Interac',
          'category': 'Tax Refund Phishing',
          'text': 'Canada Revenue Agency: A federal carbon rebate refund of \$320.00 CAD is ready. Deposit your e-Transfer here: https://cra-arc-rebate-deposit.com/claim',
          'risk': 'DANGEROUS',
          'score': 95,
          'dangerous_keywords': ['Canada Revenue Agency', 'carbon rebate', 'e-Transfer'],
          'suspect_links': ['https://cra-arc-rebate-deposit.com/claim'],
        },
        {
          'title': 'Canada Post Held Package',
          'category': 'Delivery Fee Scam',
          'text': 'Canada Post: Parcel #CA-881203 held at provincial distribution centre. \$2.45 handling fee required: https://postescan-douane-frais.xyz/suivi',
          'risk': 'DANGEROUS',
          'score': 92,
          'dangerous_keywords': ['parcel', 'distribution centre', 'handling fee'],
          'suspect_links': ['https://postescan-douane-frais.xyz/suivi'],
        },
        {
          'title': 'RBC Royal Bank Security Alert',
          'category': 'Banking Impersonation',
          'text': 'RBC Royal Bank: Access temporarily suspended following unusual activity. Restore your account: https://rbcroyalbank-online-security.net/auth',
          'risk': 'DANGEROUS',
          'score': 98,
          'dangerous_keywords': ['RBC Royal Bank', 'Access temporarily suspended', 'unusual activity'],
          'suspect_links': ['https://rbcroyalbank-online-security.net/auth'],
        },
        {
          'title': 'Official Canada.ca Notice (Safe)',
          'category': 'Legitimate Utility Notice',
          'text': 'Government of Canada: Your annual benefits summary is ready in your official My Account at https://www.canada.ca. No action required by SMS.',
          'risk': 'SAFE',
          'score': 5,
          'dangerous_keywords': [],
          'suspect_links': [],
        },
      ];
    }
    return [
      {
        'title': 'Fausse Contravention Radar ($province)',
        'category': 'Government Impersonation',
        'text': 'Sécurité Routière ($province) : Contravention radar impayée #TR-9941. Réglez sous 24h pour éviter des points d\'inaptitude et pénalités : https://provincial-traffic-tickets-portal.cc/pay',
        'risk': 'DANGEROUS',
        'score': 96,
        'dangerous_keywords': ['Sécurité Routière', 'contravention radar', 'points d\'inaptitude', 'sous 24h'],
        'suspect_links': ['https://provincial-traffic-tickets-portal.cc/pay'],
      },
      {
        'title': 'Faux Remboursement ARC Interac',
        'category': 'Tax Refund Phishing',
        'text': 'Agence du Revenu du Canada (ARC) : Un remboursement de taxe carbone de 320.00\$ vous attend. Déposez votre virement : https://cra-arc-rebate-deposit.com/claim',
        'risk': 'DANGEROUS',
        'score': 95,
        'dangerous_keywords': ['ARC', 'remboursement', 'taxe carbone', 'virement'],
        'suspect_links': ['https://cra-arc-rebate-deposit.com/claim'],
      },
      {
        'title': 'Colis en Attente Postes Canada',
        'category': 'Delivery Fee Scam',
        'text': 'Postes Canada : Votre colis #CA-881203 est en attente au centre régional. Frais d\'expédition impayés de 2.45\$ : https://postescan-douane-frais.xyz/suivi',
        'risk': 'DANGEROUS',
        'score': 92,
        'dangerous_keywords': ['colis', 'centre régional', 'frais d\'expédition'],
        'suspect_links': ['https://postescan-douane-frais.xyz/suivi'],
      },
      {
        'title': 'Alerte Sécurité RBC Banque Royale',
        'category': 'Banking Impersonation',
        'text': 'RBC Banque Royale : Accès temporairement suspendu suite à une tentative suspecte. Restaurez votre accès sécurisé : https://rbcroyalbank-online-security.net/auth',
        'risk': 'DANGEROUS',
        'score': 98,
        'dangerous_keywords': ['RBC Banque Royale', 'Accès temporairement suspendu', 'tentative suspecte'],
        'suspect_links': ['https://rbcroyalbank-online-security.net/auth'],
      },
      {
        'title': 'Avis Officiel Canada.ca (Légitime)',
        'category': 'Legitimate Utility Notice',
        'text': 'Gouvernement du Canada : Votre sommaire de prestations est consultable dans votre dossier Mon dossier sur https://www.canada.ca. Aucun paiement par texto.',
        'risk': 'SAFE',
        'score': 5,
        'dangerous_keywords': [],
        'suspect_links': [],
      },
    ];
  }

  // --- Scénarios Régionaux États-Unis ---

  static List<Map<String, dynamic>> _getCaliforniaSmsSamples(bool isEn) {
    if (isEn) {
      return const [
        {
          'title': 'Fake California DMV FasTrak Toll',
          'category': 'DMV Toll Phishing',
          'text': 'CALIFORNIA DMV: Final notification for unpaid FasTrak toll violation on Highway 101. Pay \$45.50 immediately to avoid driver license suspension: https://dmv-ca-fastrak-settlement.org/pay',
          'risk': 'DANGEROUS',
          'score': 96,
          'dangerous_keywords': ['CALIFORNIA DMV', 'FasTrak', 'toll violation', 'driver license suspension', 'immediately'],
          'suspect_links': ['https://dmv-ca-fastrak-settlement.org/pay'],
        },
        {
          'title': 'PG&E Power Shutoff Scam',
          'category': 'Utility Disconnection Scam',
          'text': 'PG&E Urgency: Your power will be disconnected today within 45 minutes due to past due balance of \$164.20. Pay now by Zelle or card: https://pge-emergency-power-reconnect.net/bill',
          'risk': 'DANGEROUS',
          'score': 98,
          'dangerous_keywords': ['PG&E', 'disconnected', 'past due balance', 'Pay now', 'Zelle'],
          'suspect_links': ['https://pge-emergency-power-reconnect.net/bill'],
        },
        {
          'title': 'Wells Fargo Account Lockout',
          'category': 'Banking Impersonation',
          'text': 'Wells Fargo Alert: Online access suspended following an unrecognized login in San Francisco CA. Confirm identity to unlock: https://wellsfargo-verify-security.org/signin',
          'risk': 'DANGEROUS',
          'score': 97,
          'dangerous_keywords': ['Wells Fargo', 'access suspended', 'unrecognized login'],
          'suspect_links': ['https://wellsfargo-verify-security.org/signin'],
        },
        {
          'title': 'USPS Redelivery Fee Scam',
          'category': 'Delivery Fee Scam',
          'text': 'USPS Ground: Package #940011189922 cannot be delivered due to incomplete street address. Pay \$1.95 redelivery fee: https://usps-post-redelivery-us.xyz/address',
          'risk': 'DANGEROUS',
          'score': 93,
          'dangerous_keywords': ['USPS', 'incomplete street address', 'redelivery fee'],
          'suspect_links': ['https://usps-post-redelivery-us.xyz/address'],
        },
        {
          'title': 'PG&E Monthly Statement (Safe)',
          'category': 'Legitimate Utility Notice',
          'text': 'PG&E: Your monthly energy statement is ready. View your statement safely at https://www.pge.com. PG&E never asks for gift cards, Zelle, or immediate debit payments via SMS.',
          'risk': 'SAFE',
          'score': 5,
          'dangerous_keywords': [],
          'suspect_links': [],
        },
      ];
    }
    return const [
      {
        'title': 'Fausse Infraction DMV Fastrak Californie',
        'category': 'DMV Toll Phishing',
        'text': 'DMV CALIFORNIE : Dernier avis pour péage Fastrak impayé sur l\'autoroute 101. Réglez 45.50\$ immédiatement pour éviter la suspension de votre permis : https://dmv-ca-fastrak-settlement.org/pay',
        'risk': 'DANGEROUS',
        'score': 96,
        'dangerous_keywords': ['DMV', 'Fastrak', 'péage', 'suspension de permis'],
        'suspect_links': ['https://dmv-ca-fastrak-settlement.org/pay'],
      },
      {
        'title': 'Fausse Menace de Coupure PG&E',
        'category': 'Utility Disconnection Scam',
        'text': 'Urgence PG&E : Interruption de votre électricité aujourd\'hui sous 45 min pour solde impayé de 164.20\$. Payez par Zelle ou carte : https://pge-emergency-power-reconnect.net/bill',
        'risk': 'DANGEROUS',
        'score': 98,
        'dangerous_keywords': ['PG&E', 'coupure', 'solde impayé', 'Zelle'],
        'suspect_links': ['https://pge-emergency-power-reconnect.net/bill'],
      },
      {
        'title': 'Alerte Sécurité Wells Fargo (SF)',
        'category': 'Banking Impersonation',
        'text': 'Alerte Wells Fargo : Accès suspendu suite à une connexion suspecte à San Francisco CA. Débloquez votre compte en ligne : https://wellsfargo-verify-security.org/signin',
        'risk': 'DANGEROUS',
        'score': 97,
        'dangerous_keywords': ['Wells Fargo', 'Accès suspendu', 'connexion suspecte'],
        'suspect_links': ['https://wellsfargo-verify-security.org/signin'],
      },
      {
        'title': 'Faux Colis Bloqué USPS',
        'category': 'Delivery Fee Scam',
        'text': 'USPS : Votre colis #940011189922 ne peut être livré en raison d\'une adresse incomplète. Réglez 1.95\$ pour nouvelle livraison : https://usps-post-redelivery-us.xyz/address',
        'risk': 'DANGEROUS',
        'score': 93,
        'dangerous_keywords': ['USPS', 'colis', 'adresse incomplète'],
        'suspect_links': ['https://usps-post-redelivery-us.xyz/address'],
      },
      {
        'title': 'Relevé Mensuel PG&E (Légitime)',
        'category': 'Legitimate Utility Notice',
        'text': 'PG&E : Votre relevé mensuel d\'énergie est disponible sur https://www.pge.com. PG&E n\'exige jamais de virement Zelle ou de cartes prépayées par texto.',
        'risk': 'SAFE',
        'score': 5,
        'dangerous_keywords': [],
        'suspect_links': [],
      },
    ];
  }

  static List<Map<String, dynamic>> _getNewYorkSmsSamples(bool isEn) {
    if (isEn) {
      return const [
        {
          'title': 'Fake NY E-ZPass Toll Violation',
          'category': 'Toll Evasion Phishing',
          'text': 'NY Tolls by Mail: Unpaid E-ZPass violation fee of \$36.50 on NY Thruway. Settle immediately to avoid vehicle registration hold: https://ezpass-ny-tolls-services.net/pay',
          'risk': 'DANGEROUS',
          'score': 96,
          'dangerous_keywords': ['NY Tolls', 'E-ZPass', 'violation fee', 'registration hold'],
          'suspect_links': ['https://ezpass-ny-tolls-services.net/pay'],
        },
        {
          'title': 'Con Edison Disconnection Alert',
          'category': 'Utility Disconnection Scam',
          'text': 'Con Edison Emergency: Disconnection order scheduled today for unpaid bill of \$198.40. Call support or pay immediately: https://conedison-electric-paydesk.com/bill',
          'risk': 'DANGEROUS',
          'score': 98,
          'dangerous_keywords': ['Con Edison', 'Disconnection order', 'unpaid bill', 'immediately'],
          'suspect_links': ['https://conedison-electric-paydesk.com/bill'],
        },
        {
          'title': 'Fake NY DMV REAL ID Notice',
          'category': 'Government Impersonation',
          'text': 'NY DMV Notice: Your New York driver license must be validated for federal REAL ID compliance. Update info now: https://dmv-ny-gov-realid-validation.org/verify',
          'risk': 'DANGEROUS',
          'score': 94,
          'dangerous_keywords': ['NY DMV', 'driver license', 'REAL ID', 'compliance'],
          'suspect_links': ['https://dmv-ny-gov-realid-validation.org/verify'],
        },
        {
          'title': 'Chase Bank Card Fraud Alert',
          'category': 'Banking Impersonation',
          'text': 'Chase Fraud Alert: Did you authorize \$489.00 at Apple Manhattan? If not, verify and freeze your card immediately: https://chase-security-fraud-alert.net/auth',
          'risk': 'DANGEROUS',
          'score': 98,
          'dangerous_keywords': ['Chase Fraud Alert', 'authorize', 'freeze your card'],
          'suspect_links': ['https://chase-security-fraud-alert.net/auth'],
        },
        {
          'title': 'Con Edison Statement (Safe)',
          'category': 'Legitimate Utility Notice',
          'text': 'Con Edison: Your monthly bill is now available. Log in securely to your online account at https://www.coned.com. Con Edison never solicits wire transfers or prepaid cards.',
          'risk': 'SAFE',
          'score': 5,
          'dangerous_keywords': [],
          'suspect_links': [],
        },
      ];
    }
    return const [
      {
        'title': 'Fausse Infraction E-ZPass New York',
        'category': 'Toll Evasion Phishing',
        'text': 'Péages NY E-ZPass : Frais de péage impayés de 36.50\$ sur le NY Thruway. Réglez immédiatement pour éviter le blocage de l\'immatriculation : https://ezpass-ny-tolls-services.net/pay',
        'risk': 'DANGEROUS',
        'score': 96,
        'dangerous_keywords': ['E-ZPass', 'péage', 'blocage de l\'immatriculation'],
        'suspect_links': ['https://ezpass-ny-tolls-services.net/pay'],
      },
      {
        'title': 'Avis Coupure Électrique Con Edison',
        'category': 'Utility Disconnection Scam',
        'text': 'Urgence Con Edison : Ordre de coupure planifié pour solde impayé de 198.40\$. Réglez sur le portail sécurisé : https://conedison-electric-paydesk.com/bill',
        'risk': 'DANGEROUS',
        'score': 98,
        'dangerous_keywords': ['Con Edison', 'coupure', 'solde impayé'],
        'suspect_links': ['https://conedison-electric-paydesk.com/bill'],
      },
      {
        'title': 'Faux Avis REAL ID NY DMV',
        'category': 'Government Impersonation',
        'text': 'DMV New York : Votre permis doit être mis en conformité REAL ID. Validez vos informations personnelles : https://dmv-ny-gov-realid-validation.org/verify',
        'risk': 'DANGEROUS',
        'score': 94,
        'dangerous_keywords': ['DMV', 'permis', 'REAL ID'],
        'suspect_links': ['https://dmv-ny-gov-realid-validation.org/verify'],
      },
      {
        'title': 'Alerte Fraude Chase Manhattan',
        'category': 'Banking Impersonation',
        'text': 'Sécurité Chase : Avez-vous autorisé 489.00\$ chez Apple Manhattan ? Confirmez ou bloquez votre carte : https://chase-security-fraud-alert.net/auth',
        'risk': 'DANGEROUS',
        'score': 98,
        'dangerous_keywords': ['Chase', 'bloquez votre carte', 'autorisé'],
        'suspect_links': ['https://chase-security-fraud-alert.net/auth'],
      },
      {
        'title': 'Facture Officielle Con Edison (Légitime)',
        'category': 'Legitimate Utility Notice',
        'text': 'Con Edison : Votre facture mensuelle est prête sur https://www.coned.com. Con Edison n\'exige jamais de virement urgent par SMS.',
        'risk': 'SAFE',
        'score': 5,
        'dangerous_keywords': [],
        'suspect_links': [],
      },
    ];
  }

  static List<Map<String, dynamic>> _getTexasSmsSamples(bool isEn) {
    if (isEn) {
      return const [
        {
          'title': 'Fake Texas TxTag Toll Violation',
          'category': 'Toll Evasion Phishing',
          'text': 'TxTag Alert: Unpaid toll balance of \$28.40 on Texas Tollway. Pay within 24 hours to avoid vehicle registration hold: https://txtag-toll-texas-services.com/pay',
          'risk': 'DANGEROUS',
          'score': 96,
          'dangerous_keywords': ['TxTag', 'toll balance', 'registration hold', 'within 24 hours'],
          'suspect_links': ['https://txtag-toll-texas-services.com/pay'],
        },
        {
          'title': 'Texas DPS License Suspension',
          'category': 'Government Impersonation',
          'text': 'Texas DPS: Urgent action required regarding your driver license status. Confirm records to avoid suspension: https://texas-dps-licence-status.org/verify',
          'risk': 'DANGEROUS',
          'score': 95,
          'dangerous_keywords': ['Texas DPS', 'driver license', 'suspension'],
          'suspect_links': ['https://texas-dps-licence-status.org/verify'],
        },
        {
          'title': 'Oncor Energy Shutoff Alert',
          'category': 'Utility Disconnection Scam',
          'text': 'Oncor Power: Urgent notice! Your electricity is scheduled for shutoff for \$145.20 overdue balance. Pay immediately: https://oncor-electric-settle-bill.net/pay',
          'risk': 'DANGEROUS',
          'score': 97,
          'dangerous_keywords': ['Oncor Power', 'scheduled for shutoff', 'overdue balance'],
          'suspect_links': ['https://oncor-electric-settle-bill.net/pay'],
        },
        {
          'title': 'Wells Fargo Texas Mobile Alert',
          'category': 'Banking Impersonation',
          'text': 'Wells Fargo Alert: Unusual activity detected in Dallas TX. Online banking is restricted. Verify here: https://wellsfargo-verify-security.org/signin',
          'risk': 'DANGEROUS',
          'score': 98,
          'dangerous_keywords': ['Wells Fargo', 'Unusual activity', 'restricted'],
          'suspect_links': ['https://wellsfargo-verify-security.org/signin'],
        },
        {
          'title': 'Official Texas.gov Notice (Safe)',
          'category': 'Legitimate Utility Notice',
          'text': 'State of Texas: Your annual vehicle inspection renewal confirmation is available online at https://www.texas.gov. No payment requested by SMS.',
          'risk': 'SAFE',
          'score': 5,
          'dangerous_keywords': [],
          'suspect_links': [],
        },
      ];
    }
    return const [
      {
        'title': 'Fausse Infraction TxTag Texas',
        'category': 'Toll Evasion Phishing',
        'text': 'Avis TxTag : Solde de péage impayé de 28.40\$ sur l\'autoroute texane. Réglez sous 24h pour éviter le blocage de carte grise : https://txtag-toll-texas-services.com/pay',
        'risk': 'DANGEROUS',
        'score': 96,
        'dangerous_keywords': ['TxTag', 'péage impayé', 'carte grise', 'sous 24h'],
        'suspect_links': ['https://txtag-toll-texas-services.com/pay'],
      },
      {
        'title': 'Fausse Suspension Texas DPS',
        'category': 'Government Impersonation',
        'text': 'Texas DPS : Action requise concernant le statut de votre permis de conduire. Confirmez votre dossier pour éviter la suspension : https://texas-dps-licence-status.org/verify',
        'risk': 'DANGEROUS',
        'score': 95,
        'dangerous_keywords': ['Texas DPS', 'permis de conduire', 'suspension'],
        'suspect_links': ['https://texas-dps-licence-status.org/verify'],
      },
      {
        'title': 'Menace Coupure Électrique Oncor',
        'category': 'Utility Disconnection Scam',
        'text': 'Oncor Énergie : Coupure d\'électricité planifiée pour facture impayée de 145.20\$. Réglez d\'urgence : https://oncor-electric-settle-bill.net/pay',
        'risk': 'DANGEROUS',
        'score': 97,
        'dangerous_keywords': ['Oncor', 'Coupure d\'électricité', 'facture impayée'],
        'suspect_links': ['https://oncor-electric-settle-bill.net/pay'],
      },
      {
        'title': 'Alerte Sécurité Wells Fargo Texas',
        'category': 'Banking Impersonation',
        'text': 'Wells Fargo : Activité suspecte détectée à Dallas TX. Accès mobile restreint. Vérifiez votre profil : https://wellsfargo-verify-security.org/signin',
        'risk': 'DANGEROUS',
        'score': 98,
        'dangerous_keywords': ['Wells Fargo', 'Activité suspecte', 'restreint'],
        'suspect_links': ['https://wellsfargo-verify-security.org/signin'],
      },
      {
        'title': 'Avis Officiel Texas.gov (Légitime)',
        'category': 'Legitimate Utility Notice',
        'text': 'État du Texas : Votre confirmation de renouvellement d\'inspection de véhicule est disponible sur https://www.texas.gov. Aucun paiement par texto.',
        'risk': 'SAFE',
        'score': 5,
        'dangerous_keywords': [],
        'suspect_links': [],
      },
    ];
  }

  static List<Map<String, dynamic>> _getFloridaSmsSamples(bool isEn) {
    if (isEn) {
      return const [
        {
          'title': 'Fake Florida SunPass Toll Notice',
          'category': 'Toll Evasion Phishing',
          'text': 'SunPass Alert: Unpaid Florida toll charges of \$34.20 on Turnpike. Settle now to avoid license suspension: https://sunpass-florida-tolls-enforcement.org/pay',
          'risk': 'DANGEROUS',
          'score': 96,
          'dangerous_keywords': ['SunPass', 'toll charges', 'license suspension'],
          'suspect_links': ['https://sunpass-florida-tolls-enforcement.org/pay'],
        },
        {
          'title': 'FLHSMV License Action Required',
          'category': 'Government Impersonation',
          'text': 'FLHSMV Notice: Immediate action required on Florida driver license #FL-90218. Settle overdue penalty: https://flhsmv-florida-licence-portal.net/renew',
          'risk': 'DANGEROUS',
          'score': 95,
          'dangerous_keywords': ['FLHSMV', 'driver license', 'penalty'],
          'suspect_links': ['https://flhsmv-florida-licence-portal.net/renew'],
        },
        {
          'title': 'FPL Power Disconnection Alert',
          'category': 'Utility Disconnection Scam',
          'text': 'FPL Urgent: Florida Power & Light disconnection order for unpaid \$172.50. Settle balance now: https://fpl-power-emergency-pay.com/bill',
          'risk': 'DANGEROUS',
          'score': 97,
          'dangerous_keywords': ['FPL', 'disconnection order', 'unpaid'],
          'suspect_links': ['https://fpl-power-emergency-pay.com/bill'],
        },
        {
          'title': 'Bank of America Fraud Alert (Miami)',
          'category': 'Banking Impersonation',
          'text': 'Bank of America Alert: Suspicious transaction of \$520.00 flagged in Miami FL. Lock your card if unauthorized: https://bankofamerica-fraud-detection.net/verify',
          'risk': 'DANGEROUS',
          'score': 98,
          'dangerous_keywords': ['Bank of America', 'Suspicious transaction', 'Lock your card'],
          'suspect_links': ['https://bankofamerica-fraud-detection.net/verify'],
        },
        {
          'title': 'FPL Monthly Statement (Safe)',
          'category': 'Legitimate Utility Notice',
          'text': 'FPL: Your monthly electricity statement is ready. Review your account safely at https://www.fpl.com. FPL never requests wire transfers via text message.',
          'risk': 'SAFE',
          'score': 5,
          'dangerous_keywords': [],
          'suspect_links': [],
        },
      ];
    }
    return const [
      {
        'title': 'Fausse Infraction SunPass Floride',
        'category': 'Toll Evasion Phishing',
        'text': 'Avis SunPass : Péage impayé de 34.20\$ sur le Turnpike de Floride. Réglez pour éviter la suspension de votre permis : https://sunpass-florida-tolls-enforcement.org/pay',
        'risk': 'DANGEROUS',
        'score': 96,
        'dangerous_keywords': ['SunPass', 'péage impayé', 'suspension de votre permis'],
        'suspect_links': ['https://sunpass-florida-tolls-enforcement.org/pay'],
      },
      {
        'title': 'Alerte Suspension FLHSMV Floride',
        'category': 'Government Impersonation',
        'text': 'FLHSMV Floride : Action requise concernant votre permis de conduire. Régularisez votre situation : https://flhsmv-florida-licence-portal.net/renew',
        'risk': 'DANGEROUS',
        'score': 95,
        'dangerous_keywords': ['FLHSMV', 'permis de conduire', 'action requise'],
        'suspect_links': ['https://flhsmv-florida-licence-portal.net/renew'],
      },
      {
        'title': 'Menace de Coupure Électrique FPL',
        'category': 'Utility Disconnection Scam',
        'text': 'Urgence FPL : Interruption d\'électricité imminente pour facture impayée de 172.50\$. Régularisez ici : https://fpl-power-emergency-pay.com/bill',
        'risk': 'DANGEROUS',
        'score': 97,
        'dangerous_keywords': ['FPL', 'Interruption d\'électricité', 'facture impayée'],
        'suspect_links': ['https://fpl-power-emergency-pay.com/bill'],
      },
      {
        'title': 'Alerte Fraude Bank of America Miami',
        'category': 'Banking Impersonation',
        'text': 'Bank of America : Transaction suspecte de 520.00\$ à Miami FL. Bloquez votre carte si non autorisée : https://bankofamerica-fraud-detection.net/verify',
        'risk': 'DANGEROUS',
        'score': 98,
        'dangerous_keywords': ['Bank of America', 'Transaction suspecte', 'Bloquez votre carte'],
        'suspect_links': ['https://bankofamerica-fraud-detection.net/verify'],
      },
      {
        'title': 'Facture Mensuelle FPL (Légitime)',
        'category': 'Legitimate Utility Notice',
        'text': 'FPL : Votre relevé mensuel d\'électricité est prêt dans votre espace client sur https://www.fpl.com. FPL n\'exige aucun virement direct par SMS.',
        'risk': 'SAFE',
        'score': 5,
        'dangerous_keywords': [],
        'suspect_links': [],
      },
    ];
  }

  static List<Map<String, dynamic>> _getGenericUsSmsSamples(bool isEn, {required String stateCode}) {
    if (isEn) {
      return [
        {
          'title': 'State DMV Toll Violation ($stateCode)',
          'category': 'DMV Toll Phishing',
          'text': 'State DMV Toll Services ($stateCode): Unpaid highway toll violation of \$38.50. Settle immediately to avoid driver license suspension: https://state-tolls-enforcement-services.org/pay',
          'risk': 'DANGEROUS',
          'score': 96,
          'dangerous_keywords': ['State DMV', 'toll violation', 'driver license suspension', 'immediately'],
          'suspect_links': ['https://state-tolls-enforcement-services.org/pay'],
        },
        {
          'title': 'IRS Federal Tax Refund Notice',
          'category': 'Tax Refund Phishing',
          'text': 'Internal Revenue Service (IRS): Your tax refund of \$640.00 USD is available for direct electronic deposit. Claim now: https://irs-tax-refund-portal.us/claim',
          'risk': 'DANGEROUS',
          'score': 95,
          'dangerous_keywords': ['Internal Revenue Service', 'IRS', 'tax refund', 'electronic deposit'],
          'suspect_links': ['https://irs-tax-refund-portal.us/claim'],
        },
        {
          'title': 'USPS Package Address Verification',
          'category': 'Delivery Fee Scam',
          'text': 'USPS Tracking: Package #US-981249 cannot be delivered due to incorrect street number. Verify address and pay \$1.95: https://usps-post-redelivery-us.xyz/address',
          'risk': 'DANGEROUS',
          'score': 93,
          'dangerous_keywords': ['USPS', 'incorrect street number', 'Verify address'],
          'suspect_links': ['https://usps-post-redelivery-us.xyz/address'],
        },
        {
          'title': 'Chase / BoA Banking Security Freeze',
          'category': 'Banking Impersonation',
          'text': 'Bank Fraud Alert: Online access temporarily restricted due to unauthorized sign-in attempt. Verify identity: https://chase-security-fraud-alert.net/auth',
          'risk': 'DANGEROUS',
          'score': 98,
          'dangerous_keywords': ['Bank Fraud Alert', 'restricted', 'unauthorized sign-in'],
          'suspect_links': ['https://chase-security-fraud-alert.net/auth'],
        },
        {
          'title': 'Official USA.gov Alert (Safe)',
          'category': 'Legitimate Utility Notice',
          'text': 'USA.gov Official: Your federal benefit statements and account preferences can be reviewed safely at https://www.usa.gov. The US Government never demands gift cards or fees by SMS.',
          'risk': 'SAFE',
          'score': 5,
          'dangerous_keywords': [],
          'suspect_links': [],
        },
      ];
    }
    return [
      {
        'title': 'Avis Infraction Péage d\'État ($stateCode)',
        'category': 'DMV Toll Phishing',
        'text': 'Services Péage DMV ($stateCode) : Infraction de péage impayée de 38.50\$. Réglez immédiatement pour éviter la suspension de votre permis : https://state-tolls-enforcement-services.org/pay',
        'risk': 'DANGEROUS',
        'score': 96,
        'dangerous_keywords': ['DMV', 'péage', 'suspension de votre permis', 'immédiatement'],
        'suspect_links': ['https://state-tolls-enforcement-services.org/pay'],
      },
      {
        'title': 'Faux Remboursement Fédéral IRS',
        'category': 'Tax Refund Phishing',
        'text': 'Internal Revenue Service (IRS) : Votre remboursement d\'impôt de 640.00\$ USD est prêt. Réclamez votre virement électronique : https://irs-tax-refund-portal.us/claim',
        'risk': 'DANGEROUS',
        'score': 95,
        'dangerous_keywords': ['IRS', 'remboursement d\'impôt', 'virement électronique'],
        'suspect_links': ['https://irs-tax-refund-portal.us/claim'],
      },
      {
        'title': 'Échec de Livraison USPS',
        'category': 'Delivery Fee Scam',
        'text': 'Suivi USPS : Colis #US-981249 bloqué pour numéro de rue incorrect. Validez l\'adresse et réglez 1.95\$ : https://usps-post-redelivery-us.xyz/address',
        'risk': 'DANGEROUS',
        'score': 93,
        'dangerous_keywords': ['USPS', 'bloqué', 'Validez l\'adresse'],
        'suspect_links': ['https://usps-post-redelivery-us.xyz/address'],
      },
      {
        'title': 'Alerte Sécurité Bancaire US',
        'category': 'Banking Impersonation',
        'text': 'Alerte Sécurité Bancaire : Accès en ligne restreint suite à une tentative suspecte. Confirmez votre identité : https://chase-security-fraud-alert.net/auth',
        'risk': 'DANGEROUS',
        'score': 98,
        'dangerous_keywords': ['Alerte Sécurité', 'restreint', 'tentative suspecte'],
        'suspect_links': ['https://chase-security-fraud-alert.net/auth'],
      },
      {
        'title': 'Avis Officiel USA.gov (Légitime)',
        'category': 'Legitimate Utility Notice',
        'text': 'USA.gov : Consultez vos documents officiels et prestations sur le portail fédéral https://www.usa.gov. Le gouvernement américain ne sollicite aucun paiement par SMS.',
        'risk': 'SAFE',
        'score': 5,
        'dangerous_keywords': [],
        'suspect_links': [],
      },
    ];
  }

  static List<Map<String, dynamic>> get demoSmsSamples => getDemoSmsSamples(isEn: false);

  /// Statistiques d'administration simulées pour une présentation complète
  static Map<String, dynamic> getDemoAdminStats() {
    return {
      'total_blacklisted': 1482,
      'total_blocked': 1340,
      'total_whitelisted': 142,
      'total_safe_reports': 86,
      'total_auto_consensus': 54,
      'total_reports': 4280,
      'total_users': 5230,
      'active_users': 3890,
      'filtered_calls_count': 32450,
      'false_positives_prevented': 140,
      'fraud_categories': {
        'ROBOCALL': 1498,
        'PHISHING': 1070,
        'CRA_IMPOSTOR': 770,
        'BANK_SCAM': 599,
        'DELIVERY_SCAM': 343,
      },
      'daily_trends': [
        {'date': '2026-10-04', 'day_name': 'Dim', 'reports': 48, 'blocked': 62, 'protected': 312},
        {'date': '2026-10-05', 'day_name': 'Lun', 'reports': 85, 'blocked': 110, 'protected': 550},
        {'date': '2026-10-06', 'day_name': 'Mar', 'reports': 92, 'blocked': 120, 'protected': 598},
        {'date': '2026-10-07', 'day_name': 'Mer', 'reports': 78, 'blocked': 101, 'protected': 507},
        {'date': '2026-10-08', 'day_name': 'Jeu', 'reports': 114, 'blocked': 148, 'protected': 741},
        {'date': '2026-10-09', 'day_name': 'Ven', 'reports': 130, 'blocked': 169, 'protected': 845},
        {'date': '2026-10-10', 'day_name': 'Sam', 'reports': 65, 'blocked': 84, 'protected': 422},
      ],
      'users_by_country': {'CA': 4120, 'US': 1110},
      'users_by_province': [
        {'country': 'CA', 'province_or_state': 'QC', 'total': 2850},
        {'country': 'CA', 'province_or_state': 'ON', 'total': 920},
        {'country': 'CA', 'province_or_state': 'BC', 'total': 350},
        {'country': 'US', 'province_or_state': 'NY', 'total': 480},
        {'country': 'US', 'province_or_state': 'FL', 'total': 310},
        {'country': 'US', 'province_or_state': 'CA', 'total': 320},
      ],
      'recent_reports': [
        {
          'id': 'demo-rep-1',
          'phone_hash': 'demo_hash_cra',
          'masked_number': '+1 514 *** **34',
          'category': 'CRA_IMPOSTOR',
          'risk_score': 96,
          'is_whitelisted': false,
          'is_blocked': true,
          'created_at': DateTime.now().subtract(const Duration(minutes: 12)).toIso8601String(),
        },
        {
          'id': 'demo-rep-2',
          'phone_hash': 'demo_hash_dhl',
          'masked_number': '+1 438 *** **78',
          'category': 'DELIVERY_SCAM',
          'risk_score': 88,
          'is_whitelisted': false,
          'is_blocked': true,
          'created_at': DateTime.now().subtract(const Duration(minutes: 34)).toIso8601String(),
        },
        {
          'id': 'demo-rep-3',
          'phone_hash': 'demo_hash_bank',
          'masked_number': '+1 819 *** **12',
          'category': 'BANK_SCAM',
          'risk_score': 94,
          'is_whitelisted': false,
          'is_blocked': true,
          'created_at': DateTime.now().subtract(const Duration(hours: 1, minutes: 15)).toIso8601String(),
        },
      ],
    };
  }

  /// Injecte les numéros dans SQLite local
  Future<void> _seedDemoDatabase() async {
    final dbHelper = DatabaseHelper.instance;

    for (final s in demoScenarios) {
      final rawNumber = s['phone_number'] as String;
      final hash = CryptoUtils.hashPhoneNumber(rawNumber);
      final isBlocked = s['is_blocked'] as bool;

      await dbHelper.insertOrUpdateBlacklistedNumber(BlacklistedNumber(
        phoneHash: hash,
        maskedNumber: CryptoUtils.maskPhoneNumber(rawNumber),
        riskScore: s['risk_score'] as int,
        category: s['category'] as String,
        reportsCount: isBlocked ? 18 : 0,
        updatedAt: DateTime.now().toIso8601String(),
      ));
    }
  }

  /// Nettoie les numéros du mode démo
  Future<void> _cleanDemoDatabase() async {
    final dbHelper = DatabaseHelper.instance;
    final hashes = demoScenarios.map((s) {
      final rawNumber = s['phone_number'] as String;
      return CryptoUtils.hashPhoneNumber(rawNumber);
    }).toList();
    await dbHelper.deleteBatchBlacklistedNumbers(hashes);
  }
}
