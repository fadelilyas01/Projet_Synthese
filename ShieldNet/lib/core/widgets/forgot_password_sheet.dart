import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../services/session_timeout_service.dart';
import '../theme/app_theme.dart';

/// Boîte de dialogue et modale de réinitialisation de mot de passe oublié avec OTP
class ForgotPasswordSheet extends ConsumerStatefulWidget {
  final String? initialEmail;
  final VoidCallback? onPasswordResetSuccess;

  const ForgotPasswordSheet({
    super.key,
    this.initialEmail,
    this.onPasswordResetSuccess,
  });

  /// Affiche la feuille de réinitialisation
  static void show(
    BuildContext context, {
    String? initialEmail,
    VoidCallback? onPasswordResetSuccess,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ForgotPasswordSheet(
        initialEmail: initialEmail,
        onPasswordResetSuccess: onPasswordResetSuccess,
      ),
    );
  }

  @override
  ConsumerState<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends ConsumerState<ForgotPasswordSheet> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _codeSent = false;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Étape 1 : Envoi du code de vérification par email
  Future<void> _handleSendOtp() async {
    final email = _emailController.text.trim();
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = isEn
            ? 'Please enter a valid email address.'
            : 'Veuillez renseigner une adresse courriel valide.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final msg = await ref.read(authNotifierProvider.notifier).sendPasswordResetOtp(email);
      if (mounted) {
        setState(() {
          _loading = false;
          _codeSent = true;
          _successMessage = msg.isNotEmpty
              ? msg
              : (isEn ? 'Verification code sent!' : 'Code de vérification envoyé à votre adresse.');
        });
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

  /// Étape 2 : Validation du code et enregistrement du nouveau mot de passe
  Future<void> _handleResetPassword() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    if (code.isEmpty || code.length < 4) {
      setState(() {
        _errorMessage = isEn
            ? 'Please enter the 6-digit code received.'
            : 'Veuillez saisir le code à 6 chiffres reçu.';
      });
      return;
    }

    if (newPassword.isEmpty || newPassword.length < 6) {
      setState(() {
        _errorMessage = isEn
            ? 'The password must be at least 6 characters long.'
            : 'Le mot de passe doit comporter au moins 6 caractères.';
      });
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        _errorMessage = isEn
            ? 'Passwords do not match.'
            : 'Les deux mots de passe ne correspondent pas.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authNotifierProvider.notifier).resetPasswordWithOtp(
            email: email,
            code: code,
            newPassword: newPassword,
          );

      // Déverrouiller immédiatement la session
      await SessionTimeoutService.instance.unlockSession();

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
                    isEn
                        ? 'New password saved! You are now reconnected.'
                        : 'Nouveau mot de passe enregistré ! Vous êtes reconnecté.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.accentGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        widget.onPasswordResetSuccess?.call();
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

            // En-tête
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEn ? 'Password Recovery' : 'Récupération du mot de passe',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _codeSent
                            ? (isEn
                                ? 'Enter the code received and choose your new password.'
                                : 'Saisissez le code reçu et définissez votre nouveau mot de passe.')
                            : (isEn
                                ? 'We will send a 6-digit verification code to your email.'
                                : 'Nous allons vous envoyer un code de vérification à 6 chiffres par courriel.'),
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
              const SizedBox(height: 14),
            ],

            // Message de succès
            if (_successMessage != null && _errorMessage == null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mark_email_read_outlined, color: AppTheme.accentGreen, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: const TextStyle(color: AppTheme.accentGreen, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Champ Email
            TextField(
              controller: _emailController,
              enabled: !_codeSent || !_loading,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: isEn ? 'Email Address' : 'Adresse courriel',
                prefixIcon: const Icon(Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),

            if (!_codeSent) ...[
              // Bouton Envoi OTP
              ElevatedButton.icon(
                onPressed: _loading ? null : _handleSendOtp,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  isEn ? 'Send Verification Code' : 'Envoyer le code de vérification',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ] else ...[
              // Étape 2 : Code OTP + Nouveau mot de passe
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: isEn ? '6-Digit Verification Code' : 'Code de vérification à 6 chiffres',
                  prefixIcon: const Icon(Icons.pin_outlined),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _newPasswordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: isEn ? 'New Password' : 'Nouveau mot de passe',
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
              const SizedBox(height: 12),

              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: isEn ? 'Confirm New Password' : 'Confirmer le nouveau mot de passe',
                  prefixIcon: const Icon(Icons.lock_reset_rounded),
                ),
              ),
              const SizedBox(height: 18),

              ElevatedButton.icon(
                onPressed: _loading ? null : _handleResetPassword,
                icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                label: Text(
                  isEn ? 'Save Password & Reconnect' : 'Enregistrer et se reconnecter',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 8),

              Center(
                child: TextButton.icon(
                  onPressed: _loading ? null : _handleSendOtp,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(
                    isEn ? 'Resend code' : 'Renvoyer un nouveau code',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
