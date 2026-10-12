import 'package:flutter/material.dart';
import '../../../../core/security/device_integrity_checker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';

/// Bandeau d'alerte informant l'utilisateur en cas de détection d'accès Root / Super-Utilisateur
class DeviceIntegrityBanner extends StatelessWidget {
  final DeviceIntegrityResult result;

  const DeviceIntegrityBanner({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    if (!result.isCompromised) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentRed, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accentRed.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.gpp_maybe_rounded,
              color: AppTheme.accentRed,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.deviceIntegrityRooted ?? 'Sécurité : Appareil modifié',
                  style: const TextStyle(
                    color: AppTheme.accentRed,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n?.deviceIntegrityDesc ??
                      'Votre appareil a été modifié ou déverrouillé. Certaines protections du système Android peuvent être affaiblies.',
                  style: const TextStyle(fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
