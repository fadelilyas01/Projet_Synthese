import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../services/biometric_service.dart';
import '../services/google_sign_in_service.dart';
import '../theme/app_theme.dart';
import 'app_logo.dart';
import 'google_logo.dart';
import 'biometric_enrollment_sheet.dart';
import '../../features/settings/presentation/widgets/auth_bottom_sheet.dart';

/// Verrou d'Authentification (Auth Gate Pattern) avec support de la Protection Biométrique (Face ID / Empreinte)
class AuthGate extends ConsumerStatefulWidget {
  final Widget child;

  const AuthGate({super.key, required this.child});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  final BiometricService _biometricService = BiometricService();
  bool _isBiometricUnlocked = false;
  bool _isCheckingBiometrics = true;

  @override
  void initState() {
    super.initState();
    _checkBiometricRequirement();
  }

  Future<void> _checkBiometricRequirement() async {
    final enabled = await _biometricService.isBiometricEnabled();
    if (!enabled) {
      if (mounted) {
        setState(() {
          _isBiometricUnlocked = true;
          _isCheckingBiometrics = false;
        });
      }
      return;
    }

    // Si la protection biométrique est activée en paramètres, exiger la vérification
    final authenticated = await _biometricService.authenticate(
      reason: 'Authentifiez-vous par biométrie pour déverrouiller ShieldNet',
    );

    if (mounted) {
      setState(() {
        _isBiometricUnlocked = authenticated;
        _isCheckingBiometrics = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider);

    // 1. Si pas d'utilisateur connecté, afficher l'écran d'accueil d'authentification épuré
    if (user == null) {
      return const AuthLockPage();
    }

    // 2. Si l'utilisateur est connecté mais que la vérification biométrique est en cours
    if (_isCheckingBiometrics) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Si verrouillé par biométrie activée par l'utilisateur
    if (!_isBiometricUnlocked) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const ShieldNetLogo(size: 76),
                const SizedBox(height: 24),
                Text(
                  'ShieldNet Verrouillé',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Confirmez votre identité pour déverrouiller vos protections.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _checkBiometricRequirement,
                  icon: const Icon(Icons.fingerprint_rounded, size: 24),
                  label: const Text('Déverrouiller avec Face ID / Empreinte'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 3. Accès autorisé
    return widget.child;
  }
}

/// Écran de connexion épuré et moderne (Sans biométrie prématurée, avec accès direct et sans redondance)
class AuthLockPage extends ConsumerStatefulWidget {
  const AuthLockPage({super.key});

  @override
  ConsumerState<AuthLockPage> createState() => _AuthLockPageState();
}

class _AuthLockPageState extends ConsumerState<AuthLockPage> {
  bool _isGoogleLoading = false;

  void _openAuthModal(BuildContext context, {bool initialRegister = false}) {
    AuthBottomSheet.show(context, initialRegister: initialRegister);
  }

  Future<void> _handleDirectGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    try {
      final googleService = GoogleSignInService();
      final result = await googleService.signInWithGoogle();

      if (result.success && result.user != null) {
        await ref.read(authNotifierProvider.notifier).checkCurrentUser();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white),
                  SizedBox(width: 10),
                  Text('Connexion Google réussie !', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              backgroundColor: AppTheme.accentGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );

          // Proposer discrètement l'activation de la biométrie pour la prochaine fois
          BiometricEnrollmentSheet.showIfEligible(context);
        }
      } else if (result.errorMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage!),
            backgroundColor: AppTheme.accentOrange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentLocale = ref.watch(localeProvider);
    final isEn = currentLocale.languageCode == 'en';

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const Spacer(flex: 3),

              // Logo & Identité visuelle épurée
              Hero(
                tag: 'shieldnet_logo_auth',
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const ShieldNetLogo(size: 72),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'ShieldNet',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isEn
                    ? 'AI Telecom Shield & Anti-Spam Protection'
                    : 'Bouclier Télécom IA & Protection Anti-Spam',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                ),
              ),

              const Spacer(flex: 4),

              // 1. Bouton Connexion Google Direct (sans formulaires ni questions en double)
              SizedBox(
                height: 52,
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isGoogleLoading ? null : _handleDirectGoogleSignIn,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isDark ? Colors.white24 : Colors.black12,
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    backgroundColor: isDark ? AppTheme.cardBg(true) : Colors.white,
                  ),
                  child: _isGoogleLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const GoogleLogo(size: 22),
                            const SizedBox(width: 12),
                            Text(
                              isEn ? 'Continue with Google' : 'Continuer avec Google',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // 2. Bouton Connexion par Courriel
              ElevatedButton.icon(
                onPressed: () => _openAuthModal(context, initialRegister: false),
                icon: const Icon(Icons.mail_outline_rounded, size: 20),
                label: Text(
                  isEn ? 'Sign in with Email' : 'Se connecter avec un courriel',
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
              const SizedBox(height: 16),

              // 3. Inscription rapide (ouvre directement le mode Inscription sans questions en double)
              TextButton(
                onPressed: () => _openAuthModal(context, initialRegister: true),
                child: Text.rich(
                  TextSpan(
                    text: isEn ? "Don't have an account? " : "Nouveau sur ShieldNet ? ",
                    style: TextStyle(
                      color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                      fontSize: 13,
                    ),
                    children: [
                      TextSpan(
                        text: isEn ? 'Create an account' : 'Créer un compte',
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 1),

              // Mention de sécurité et confidentialité discrète
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      isEn ? 'Confidential & Secure' : 'Confidentiel et sécurisé',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  },
),
      ),
    );
  }
}
