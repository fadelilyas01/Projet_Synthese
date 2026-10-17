import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/services/observability_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Page Visuelle de Conformité Légale, Vie Privée et Éthique
/// Présente les garanties rigoureuses de conformité Loi 25 (Québec),
/// PIPEDA (Canada) et démontre qu'aucun carnet d'adresses n'est collecté.
class LegalCompliancePage extends ConsumerStatefulWidget {
  const LegalCompliancePage({super.key});

  @override
  ConsumerState<LegalCompliancePage> createState() => _LegalCompliancePageState();
}

class _LegalCompliancePageState extends ConsumerState<LegalCompliancePage> {
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
    final isEn = ref.watch(localeProvider).languageCode == 'en';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEn ? 'Compliance, Privacy & Ethics' : 'Conformité, Vie Privée & Éthique',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, color: Colors.white, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEn ? 'Telecom Shield & Privacy Protection' : 'Bouclier Télécom & Vie Privée',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  isEn
                      ? 'ShieldNet enforces the highest standards of digital sovereignty and data protection from its core architecture.'
                      : 'ShieldNet applique dès sa conception les normes les plus strictes de souveraineté numérique et de protection des données personnelles.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
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
              _buildJurisdictionBadge(
                isEn ? '🇨🇦 Quebec Law 25' : '🇨🇦 Loi 25 du Québec',
                isEn ? 'Strict data protection' : 'Protection stricte des données',
                const Color(0xFF0284C7),
              ),
              _buildJurisdictionBadge(
                isEn ? '🍁 PIPEDA / LPRPDE' : '🍁 LPRPDE / PIPEDA',
                isEn ? 'Federal Canada' : 'Canada Fédéral',
                const Color(0xFF10B981),
              ),
              _buildJurisdictionBadge(
                isEn ? '🇺🇸 Anti-Fraud' : '🇺🇸 Anti-Fraude',
                isEn ? 'Anti-spoofing certified' : 'Anti-usurpation certifié',
                const Color(0xFF8B5CF6),
              ),
              _buildJurisdictionBadge(
                isEn ? '🔒 Zero Third-Party' : '🔒 Zéro Tiers',
                isEn ? 'No ad trackers' : 'Aucun traceur publicitaire',
                Colors.deepOrange,
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Pilier 1 : Démonstration Zéro Carnet d'Adresses
          _buildComplianceSection(
            cardBg: cardBg,
            borderColor: borderColor,
            icon: Icons.contacts_rounded,
            iconColor: AppTheme.accentGreen,
            title: isEn ? '1. Zero Contact Book Collection Guarantee' : '1. Garantie Zéro Collecte de Contacts',
            subtitle: isEn
                ? 'No address book or personal contact list is ever uploaded to our servers.'
                : 'Aucun carnet d\'adresses ni liste de contacts n\'est jamais téléversé sur nos serveurs.',
            content: isEn
                ? 'Unlike commercial caller-ID apps that harvest your contacts onto remote databases, ShieldNet conducts all contact checks 100% locally on your phone without sending any data over the internet.\n\n'
                  '• Your personal contacts stay strictly confined to your device chip.\n'
                  '• Zero identifiable metadata (names, phone numbers, call frequency) is sent to anyone.'
                : 'Contrairement aux applications commerciales qui aspirent vos contacts sur leurs serveurs distants, ShieldNet effectue toutes ses vérifications de contacts 100% en local, directement dans la mémoire sécurisée de votre téléphone.\n\n'
                  '• Vos contacts personnels restent hermétiquement confinés à la puce de votre appareil.\n'
                  '• Aucune métadonnée nominative (nom, prénom, fréquence d\'appels) n\'est envoyée à qui que ce soit.',
          ),
          const SizedBox(height: 16),

          // Pilier 2 : Anonymisation Totale & Sécurité
          _buildComplianceSection(
            cardBg: cardBg,
            borderColor: borderColor,
            icon: Icons.key_rounded,
            iconColor: AppTheme.primaryColor,
            title: isEn ? '2. Total Anonymization & Encryption' : '2. Anonymisation Totale & Sécurité',
            subtitle: isEn
                ? 'Your phone numbers and identity are never exposed in cleartext.'
                : 'Vos numéros et votre identité ne circulent jamais en clair sur le réseau.',
            content: isEn
                ? 'To protect your privacy while effectively blocking scammers:\n\n'
                  '• Your phone number and communications remain strictly anonymous.\n'
                  '• Advanced irreversible encryption protects all threat intelligence.\n'
                  '• It is mathematically impossible for anyone to trace a report back to your personal identity.'
                : 'Pour vous protéger des spammeurs tout en garantissant votre vie privée :\n\n'
                  '• Votre numéro de téléphone et vos correspondants restent strictement anonymes.\n'
                  '• Un chiffrement sécurisé et irréversible protège les données de protection.\n'
                  '• Il est mathématiquement impossible pour quiconque de remonter à votre identité personnelle.',
          ),
          const SizedBox(height: 16),

          // Pilier 3 : Droit à l'oubli et Purge Automatique
          _buildComplianceSection(
            cardBg: cardBg,
            borderColor: borderColor,
            icon: Icons.auto_delete_rounded,
            iconColor: AppTheme.accentOrange,
            title: isEn ? '3. Limited Retention & Right to be Forgotten' : '3. Rétention Limitée & Droit à l\'Oubli (Loi 25)',
            subtitle: isEn
                ? 'Strict lifecycle management and permanent data erasure rights.'
                : 'Respect scrupuleux du cycle de vie des données et droit d\'effacement irréversible.',
            content: isEn
                ? 'In accordance with Quebec Law 25 and PIPEDA:\n\n'
                  '• Automatic expiration: Call logs and reports are automatically purged from memory after 30 to 90 days.\n'
                  '• Instant account deletion: You can delete your account at any time from Settings. All your reports are immediately anonymized and personal data permanently erased.'
                : 'Conformément à la Loi 25 du Québec :\n\n'
                  '• Expiration automatique : Les signalements et historiques d\'appels sont purgés de la mémoire sous 30 à 90 jours.\n'
                  '• Suppression instantanée de compte : L\'utilisateur peut à tout instant supprimer son compte depuis les Paramètres. Tous ses signalements sont immédiatement anonymisés et ses données nominatives irrémédiablement effacées.',
          ),
          const SizedBox(height: 16),

          // Pilier 4 : Immunité Institutionnelle Absolue
          _buildComplianceSection(
            cardBg: cardBg,
            borderColor: borderColor,
            icon: Icons.local_hospital_rounded,
            iconColor: AppTheme.accentCyan,
            title: isEn ? '4. Absolute Emergency Service Immunity' : '4. Immunité Absolue des Services d\'Urgence',
            subtitle: isEn
                ? 'Zero false-positive guarantee on vital public services.'
                : 'Garantie vitale de zéro faux positif sur les services publics essentiels.',
            content: isEn
                ? 'The ShieldNet engine includes an inviolable, hardcoded priority whitelist:\n\n'
                  '• Emergency numbers (911, 811 Info-Health, 988 Suicide Crisis Line) and certified hospitals can NEVER be blocked or filtered, guaranteeing continuous citizen safety.'
                : 'Le moteur ShieldNet intègre une liste d\'immunité inviolable codée en dur :\n\n'
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
            child: Row(
              children: [
                const Icon(Icons.gavel_rounded, color: Colors.grey, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEn ? 'Data Protection Officer (DPO)' : 'Délégué à la Protection des Données (DPO)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      const Text(
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
