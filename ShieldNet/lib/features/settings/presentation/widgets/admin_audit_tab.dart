import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Onglet journal d'audit avec traçabilité des actions Web & Mobile
class AdminAuditTab extends StatelessWidget {
  final List<Map<String, dynamic>> auditLogs;
  final bool isLoading;
  final VoidCallback onRefresh;

  const AdminAuditTab({
    super.key,
    required this.auditLogs,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AppTheme.cardBg(isDark);
    final borderColor = AppTheme.borderColor(isDark);
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (auditLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              isEn ? 'No audit events recorded.' : 'Aucun événement d\'audit enregistré.',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: auditLogs.length,
        separatorBuilder: (_, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _buildAuditLogCard(auditLogs[index], cardBg, borderColor, isEn),
      ),
    );
  }

  Widget _buildAuditLogCard(Map<String, dynamic> log, Color cardBg, Color borderColor, bool isEn) {
    final action = log['action'] as String? ?? '';
    final source = log['source'] as String? ?? 'web';
    final username = (log['username'] ?? log['user_username']) as String? ?? (isEn ? 'System' : 'Système');
    final targetHash = log['target_hash'] as String? ?? '';
    final createdAt = log['created_at'] as String? ?? '';
    final details = log['details'];

    Color actionColor = AppTheme.primaryColor;
    IconData actionIcon = Icons.info_outline_rounded;
    String actionLabel = action;

    if (action.contains('BLOCK') && !action.contains('UNBLOCK')) {
      actionColor = AppTheme.accentRed;
      actionIcon = Icons.block_rounded;
      actionLabel = isEn ? 'Number Blocked' : 'Blocage de numéro';
    } else if (action.contains('UNBLOCK') || action.contains('WHITELIST')) {
      actionColor = AppTheme.accentGreen;
      actionIcon = Icons.check_circle_outline_rounded;
      actionLabel = isEn ? 'Unblocked / Approved' : 'Autorisation / Déblocage';
    } else if (action.contains('PURGE')) {
      actionColor = Colors.purple;
      actionIcon = Icons.auto_delete_rounded;
      actionLabel = isEn ? 'Database Maintenance Purge' : 'Purge Maintenance BDD';
    } else if (action.contains('APPROVE')) {
      actionColor = AppTheme.accentOrange;
      actionIcon = Icons.verified_user_rounded;
      actionLabel = isEn ? 'Report Approved' : 'Signalement Validé';
    } else if (action.contains('REJECT')) {
      actionColor = Colors.grey;
      actionIcon = Icons.cancel_outlined;
      actionLabel = isEn ? 'Report Rejected' : 'Signalement Rejeté';
    }

    final isWeb = source.toLowerCase() == 'web';

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: actionColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(actionIcon, color: actionColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        actionLabel,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: actionColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${isEn ? "By" : "Par"} $username • ${createdAt.length > 19 ? createdAt.substring(0, 19).replaceAll("T", " ") : createdAt}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isWeb ? Colors.blue.withValues(alpha: 0.12) : AppTheme.accentOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isWeb ? Icons.language_rounded : Icons.smartphone_rounded,
                        size: 13,
                        color: isWeb ? Colors.blue : AppTheme.accentOrange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isWeb ? 'WEB ADMIN' : 'MOBILE APP',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isWeb ? Colors.blue : AppTheme.accentOrange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (targetHash.isNotEmpty || (details != null && details.toString() != '{}')) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              if (targetHash.isNotEmpty)
                Text(
                  '${isEn ? "Target (Hash)" : "Cible (Hash)"}: ${targetHash.length >= 16 ? "${targetHash.substring(0, 16)}..." : targetHash}',
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.grey),
                ),
              if (details != null && details.toString() != '{}')
                Text(
                  '${isEn ? "Details" : "Détails"}: $details',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
