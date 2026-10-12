import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';

/// Carte principale de statut et de contrôle de la protection télécom
/// Design épuré, sobre et fonctionnel (Standard Signal & Google Phone)
class ZenShieldCard extends StatelessWidget {
  final bool isActive;
  final bool isContactsOnly;
  final bool isNightWindow;
  final VoidCallback onToggleProtection;
  final VoidCallback onActivateProtection;

  const ZenShieldCard({
    super.key,
    required this.isActive,
    required this.isContactsOnly,
    required this.isNightWindow,
    required this.onToggleProtection,
    required this.onActivateProtection,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    final statusColor = isActive
        ? (isContactsOnly ? AppTheme.accentOrange : AppTheme.accentGreen)
        : AppTheme.accentRed;

    final titleText = isActive
        ? (isContactsOnly
            ? (l10n?.shieldStrictTitle ?? (isEn ? 'Strict Protection' : 'Protection Contacts Seuls'))
            : (l10n?.shieldProtected ?? (isEn ? 'You are protected' : 'Protection active')))
        : (l10n?.shieldInactive ?? (isEn ? 'Protection inactive' : 'Protection suspendue'));

    final descText = isActive
        ? (isContactsOnly
            ? (l10n?.shieldStrictDesc ?? (isEn ? 'Only your saved contacts are allowed to ring.' : 'Seuls vos contacts enregistrés sont autorisés à sonner.'))
            : (l10n?.shieldActiveDesc ?? (isEn ? 'ShieldNet automatically filters malicious calls.' : 'Les spams et numéros malveillants sont bloqués sans sonnerie.')))
        : (l10n?.shieldInactiveDesc ?? (isEn ? 'Enable filtering to block unwanted calls.' : 'Activez le filtrage pour rejeter automatiquement les appels frauduleux.'));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? statusColor.withValues(alpha: 0.3)
              : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
          width: isActive ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ligne principale : Statut, Libellé et Commutateur Switch
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Indicateur visuel d'état
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isActive
                      ? (isContactsOnly ? Icons.verified_user_rounded : Icons.shield_rounded)
                      : Icons.shield_outlined,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),

              // Titre et sous-titre
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            titleText,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isActive
                          ? (isEn ? 'Automatic protection active' : 'Protection automatique active')
                          : (isEn ? 'Protection paused' : 'Protection en pause'),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Commutateur interactif rapide
              Transform.scale(
                scale: 0.85,
                child: Switch.adaptive(
                  value: isActive,
                  activeTrackColor: AppTheme.accentGreen,
                  onChanged: (val) {
                    HapticFeedback.mediumImpact();
                    if (!isActive) {
                      onActivateProtection();
                    } else {
                      onToggleProtection();
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Description détaillée
          Text(
            descText,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
            ),
          ),

          // Badges d'options actives (Mode Nuit, Contacts Uniquement)
          if (isNightWindow || isContactsOnly) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (isNightWindow)
                  _buildStatusChip(
                    icon: Icons.bedtime_rounded,
                    label: l10n?.nightShieldActiveBadge ?? 'Bouclier Nocturne actif',
                    color: AppTheme.primaryColor,
                    isDark: isDark,
                  ),
                if (isContactsOnly)
                  _buildStatusChip(
                    icon: Icons.contacts_rounded,
                    label: l10n?.settingContactsOnly ?? 'Mode Contacts Uniquement',
                    color: AppTheme.accentOrange,
                    isDark: isDark,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
