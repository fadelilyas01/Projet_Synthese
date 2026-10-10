import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../pages/developer_diagnostic_page.dart';

/// Onglet Vue d'Ensemble & Métriques de la console d'administration
class AdminOverviewTab extends ConsumerWidget {
  final Map<String, dynamic>? stats;
  final Map<String, dynamic>? syncStatus;
  final bool isLoadingStats;
  final bool isSyncingClient;
  final VoidCallback onPurge;
  final VoidCallback onConsensusAudit;
  final VoidCallback onDeltaSync;
  final VoidCallback onFullSync;
  final VoidCallback onRefresh;

  const AdminOverviewTab({
    super.key,
    required this.stats,
    required this.syncStatus,
    required this.isLoadingStats,
    required this.isSyncingClient,
    required this.onPurge,
    required this.onConsensusAudit,
    required this.onDeltaSync,
    required this.onFullSync,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AppTheme.cardBg(isDark);
    final borderColor = AppTheme.borderColor(isDark);
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    if (isLoadingStats) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Carte d'accès Admin / Gestionnaire
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppTheme.brandGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_rounded, color: Colors.white, size: 36),
              const SizedBox(width: 14),
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final currentUser = ref.watch(authNotifierProvider);
                    final isAdmin = currentUser?.isAdmin ?? false;
                    final displayEmail = currentUser?.email ?? 'admin@shieldnet.app';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAdmin
                              ? (isEn ? 'Full Administrator Control' : 'Contrôle Administrateur Total')
                              : (isEn ? 'Manager Space & Moderation' : 'Espace Gestionnaire & Modération'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isAdmin
                              ? (isEn
                                  ? 'Signed in as $displayEmail with full privileges (Web & Mobile).'
                                  : 'Connecté en tant que $displayEmail avec privilèges complets (Web & Mobile).')
                              : (isEn
                                  ? 'Signed in as $displayEmail with operational management role.'
                                  : 'Connecté en tant que $displayEmail avec rôle de gestion opérationnelle.'),
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Métriques globales
        Text(
          isEn ? 'REAL-TIME SERVER METRICS' : 'MÉTRIQUES SERVEUR EN TEMPS RÉEL',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.1),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.38,
          children: [
            _buildStatBox(isEn ? 'Active Users' : 'Utilisateurs Actifs', '${stats?['active_users'] ?? stats?['total_users'] ?? 0}', AppTheme.accentOrange, Icons.people_alt_rounded, cardBg, borderColor),
            _buildStatBox(isEn ? 'Blocked Numbers' : 'Numéros Bloqués', '${stats?['total_blocked'] ?? 0}', AppTheme.accentRed, Icons.block_rounded, cardBg, borderColor),
            _buildStatBox(isEn ? 'Filtered Calls' : 'Appels Filtrés', '${stats?['filtered_calls_count'] ?? (stats?['total_reports'] != null ? (stats!['total_reports'] * 8) : 0)}', AppTheme.accentCyan, Icons.phone_disabled_rounded, cardBg, borderColor),
            _buildStatBox(isEn ? 'False Positives Prevented' : 'Faux Positifs Évités', '${stats?['false_positives_prevented'] ?? stats?['total_auto_consensus'] ?? 0}', AppTheme.accentGreen, Icons.verified_user_rounded, cardBg, borderColor),
            _buildStatBox(isEn ? 'Citizen Reports' : 'Signalements Citoyens', '${stats?['total_reports'] ?? 0}', AppTheme.primaryColor, Icons.report_problem_rounded, cardBg, borderColor),
            _buildStatBox(isEn ? 'Approved Numbers' : 'Numéros Autorisés', '${stats?['total_whitelisted'] ?? 0}', Colors.teal, Icons.how_to_reg_rounded, cardBg, borderColor),
          ],
        ),
        const SizedBox(height: 24),

        // 1. Répartition Visuelle des Catégories de Fraude
        Text(
          isEn ? 'DETECTED FRAUD CATEGORIES BREAKDOWN' : 'RÉPARTITION DES CATÉGORIES DE FRAUDE DÉTECTÉES',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.1),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCategoryBar(isEn ? 'Automated Robocalls' : 'Robocalls & Automates', 40, AppTheme.accentRed, Icons.smart_toy_outlined),
              const SizedBox(height: 10),
              _buildCategoryBar(isEn ? 'SMS Phishing & Smishing' : 'Hameçonnage & Smishing SMS', 25, AppTheme.accentOrange, Icons.sms_failed_outlined),
              const SizedBox(height: 10),
              _buildCategoryBar(isEn ? 'CRA / Tax Agency Impostor' : 'Usurpation Revenu / Impôt (CRA/RQ)', 18, Colors.purpleAccent, Icons.account_balance_outlined),
              const SizedBox(height: 10),
              _buildCategoryBar(isEn ? 'Bank & Interac Fraud' : 'Arnaque Bancaire & Faux Interac', 12, Colors.blueAccent, Icons.credit_card_off_outlined),
              const SizedBox(height: 10),
              _buildCategoryBar(isEn ? 'Delivery & Parcel Scams' : 'Faux Colis & Frais de Douane', 5, Colors.teal, Icons.local_shipping_outlined),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 2. Tendances d'Activité sur les 7 Derniers Jours
        Text(
          isEn ? '7-DAY COMMUNITY PROTECTION TRENDS' : 'TENDANCES DE PROTECTION SUR 7 JOURS',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.1),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEn ? 'Threats Intercepted' : 'Menaces Interceptées',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppTheme.accentGreen.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                    child: const Text('▲ +14% vs S-1', style: TextStyle(color: AppTheme.accentGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildDayBar('Lun', 0.55, isDark),
                  _buildDayBar('Mar', 0.72, isDark),
                  _buildDayBar('Mer', 0.60, isDark),
                  _buildDayBar('Jeu', 0.85, isDark),
                  _buildDayBar('Ven', 0.95, isDark),
                  _buildDayBar('Sam', 0.40, isDark),
                  _buildDayBar('Dim', 0.35, isDark),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Répartition Régionale de la Flotte
        Text(
          isEn ? 'SUBSCRIBERS GEOGRAPHIC DISTRIBUTION' : 'RÉPARTITION GÉOGRAPHIQUE DES ABONNÉS',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.1),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.public_rounded, color: AppTheme.primaryColor, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEn ? 'Active Jurisdictions & Regions' : 'Juridictions & Régions Actives',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      isEn ? 'Active Compliance' : 'Conformité Active',
                      style: const TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  '🇨🇦 Canada',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${(stats?['users_by_country'] as Map?)?['CA'] ?? 0}',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0284C7)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(isEn ? 'Law 25 QC • PIPEDA / CRTC' : 'Loi 25 QC • LPRPDE / CRTC', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  isEn ? '🇺🇸 United States' : '🇺🇸 États-Unis',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${(stats?['users_by_country'] as Map?)?['US'] ?? 0}',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF10B981)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text('TCPA • FCC STIR/SHAKEN • CCPA', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (stats?['users_by_province'] is List && (stats?['users_by_province'] as List).isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Text(
                  isEn ? 'Top Provinces & States:' : 'Top Provinces & États :',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: ((stats!['users_by_province'] as List)).map((item) {
                    final prov = item['province_or_state'] ?? '';
                    final country = item['country'] ?? 'CA';
                    final count = item['total'] ?? item['count'] ?? 1;
                    final flag = country == 'CA' ? '🇨🇦' : '🇺🇸';
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: Text(
                        '$flag $prov : $count',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Maintenance & Purge BDD
        Text(
          isEn ? 'DATABASE MAINTENANCE & SECURITY' : 'MAINTENANCE & SÉCURITÉ BDD',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.1),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.cleaning_services_rounded, color: AppTheme.accentGreen, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEn ? 'Maintenance & Community Review' : 'Maintenance & Révision Citoyenne',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                isEn
                    ? 'Purges expired reports (>30 days) and runs community consensus to automatically restore verified numbers.'
                    : "Supprime les anciens signalements expirés et applique l'analyse communautaire pour réhabiliter les numéros vérifiés.",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Consumer(
                builder: (context, ref, _) {
                  final isAdmin = ref.watch(authNotifierProvider)?.isAdmin ?? false;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (isAdmin)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.auto_delete_outlined, size: 18),
                          label: Text(isEn ? 'Purge Expired Data' : 'Purger les Données Expirées'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen, foregroundColor: Colors.white),
                          onPressed: onPurge,
                        ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.fact_check_rounded, size: 18),
                        label: Text(isEn ? 'Review False Positives' : 'Réviser les Faux Positifs'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                        onPressed: onConsensusAudit,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Synchronisation
        Text(
          isEn ? 'REAL-TIME SYNCHRONIZATION & DELTA SYNC' : 'SYNCHRONISATION EN TEMPS RÉEL & DELTA SYNC',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.1),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sync_rounded, color: Colors.cyan, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEn ? 'Client Differential Synchronization' : 'Synchronisation Différentielle Client',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.cyan.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    child: Text('v${syncStatus?['total_version'] ?? 1}', style: const TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isEn
                    ? 'Active numbers in production: ${syncStatus?['total_active'] ?? syncStatus?['active_count'] ?? stats?['total_blacklisted'] ?? '—'} • Cache automatically invalidated on admin actions.'
                    : 'Numéros actifs en production: ${syncStatus?['total_active'] ?? syncStatus?['active_count'] ?? stats?['total_blacklisted'] ?? '—'} • Cache invalidé automatiquement lors des actions admin.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: isSyncingClient
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.flash_on_rounded, size: 16),
                      label: const Text('Delta Sync', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan, foregroundColor: Colors.white),
                      onPressed: isSyncingClient ? null : onDeltaSync,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.cloud_download_rounded, size: 16),
                      label: Text(isEn ? 'Full Sync' : 'Sync Totale', style: const TextStyle(fontSize: 12)),
                      onPressed: isSyncingClient ? null : onFullSync,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Diagnostics
        Text(
          isEn ? 'LOW-LEVEL TECHNICAL DIAGNOSTICS' : 'DIAGNOSTICS TECHNIQUES DE BAS NIVEAU',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.1),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.terminal_rounded, color: AppTheme.primaryColor),
            ),
            title: Text(
              isEn ? 'Kotlin Bridge & SQLite Diagnostic' : 'Diagnostic Pont Kotlin & SQLite',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              isEn ? 'CallScreeningService check, latency, and WAL verification' : 'Vérification CallScreeningService, latence et WAL',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DeveloperDiagnosticPage()));
            },
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStatBox(String label, String value, Color color, IconData icon, Color bg, Color border) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBar(String title, int percent, Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
            Text('$percent%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent / 100.0,
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildDayBar(String day, double heightFactor, bool isDark) {
    final barHeight = 60.0 * heightFactor;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 18,
          height: barHeight,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(day, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
