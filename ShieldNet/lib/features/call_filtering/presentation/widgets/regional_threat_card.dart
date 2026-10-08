import 'package:flutter/material.dart';
import '../../../../core/models/regional_threat.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';

/// Carte d'alerte et de veille sur les menaces téléphoniques régionales ciblées (Spoofing)
class RegionalThreatCard extends StatelessWidget {
  final RegionalThreatSummary summary;

  const RegionalThreatCard({
    super.key,
    required this.summary,
  });

  String _formatAlertLevel(String level, bool isEn) {
    final upper = level.toUpperCase();
    if (upper.contains('CRITIQUE') || upper.contains('CRITICAL')) {
      return isEn ? 'CRITICAL' : 'CRITIQUE';
    } else if (upper.contains('ÉLEVÉ') || upper.contains('ELEVE') || upper.contains('HIGH')) {
      return isEn ? 'HIGH' : 'ÉLEVÉ';
    } else {
      return isEn ? 'MODERATE' : 'MODÉRÉ';
    }
  }

  String _formatCategory(String cat, bool isEn) {
    final lower = cat.toLowerCase();
    if (lower.contains('fraud') || lower.contains('arnaque')) {
      return isEn ? 'Fraud' : 'Arnaque';
    } else if (lower.contains('telemarketing') || lower.contains('démarchage') || lower.contains('demarchage')) {
      return isEn ? 'Telemarketing' : 'Démarchage';
    } else if (lower.contains('phishing') || lower.contains('hameçonnage')) {
      return isEn ? 'Phishing' : 'Hameçonnage';
    } else if (lower.contains('robocall') || lower.contains('automate')) {
      return isEn ? 'Robocall' : 'Automate';
    }
    return cat;
  }

  void _showDetailsBottomSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.radar_rounded, color: AppTheme.accentOrange, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n?.regionalRadarTitle ?? (isEn ? 'Regional Scam Radar' : 'Radar Régional des Arnaques'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n?.regionalRadarDesc ??
                    (isEn
                        ? 'Real-time analysis of targeted spoofing waves by North American area codes (Canada / US).'
                        : 'Analyse en temps réel des vagues d\'usurpation d\'identité (Spoofing) ciblées par indicatif québécois et canadien.'),
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: summary.regions.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final item = summary.regions[index];
                    final isCritical = item.isCritical;
                    final isHigh = item.isHigh;
                    final badgeColor = isCritical
                        ? AppTheme.accentRed
                        : (isHigh ? AppTheme.accentOrange : AppTheme.accentGreen);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item.areaCode,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: badgeColor,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      title: Text(
                        item.regionName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        '${item.totalSpams} ${l10n?.regionalReportsCount ?? (isEn ? "reports • Type:" : "signalements • Type :")} ${_formatCategory(item.topCategory, isEn)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: badgeColor, width: 1),
                        ),
                        child: Text(
                          _formatAlertLevel(item.alertLevel, isEn),
                          style: TextStyle(
                            color: badgeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(l10n?.btnUnderstood ?? 'Compris', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final highest = summary.highestAlert;
    if (highest == null) return const SizedBox.shrink();

    final isCritical = highest.isCritical;
    final isHigh = highest.isHigh;
    final alertColor = isCritical
        ? AppTheme.accentRed
        : (isHigh ? AppTheme.accentOrange : AppTheme.primaryColor);

    return InkWell(
      onTap: () => _showDetailsBottomSheet(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: alertColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: alertColor.withValues(alpha: 0.35), width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: alertColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCritical ? Icons.warning_amber_rounded : Icons.cell_tower_rounded,
                color: alertColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${l10n?.regionalAlertPrefix ?? "Alerte Indicatif"} (${highest.areaCode})',
                          style: TextStyle(
                            color: alertColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: alertColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          highest.alertLevel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n?.regionalWaveDesc(highest.regionName) ?? 'Vague active d\'appels frauduleux ciblant la région : ${highest.regionName}.',
                    style: const TextStyle(fontSize: 12, height: 1.3),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
