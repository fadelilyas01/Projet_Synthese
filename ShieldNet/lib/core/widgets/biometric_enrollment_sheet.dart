import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/biometric_service.dart';
import '../theme/app_theme.dart';

/// Modale d'activation biométrique post-authentification de niveau entreprise
class BiometricEnrollmentSheet extends StatefulWidget {
  final VoidCallback? onCompleted;

  const BiometricEnrollmentSheet({super.key, this.onCompleted});

  /// Affiche la proposition d'activation biométrique si l'appareil est compatible
  /// et si l'utilisateur n'a pas encore répondu.
  static Future<void> showIfEligible(BuildContext context, {VoidCallback? onCompleted}) async {
    final biometricService = BiometricService();
    final isAvailable = await biometricService.isBiometricsAvailable();
    if (!isAvailable) {
      onCompleted?.call();
      return;
    }

    final isAlreadyEnabled = await biometricService.isBiometricEnabled();
    if (isAlreadyEnabled) {
      onCompleted?.call();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final hasPrompted = prefs.getBool('shieldnet_biometric_enrolled_prompted') ?? false;
    if (hasPrompted) {
      onCompleted?.call();
      return;
    }

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BiometricEnrollmentSheet(onCompleted: onCompleted),
    );
  }

  @override
  State<BiometricEnrollmentSheet> createState() => _BiometricEnrollmentSheetState();
}

class _BiometricEnrollmentSheetState extends State<BiometricEnrollmentSheet> {
  final BiometricService _biometricService = BiometricService();
  bool _isLoading = false;

  Future<void> _enableBiometrics() async {
    setState(() => _isLoading = true);
    final authenticated = await _biometricService.authenticate(
      reason: 'Confirmez votre empreinte ou Face ID pour activer le déverrouillage ShieldNet',
    );

    if (authenticated) {
      await _biometricService.setBiometricEnabled(true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('shieldnet_biometric_enrolled_prompted', true);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.fingerprint_rounded, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Protection biométrique activée avec succès !',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.accentGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        widget.onCompleted?.call();
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _skipForNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('shieldnet_biometric_enrolled_prompted', true);

    if (mounted) {
      Navigator.pop(context);
      widget.onCompleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Poignée
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Badge visuel sécurité d'entreprise
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.fingerprint_rounded,
              size: 52,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 20),

          // Titre
          Text(
            'Activer la protection biométrique',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
              color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),

          // Description claire et professionnelle
          Text(
            'Déverrouillez ShieldNet instantanément avec Face ID ou votre empreinte digitale lors de vos prochaines visites, sans avoir à ressaisir vos identifiants.',
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // Bouton 1 : Activer maintenant
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _enableBiometrics,
            icon: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.security_rounded, size: 20),
            label: Text(
              _isLoading ? 'Activation en cours...' : 'Activer maintenant',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),

          // Bouton 2 : Plus tard
          TextButton(
            onPressed: _isLoading ? null : _skipForNow,
            child: Text(
              'Plus tard',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
