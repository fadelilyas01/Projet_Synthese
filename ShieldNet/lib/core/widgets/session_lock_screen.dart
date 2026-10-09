import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/session_timeout_service.dart';
import '../theme/app_theme.dart';
import 'app_logo.dart';
import 'forgot_password_sheet.dart';

/// Écran de reverrouillage de session après inactivité de plus de 5 minutes
/// Supporte le déverrouillage prioritaire par biométrie (Face ID / Empreinte),
/// le déverrouillage par mot de passe en cas d'échec, et la récupération de mot de passe oublié.
class SessionLockScreen extends ConsumerStatefulWidget {
  final UserModel user;
  final VoidCallback onUnlocked;

  const SessionLockScreen({
    super.key,
    required this.user,
    required this.onUnlocked,
  });

  @override
  ConsumerState<SessionLockScreen> createState() => _SessionLockScreenState();
}

class _SessionLockScreenState extends ConsumerState<SessionLockScreen> {
  final BiometricService _biometricService = BiometricService();
  final TextEditingController _passwordController = TextEditingController();

  bool _isBiometricsAvailable = false;
  bool _isAuthenticatingBiometrics = false;
  bool _isLoadingPassword = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkBiometricsAndPrompt();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  /// Détecte la biométrie et propose automatiquement l'authentification au lancement
  Future<void> _checkBiometricsAndPrompt() async {
    final available = await _biometricService.isBiometricsAvailable();
    if (mounted) {
      setState(() => _isBiometricsAvailable = available);
    }

    if (available) {
      _authenticateWithBiometrics();
    }
  }

  /// Authentification biométrique (Face ID / Empreinte)
  Future<void> _authenticateWithBiometrics() async {
    if (_isAuthenticatingBiometrics) return;
    setState(() {
      _isAuthenticatingBiometrics = true;
      _errorMessage = null;
    });

    try {
      final success = await _biometricService.authenticate(
        reason: 'Confirmez votre identité pour déverrouiller ShieldNet',
      );

      if (success) {
        await SessionTimeoutService.instance.unlockSession();
        if (mounted) {
          widget.onUnlocked();
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Authentification biométrique non reconnue. Utilisez votre mot de passe.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur biométrique. Veuillez saisir votre mot de passe.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isAuthenticatingBiometrics = false);
      }
    }
  }

  /// Déverrouillage alternatif par mot de passe
  Future<void> _unlockWithPassword() async {
    final password = _passwordController.text.trim();
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    if (password.isEmpty) {
      setState(() {
        _errorMessage = isEn ? 'Please enter your password.' : 'Veuillez saisir votre mot de passe.';
      });
      return;
    }

    setState(() {
      _isLoadingPassword = true;
      _errorMessage = null;
    });

    try {
      // Re-valider les identifiants avec le compte connecté
      await ref.read(authNotifierProvider.notifier).login(widget.user.email, password);
      await SessionTimeoutService.instance.unlockSession();

      if (mounted) {
        widget.onUnlocked();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPassword = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  /// Ouvre la modale de réinitialisation de mot de passe oublié
  void _openForgotPasswordSheet() {
    ForgotPasswordSheet.show(
      context,
      initialEmail: widget.user.email,
      onPasswordResetSuccess: () {
        widget.onUnlocked();
      },
    );
  }

  /// Déconnexion complète pour changer de compte
  Future<void> _handleLogout() async {
    await SessionTimeoutService.instance.unlockSession();
    await ref.read(authNotifierProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo avec badge de sécurité
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const ShieldNetLogo(size: 72),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.accentOrange,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 2.5,
                          ),
                        ),
                        child: const Icon(Icons.lock_rounded, size: 16, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Titre
                Text(
                  isEn ? 'Session Locked' : 'Session Verrouillée',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 8),

                // Explication de la règle des 5 minutes
                Text(
                  isEn
                      ? 'For your security, ShieldNet was locked after more than 5 minutes of absence.'
                      : "Par mesure de sécurité, ShieldNet s'est verrouillé après plus de 5 minutes d'absence.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 16),

                // Carte récapitulative du compte
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderColor(isDark)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                        child: Text(
                          widget.user.name.isNotEmpty
                              ? widget.user.name[0].toUpperCase()
                              : widget.user.email[0].toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.user.name.isNotEmpty)
                              Text(
                                widget.user.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            Text(
                              widget.user.email,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Message d'erreur s'il y a lieu
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
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
                ],

                // 1. Déverrouillage biométrique prioritaire (si disponible)
                if (_isBiometricsAvailable) ...[
                  ElevatedButton.icon(
                    onPressed: _isAuthenticatingBiometrics ? null : _authenticateWithBiometrics,
                    icon: _isAuthenticatingBiometrics
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.fingerprint_rounded, size: 22),
                    label: Text(
                      isEn ? 'Unlock with Face ID / Fingerprint' : 'Déverrouiller avec Empreinte / Face ID',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Séparateur
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppTheme.borderColor(isDark))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          isEn ? 'OR WITH PASSWORD' : 'OU AVEC MOT DE PASSE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: AppTheme.borderColor(isDark))),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                // 2. Déverrouillage alternatif par Mot de passe
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: isEn ? 'Account Password' : 'Mot de passe du compte',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  onSubmitted: (_) => _unlockWithPassword(),
                ),
                const SizedBox(height: 14),

                ElevatedButton.icon(
                  onPressed: _isLoadingPassword ? null : _unlockWithPassword,
                  icon: _isLoadingPassword
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.lock_open_rounded, size: 18),
                  label: Text(
                    isEn ? 'Unlock with Password' : 'Déverrouiller avec le mot de passe',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: _isBiometricsAvailable
                        ? (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9))
                        : AppTheme.primaryColor,
                    foregroundColor: _isBiometricsAvailable
                        ? (isDark ? Colors.white : Colors.black87)
                        : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
                const SizedBox(height: 10),

                // 3. Option Mot de passe oublié ?
                Center(
                  child: TextButton.icon(
                    onPressed: _openForgotPasswordSheet,
                    icon: const Icon(Icons.help_outline_rounded, size: 16),
                    label: Text(
                      isEn ? 'Forgot password?' : 'Mot de passe oublié ?',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 4. Déconnexion / Changer de compte
                Center(
                  child: TextButton(
                    onPressed: _handleLogout,
                    child: Text(
                      isEn ? 'Sign in with another account' : 'Se déconnecter / Changer de compte',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
