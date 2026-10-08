import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/regional_compliance_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/google_sign_in_button.dart';
import '../pages/admin_console_page.dart';

/// Boîte de dialogue et modale d'authentification unifiée (Utilisateurs & Administrateurs)
class AuthBottomSheet extends ConsumerStatefulWidget {
  final bool initialAdmin;

  const AuthBottomSheet({
    super.key,
    this.initialAdmin = false,
  });

  /// Ouvre la modale de connexion unifiée
  static void show(BuildContext context, {bool initialAdmin = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AuthBottomSheet(initialAdmin: initialAdmin),
    );
  }

  @override
  ConsumerState<AuthBottomSheet> createState() => _AuthBottomSheetState();
}

class _AuthBottomSheetState extends ConsumerState<AuthBottomSheet> {
  bool _isLogin = true;
  bool _obscurePassword = true;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _loading = false;
  String? _errorMessage;

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
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
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
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminConsolePage()),
          );
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
    final emailController = TextEditingController();
    final nameController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.account_circle_outlined, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(isEn ? 'Google Sign-In' : 'Connexion Google'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEn
                  ? 'Simulate sign in with your Google account:'
                  : 'Simulez la connexion avec votre compte Google :',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: isEn ? 'Google Email' : 'Email Google',
                hintText: 'user@gmail.com',
                prefixIcon: const Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: isEn ? 'Full Name (optional)' : 'Nom complet (optionnel)',
                hintText: 'John Doe',
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isEn ? 'Cancel' : 'Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (emailController.text.trim().isNotEmpty) {
                Navigator.pop(ctx, true);
              }
            },
            child: Text(isEn ? 'Continue' : 'Continuer'),
          ),
        ],
      ),
    );

    if (result == true && emailController.text.trim().isNotEmpty) {
      await _performGoogleLogin(
        emailController.text.trim(),
        name: nameController.text.trim().isNotEmpty ? nameController.text.trim() : null,
      );
    }
  }

  Future<void> _performGoogleLogin(String email, {String? name}) async {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authNotifierProvider.notifier).googleLogin(email, name: name);
      final user = ref.read(authNotifierProvider);
      final isAdmin = user != null && user.canModerate;

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAdmin
                  ? (isEn ? 'Welcome to the administration console!' : 'Bienvenue dans la console d\'administration !')
                  : (isEn ? 'Connected with Google!' : 'Connecté avec Google !'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppTheme.accentGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        if (isAdmin) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminConsolePage()),
          );
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
                                ? 'Sign in to access your account.'
                                : 'Connectez-vous pour accéder à votre espace.')
                            : (isEn
                                ? 'Create your account to join ShieldNet.'
                                : 'Créez votre compte pour rejoindre ShieldNet.'),
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
            const SizedBox(height: 20),

            // Bouton Google
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

            const SizedBox(height: 20),

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
          ],
        ),
      ),
    );
  }
}
