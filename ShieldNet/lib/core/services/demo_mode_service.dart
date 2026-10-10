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
  static const List<Map<String, dynamic>> demoScenarios = [
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

  /// Exemples de SMS frauduleux réalistes pour l'inspecteur SMS
  static const List<Map<String, dynamic>> demoSmsSamples = [
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
      'title': 'Colis Bloqué Postes Canada',
      'category': 'Delivery Fee Scam',
      'text': 'Postes Canada : Votre colis #CA-902188 est en attente au centre de tri. Frais de douane impayés de 2.45\$. Réglez immédiatement pour livraison : https://postescan-douane-frais.xyz/suivi',
      'risk': 'DANGEROUS',
      'score': 92,
      'dangerous_keywords': ['colis', 'centre de tri', 'frais de douane', 'immédiatement'],
      'suspect_links': ['https://postescan-douane-frais.xyz/suivi'],
    },
    {
      'title': 'Alerte Sécurité Desjardins AccèsD',
      'category': 'Banking Impersonation',
      'text': 'Alerte Desjardins : AccèsD temporairement verrouillé suite à une connexion inhabituelle. Réactivez votre compte sécurisé ici : https://accesd-desjardins-auth.net/login',
      'risk': 'DANGEROUS',
      'score': 98,
      'dangerous_keywords': ['AccèsD', 'temporairement verrouillé', 'connexion inhabituelle'],
      'suspect_links': ['https://accesd-desjardins-auth.net/login'],
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
