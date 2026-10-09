import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/regional_compliance_service.dart';
import '../../../../core/services/google_sign_in_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/google_sign_in_button.dart';
import '../../../../core/widgets/biometric_enrollment_sheet.dart';
import '../../../../core/widgets/forgot_password_sheet.dart';
import '../pages/admin_console_page.dart';

/// Boîte de dialogue et modale d'authentification unifiée (Utilisateurs & Administrateurs)
class AuthBottomSheet extends ConsumerStatefulWidget {
  final bool initialAdmin;
  final bool initialRegister;

  const AuthBottomSheet({
    super.key,
    this.initialAdmin = false,
    this.initialRegister = false,
  });

  /// Ouvre la modale de connexion unifiée
  static void show(BuildContext context, {bool initialAdmin = false, bool initialRegister = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AuthBottomSheet(
        initialAdmin: initialAdmin,
        initialRegister: initialRegister,
      ),
    );
  }

  @override
  ConsumerState<AuthBottomSheet> createState() => _AuthBottomSheetState();
}

class _AuthBottomSheetState extends ConsumerState<AuthBottomSheet> {
  late bool _isLogin;
  bool _obscurePassword = true;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _isLogin = !widget.initialRegister;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = isEn
          ? 'Please enter both email and password.'
          : "Veuillez renseigner votre email et votre mot de passe.");
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      if (_isLogin) {
        await ref.read(authNotifierProvider.notifier).login(email, password);
      } else {
        final currentRegion = ref.read(regionalComplianceProvider);
        await ref.read(authNotifierProvider.notifier).register(
          email,
          password,
          name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
          country: currentRegion.country,
          provinceOrState: currentRegion.provinceOrState,
        );
      }

      final user = ref.read(authNotifierProvider);
      final isAdmin = user != null && user.canModerate;

      if (mounted) {
        navigator.pop();

        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isAdmin
                        ? (isEn ? 'Welcome to the administration console!' : 'Bienvenue dans la console d\'administration !')
                        : (_isLogin
                            ? (isEn ? 'Welcome back! Signed in successfully.' : 'Ravi de vous revoir ! Connexion réussie.')
                            : (isEn ? 'Account created! Welcome to ShieldNet.' : 'Compte créé avec succès ! Bienvenue sur ShieldNet.')),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.accentGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        if (isAdmin) {
          navigator.push(
            MaterialPageRoute(builder: (_) => const AdminConsolePage()),
          );
        } else {
          BiometricEnrollmentSheet.showIfEligible(navigator.context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final googleService = GoogleSignInService();
      final result = await googleService.signInWithGoogle();

      if (result.success && result.user != null) {
        await ref.read(authNotifierProvider.notifier).checkCurrentUser();
        final user = ref.read(authNotifierProvider);
        final isAdmin = user != null && user.canModerate;

        if (mounted) {
          navigator.pop();

          messenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isAdmin
                          ? (isEn ? 'Welcome to the administration console!' : 'Bienvenue dans la console d\'administration !')
                          : (isEn ? 'Signed in with Google!' : 'Connexion Google réussie !'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.accentGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );

          if (isAdmin) {
            navigator.push(
              MaterialPageRoute(builder: (_) => const AdminConsolePage()),
            );
          } else {
            BiometricEnrollmentSheet.showIfEligible(navigator.context);
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _loading = false;
            _errorMessage = result.errorMessage;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = AppTheme.borderColor(isDark);
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barre de préhension
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // En-tête unique
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isLogin
                            ? (isEn ? 'Welcome Back!' : 'Connexion')
                            : (isEn ? 'Create an Account' : 'Créer un compte'),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isLogin
                            ? (isEn
                                ? 'Sign in to access your protected numbers and settings.'
                                : 'Connectez-vous pour retrouver vos numéros protégés et réglages.')
                            : (isEn
                                ? 'Set up your account in seconds with complete privacy.'
                                : 'Protégez vos appels en toute simplicité et confidentialité.'),
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Encadré d'information clair et rassurant
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.12 : 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.25 : 0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_user_outlined, color: AppTheme.primaryColor, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _isLogin
                            ? (isEn ? 'Your account, your peace of mind' : 'Votre compte, votre sérénité')
                            : (isEn ? 'Why create a ShieldNet account?' : 'Pourquoi créer un compte ?'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildBenefitRow(
                    icon: Icons.sync_rounded,
                    title: isEn ? 'Secure cloud backup' : 'Sauvegarde sécurisée',
                    desc: isEn
                        ? 'Keep your blocked numbers & settings synced across devices.'
                        : 'Retrouvez vos préférences et numéros bloqués sur tous vos appareils.',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 6),
                  _buildBenefitRow(
                    icon: Icons.lock_outline_rounded,
                    title: isEn ? 'Strict privacy' : 'Confidentialité totale',
                    desc: isEn
                        ? 'Your address book and private calls are never shared with anyone.'
                        : 'Vos contacts et vos appels personnels ne sont jamais partagés.',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 6),
                  _buildBenefitRow(
                    icon: Icons.offline_bolt_outlined,
                    title: isEn ? 'Instant protection' : 'Protection instantanée',
                    desc: isEn
                        ? 'No complex setup required. ShieldNet protects your line quietly.'
                        : 'Votre téléphone veille sur vous sans interrompre vos proches.',
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Bouton Google officiel
            GoogleSignInButton(
              isLoading: _loading,
              onPressed: _loading ? null : _handleGoogleSignIn,
            ),
            const SizedBox(height: 18),

            // Séparateur épuré
            Row(
              children: [
                Expanded(child: Divider(color: borderColor)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    isEn ? 'OR WITH EMAIL' : 'OU AVEC EMAIL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: borderColor)),
              ],
            ),
            const SizedBox(height: 18),

            // Message d'erreur
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppTheme.accentRed, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppTheme.accentRed, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Champ Nom (si inscription)
            if (!_isLogin) ...[
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: isEn ? 'Your Name or Nickname' : 'Votre Nom ou Pseudo',
                  hintText: isEn ? 'e.g. Alex' : 'ex. Alexandre',
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Champ Email
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: isEn ? 'Email Address' : 'Adresse Email',
                hintText: 'alexandre@exemple.com',
                prefixIcon: const Icon(Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),

            // Champ Mot de passe
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: isEn ? 'Password' : 'Mot de passe',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),

            if (_isLogin) ...[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    ForgotPasswordSheet.show(
                      context,
                      initialEmail: _emailController.text.trim(),
                    );
                  },
                  child: Text(
                    isEn ? 'Forgot password?' : 'Mot de passe oublié ?',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 8),

            // Bouton Principal de Soumission
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_isLogin ? Icons.lock_open_rounded : Icons.person_add_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _isLogin
                              ? (isEn ? 'Sign In' : 'Se connecter')
                              : (isEn ? 'Create Account' : 'Créer un compte'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => setState(() {
                  _isLogin = !_isLogin;
                  _errorMessage = null;
                }),
                child: Text(
                  _isLogin
                      ? (isEn ? "Don't have an account? Sign Up" : "Nouveau sur ShieldNet ? Créer un compte")
                      : (isEn ? 'Already have an account? Sign In' : 'Déjà un compte ? Se connecter'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Mention rassurante de confidentialité
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield_outlined, size: 13, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  isEn
                      ? 'Strict privacy protection • Zero data sold'
                      : 'Respect de la vie privée • Zéro partage de vos données',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitRow({
    required IconData icon,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 14, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
              ),
              children: [
                TextSpan(
                  text: '$title : ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
