import 'package:flutter/material.dart';
import '../../../../core/services/observability_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Page Visuelle de Conformité Légale, Vie Privée et Éthique
/// Présente les garanties rigoureuses de conformité Loi 25 (Québec),
/// PIPEDA (Canada) et démontre qu'aucun carnet d'adresses n'est collecté.
class LegalCompliancePage extends StatefulWidget {
  const LegalCompliancePage({super.key});

  @override
  State<LegalCompliancePage> createState() => _LegalCompliancePageState();
}

class _LegalCompliancePageState extends State<LegalCompliancePage> {
  @override
  void initState() {
    super.initState();
    ObservabilityService.instance.recordFeatureUsage('compliance_check');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AppTheme.cardBg(isDark);
    final borderColor = AppTheme.borderColor(isDark);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conformité, Vie Privée & Éthique', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // En-tête officiel avec badges
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.brandGradient,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.verified_user_rounded, color: Colors.white, size: 30),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Bouclier Télécom Privacy-by-Design',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                  'ShieldNet applique dès sa conception les normes les plus strictes de souveraineté numérique et de protection des données personnelles.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Badges juridiques
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildJurisdictionBadge('🇨🇦 Loi 25 du Québec', 'art. 28.1 RGPD-équivalent', const Color(0xFF0284C7)),
              _buildJurisdictionBadge('🍁 LPRPDE / PIPEDA', 'Canada Fédéral', const Color(0xFF10B981)),
              _buildJurisdictionBadge('🇺🇸 TCPA & FCC', 'STIR/SHAKEN Validé', const Color(0xFF8B5CF6)),
              _buildJurisdictionBadge('🔒 Zéro Tiers', 'Aucun SDK publicitaire', Colors.deepOrange),
            ],
          ),
          const SizedBox(height: 22),

          // Pilier 1 : Démonstration Zéro Carnet d'Adresses
          _buildComplianceSection(
            cardBg: cardBg,
            borderColor: borderColor,
            icon: Icons.contacts_rounded,
            iconColor: AppTheme.accentGreen,
            title: '1. Garantie Zéro Collecte de Contacts',
            subtitle: 'Aucun carnet d\'adresses ni liste de contacts n\'est jamais téléversé sur nos serveurs.',
            content: 'Contrairement aux applications commerciales qui aspirent vos contacts sur leurs serveurs distants, ShieldNet effectue toutes ses vérifications de contacts 100% en local sur votre terminal Android via le ContentProvider interne.\n\n'
                '• Vos contacts personnels restent hermétiquement confinés à la puce de votre appareil.\n'
                '• Aucune métadonnée nominative (nom, prénom, fréquence d\'appels) n\'est envoyée à qui que ce soit.',
          ),
          const SizedBox(height: 16),

          // Pilier 2 : Protection Cryptographique Salée (Android Keystore)
          _buildComplianceSection(
            cardBg: cardBg,
            borderColor: borderColor,
            icon: Icons.key_rounded,
            iconColor: AppTheme.primaryColor,
            title: '2. Hachage Salé Matériel (Android Keystore)',
            subtitle: 'Les numéros signalés ne transitent jamais en clair sur le réseau.',
            content: 'Pour identifier les spammeurs sans divulguer les numéros :\n\n'
                '• Chaque numéro est normalisé au format E.164 international (+1...).\n'
                '• Un condensat cryptographique HMAC-SHA256 est généré avec un sel unique adossé à l\'enclave sécurisée de votre appareil (Android Keystore hardware).\n'
                '• Il est mathématiquement irréversible de retrouver le numéro de téléphone original à partir de ce hash.',
          ),
          const SizedBox(height: 16),

          // Pilier 3 : Droit à l'oubli et Purge Automatique
          _buildComplianceSection(
            cardBg: cardBg,
            borderColor: borderColor,
            icon: Icons.auto_delete_rounded,
            iconColor: AppTheme.accentOrange,
            title: '3. Rétention Limitée & Droit à l\'Oubli (Loi 25)',
            subtitle: 'Respect scrupuleux du cycle de vie des données et droit d\'effacement irréversible.',
            content: 'Conformément à la Loi 25 du Québec :\n\n'
                '• Expiration automatique : Les signalements et logs d\'appels sont purgés de la mémoire sous 30 à 90 jours.\n'
                '• Suppression instantanée de compte : L\'utilisateur peut à tout instant supprimer son compte depuis les Paramètres. Tous ses signalements sont immédiatement anonymisés et ses données nominatives irrémédiablement effacées.',
          ),
          const SizedBox(height: 16),

          // Pilier 4 : Immunité Institutionnelle Absolue
          _buildComplianceSection(
            cardBg: cardBg,
            borderColor: borderColor,
            icon: Icons.local_hospital_rounded,
            iconColor: AppTheme.accentCyan,
            title: '4. Immunité Absolue des Services d\'Urgence',
            subtitle: 'Garantie vitale de zéro faux positif sur les services publics essentiels.',
            content: 'Le moteur ShieldNet intègre une liste d\'immunité inviolable codée en dur :\n\n'
                '• Les numéros 911 (Urgences), 811 (Info-Santé Québec), 988 (Prévention du suicide) et les hôpitaux répertoriés ne peuvent JAMAIS être bloqués ni signalés, garantissant une sécurité citoyenne sans faille.',
          ),
          const SizedBox(height: 24),

          // Contact délégué à la protection des données
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: const Row(
              children: [
                Icon(Icons.gavel_rounded, color: Colors.grey, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Délégué à la Protection des Données (DPO)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'ShieldNet Québec • Contact: privacy@shieldnet.app',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJurisdictionBadge(String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildComplianceSection({
    required Color cardBg,
    required Color borderColor,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(fontSize: 12.5, height: 1.45),
          ),
        ],
      ),
    );
  }
}
