import 'package:flutter/material.dart';
import '../../../../core/services/citizen_impact_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';

class CitizenImpactCard extends StatelessWidget {
  final CitizenImpactData data;
  final VoidCallback? onReportSpam;

  const CitizenImpactCard({
    super.key,
    required this.data,
    this.onReportSpam,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AppTheme.cardBg(isDark);
    final borderColor = AppTheme.borderColor(isDark);

    final isEn = (l10n?.localeName == 'en') || (Localizations.localeOf(context).languageCode == 'en');

    String localizeRank(String title) {
      if (title.contains('Niveau 1') || title.contains('Initial')) return l10n?.rankInitial ?? title;
      if (title.contains('Sentinelle') || title.contains('Sentinel') || title.contains('Niveau 2')) return l10n?.rankSentinel ?? title;
      if (title.contains('Protecteur') || title.contains('Guardian') || title.contains('Niveau 3')) return l10n?.rankGuardian ?? title;
      if (title.contains('Pilier') || title.contains('Pillar')) return l10n?.rankPillar ?? title;
      return title;
    }

    String localizeDescription(String id, String defaultDesc) {
      if (!isEn) return defaultDesc;
      switch (id) {
        case 'vigie':
          return 'Submitted their first report to enrich the shared threat database.';
        case 'sentinelle':
          return 'Shared at least 5 confirmed reports.';
        case 'gardien':
          return 'Over 10 validated reports confirmed by community consensus.';
        default:
          return defaultDesc;
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentOrange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.people_alt_rounded, color: AppTheme.accentOrange, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n?.citizenImpactTitle ?? 'Signalements communautaires',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            l10n?.citizenImpactSub ?? 'Partage de signalements',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: data.currentRank.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: data.currentRank.color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(data.currentRank.icon, size: 14, color: data.currentRank.color),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          localizeRank(data.currentRank.title),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: data.currentRank.color),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Compteur estimé
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.favorite_rounded, color: AppTheme.accentRed, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n?.citizenProtectedCount(data.protectedCitizensEstimate) ?? '~${data.protectedCitizensEstimate} concitoyens protégés',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.reportsCount == 0
                            ? (l10n?.citizenReportToProtect ?? 'Signalez un spam pour protéger les autres utilisateurs.')
                            : (l10n?.citizenThanksReports(data.reportsCount) ?? 'Grâce à vos ${data.reportsCount} signalement(s) validé(s).'),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Ligne des badges
          Row(
            children: data.allBadges.map((badge) {
              final badgeTitle = localizeRank(badge.title);
              return Expanded(
                child: Tooltip(
                  message: '$badgeTitle : ${localizeDescription(badge.id, badge.description)}',
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: badge.isUnlocked
                          ? badge.color.withValues(alpha: 0.12)
                          : Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: badge.isUnlocked ? badge.color.withValues(alpha: 0.4) : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          badge.icon,
                          size: 20,
                          color: badge.isUnlocked ? badge.color : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          badgeTitle,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: badge.isUnlocked ? FontWeight.bold : FontWeight.normal,
                            color: badge.isUnlocked ? badge.color : Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
