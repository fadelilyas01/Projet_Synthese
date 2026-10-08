import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Carte valorisante présentant le bilan de tranquillité et de sérénité au quotidien.
/// Met en lumière de façon humaine et bienveillante le temps économisé,
/// les interruptions évitées et la priorité absolue donnée aux proches et aux urgences.
class PeaceOfMindSummaryCard extends StatelessWidget {
  final int interceptedCount;
  final bool isProtectionActive;

  const PeaceOfMindSummaryCard({
    super.key,
    required this.interceptedCount,
    required this.isProtectionActive,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AppTheme.cardBg(isDark);
    final borderColor = AppTheme.borderColor(isDark);
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    // Calcul valorisant et positif de tranquillité
    final estimatedMinutesSaved = (interceptedCount > 0 ? interceptedCount * 3 : 15);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête de la carte avec badge sérénité
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: AppTheme.accentGreen,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEn ? 'Daily Peace of Mind' : 'Votre Sérénité au Quotidien',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isProtectionActive
                            ? (isEn
                                ? 'Your attention and quiet time are protected'
                                : 'Votre temps et votre calme sont préservés')
                            : (isEn
                                ? 'Protection is paused. Tap shield to resume'
                                : 'Protection en pause. Touchez le bouclier pour reprendre'),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: (isProtectionActive ? AppTheme.accentGreen : Colors.grey)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isProtectionActive ? AppTheme.accentGreen : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isProtectionActive
                            ? (isEn ? 'Serene' : 'Serein')
                            : (isEn ? 'Paused' : 'En pause'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isProtectionActive ? AppTheme.accentGreen : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Encart valorisant : estimation du temps préservé
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          AppTheme.primaryColor.withValues(alpha: 0.15),
                          AppTheme.accentGreen.withValues(alpha: 0.12),
                        ]
                      : [
                          AppTheme.primaryColor.withValues(alpha: 0.06),
                          AppTheme.accentGreen.withValues(alpha: 0.08),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.accentGreen.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.access_time_filled_rounded,
                      color: AppTheme.accentGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEn
                              ? '~$estimatedMinutesSaved min of peaceful time saved'
                              : 'Environ $estimatedMinutesSaved min de tranquillité préservée',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isEn
                              ? 'No nuisance interruptions, zero scam stress'
                              : 'Aucun dérangement abusif, zéro stress téléphonique',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3 engagements concrets et rassurants
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                _buildCommitmentRow(
                  icon: Icons.people_alt_rounded,
                  iconColor: AppTheme.primaryColor,
                  title: isEn ? 'Your contacts always reach you' : 'Vos proches vous joignent toujours',
                  subtitle: isEn
                      ? 'Family, friends and work calls ring normally'
                      : 'Famille, amis et collègues sonnent sans aucun obstacle',
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _buildCommitmentRow(
                  icon: Icons.health_and_safety_rounded,
                  iconColor: Colors.teal,
                  title: isEn ? 'Essential emergency lines guaranteed' : 'Urgences 911 et 811 toujours garanties',
                  subtitle: isEn
                      ? 'Vital emergency assistance services are never filtered'
                      : 'Les secours et services de santé ne sont jamais bloqués',
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _buildCommitmentRow(
                  icon: Icons.lock_rounded,
                  iconColor: AppTheme.accentOrange,
                  title: isEn ? '100% Private on your device' : '100% Privé sur votre téléphone',
                  subtitle: isEn
                      ? 'Your address book and calls remain confidential'
                      : 'Votre carnet d\'adresses reste strictement chez vous',
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommitmentRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
