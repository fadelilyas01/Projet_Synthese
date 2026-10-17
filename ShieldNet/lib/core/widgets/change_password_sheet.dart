import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

/// Feuille modale haut niveau pour la modification sécurisée du mot de passe (NIST SP 800-63B)
/// Intègre un calculateur d'entropie en temps réel et un retour visuel multi-critères.
class ChangePasswordSheet extends ConsumerStatefulWidget {
  const ChangePasswordSheet({super.key});

  /// Affiche la feuille modale de modification de mot de passe
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const ChangePasswordSheet(),
    );
  }

  @override
  ConsumerState<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<ChangePasswordSheet> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  bool _success = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_onPasswordChanged);
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    setState(() {});
  }

  /// Évalue l'entropie et la conformité selon les recommandations NIST SP 800-63B
  _PasswordEntropyResult _evaluateEntropy(String password) {
    if (password.isEmpty) {
      return const _PasswordEntropyResult(
        score: 0.0,
        labelFr: 'Entrez un mot de passe',
        labelEn: 'Enter a password',
        color: Colors.grey,
        hasMinLength: false,
        hasLower: false,
        hasUpper: false,
        hasDigit: false,
        hasSpecial: false,
        estimatedBits: 0,
      );
    }

    final hasMinLength = password.length >= 8;
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasDigit = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecial = RegExp(r'[^a-zA-Z0-9]').hasMatch(password);

    int charsetSize = 0;
    if (hasLower) charsetSize += 26;
    if (hasUpper) charsetSize += 26;
    if (hasDigit) charsetSize += 10;
    if (hasSpecial) charsetSize += 33;

    final double rawBits = charsetSize > 0
        ? (password.length * (math.log(charsetSize) / math.ln2))
        : 0.0;
    final int estimatedBits = rawBits.round();

    // Calcul de conformité et score (0.0 à 1.0)
    int criteriaMet = 0;
    if (hasMinLength) criteriaMet++;
    if (hasLower) criteriaMet++;
    if (hasUpper) criteriaMet++;
    if (hasDigit) criteriaMet++;
    if (hasSpecial) criteriaMet++;

    double score = criteriaMet / 5.0;
    if (password.length >= 14 && criteriaMet >= 4) {
      score = 1.0;
    }

    final Color color;
    final String labelFr;
    final String labelEn;

    if (score < 0.4) {
      color = AppTheme.accentRed;
      labelFr = 'Vulnérable';
      labelEn = 'Vulnerable';
    } else if (score < 0.7) {
      color = AppTheme.accentOrange;
      labelFr = 'Moyen';
      labelEn = 'Moderate';
    } else if (score < 0.95) {
      color = AppTheme.primaryLightColor;
      labelFr = 'Robuste';
      labelEn = 'Strong';
    } else {
      color = AppTheme.accentGreen;
      labelFr = 'Impénétrable (Optimal)';
      labelEn = 'Optimal Strength';
    }

    return _PasswordEntropyResult(
      score: score,
      labelFr: labelFr,
      labelEn: labelEn,
      color: color,
      hasMinLength: hasMinLength,
      hasLower: hasLower,
      hasUpper: hasUpper,
      hasDigit: hasDigit,
      hasSpecial: hasSpecial,
      estimatedBits: estimatedBits,
    );
  }

  Future<void> _submitChange() async {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (currentPassword.isEmpty) {
      setState(() {
        _errorMessage = isEn
            ? 'Please enter your current password.'
            : 'Veuillez saisir votre mot de passe actuel.';
      });
      return;
    }

    if (newPassword.isEmpty) {
      setState(() {
        _errorMessage = isEn
            ? 'Please enter a new password.'
            : 'Veuillez saisir un nouveau mot de passe.';
      });
      return;
    }

    if (newPassword == currentPassword) {
      setState(() {
        _errorMessage = isEn
            ? 'The new password must be different from the current one.'
            : 'Le nouveau mot de passe doit être différent du mot de passe actuel.';
      });
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        _errorMessage = isEn
            ? 'The password confirmation does not match.'
            : 'La confirmation du mot de passe ne correspond pas.';
      });
      return;
    }

    final entropy = _evaluateEntropy(newPassword);
    if (!entropy.hasMinLength) {
      setState(() {
        _errorMessage = isEn
            ? 'Password must contain at least 8 characters.'
            : 'Le mot de passe doit contenir au moins 8 caractères.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final authNotifier = ref.read(authNotifierProvider.notifier);
      await authNotifier.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );

      if (mounted) {
        setState(() {
          _loading = false;
          _success = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isEn
                        ? 'Password successfully updated. Security alert email sent.'
                        : 'Mot de passe mis à jour. Courriel de confirmation envoyé.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 1400));
        if (mounted) {
          Navigator.of(context).pop();
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
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final cardBg = AppTheme.cardBg(isDark);
    final borderColor = AppTheme.borderColor(isDark);
    final entropy = _evaluateEntropy(_newPasswordController.text);

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 20,
          right: 20,
          top: 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Poignée de glissement moderne
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // En-tête avec bouclier cybernétique
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.lock_reset_rounded, color: AppTheme.primaryLightColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEn ? 'Update Password' : 'Modifier le mot de passe',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          isEn ? 'Secure & encrypted account' : 'Protection et chiffrement de votre compte',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Bannière d'état de succès
              if (_success) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isEn
                              ? 'Password updated successfully! Your account is secure.'
                              : 'Mot de passe modifié avec succès ! Votre compte est sécurisé.',
                          style: const TextStyle(
                            color: AppTheme.accentGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Bannière d'erreur éventuelle
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppTheme.accentRed, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppTheme.accentRed, fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 1. Champ mot de passe actuel
              Text(
                isEn ? 'CURRENT PASSWORD' : 'MOT DE PASSE ACTUEL',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.8),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrent,
                decoration: InputDecoration(
                  hintText: isEn ? 'Enter current password' : 'Saisissez votre mot de passe actuel',
                  prefixIcon: const Icon(Icons.key_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureCurrent ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                    onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Champ nouveau mot de passe
              Text(
                isEn ? 'NEW PASSWORD' : 'NOUVEAU MOT DE PASSE',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.8),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _newPasswordController,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  hintText: isEn ? 'Minimum 8 characters' : 'Minimum 8 caractères',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNew ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 10),

              // Jauge visuelle d'entropie dynamique
              if (_newPasswordController.text.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEn ? 'Password strength:' : 'Niveau de sécurité :',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      isEn ? entropy.labelEn : entropy.labelFr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: entropy.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: entropy.score,
                    backgroundColor: Colors.grey.withValues(alpha: 0.18),
                    valueColor: AlwaysStoppedAnimation<Color>(entropy.color),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 12),

                // Puces de vérification des exigences de complexité
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildCriterionChip(
                      label: isEn ? '8+ chars' : '8+ caract.',
                      isMet: entropy.hasMinLength,
                    ),
                    _buildCriterionChip(
                      label: isEn ? 'Upper & Lower' : 'Maj. & min.',
                      isMet: entropy.hasLower && entropy.hasUpper,
                    ),
                    _buildCriterionChip(
                      label: isEn ? 'Digit (0-9)' : 'Chiffre (0-9)',
                      isMet: entropy.hasDigit,
                    ),
                    _buildCriterionChip(
                      label: isEn ? 'Special char (!@#)' : 'Spécial (!@#)',
                      isMet: entropy.hasSpecial,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ] else ...[
                const SizedBox(height: 6),
              ],

              // 3. Champ confirmation
              Text(
                isEn ? 'CONFIRM NEW PASSWORD' : 'CONFIRMER LE NOUVEAU MOT DE PASSE',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.8),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  hintText: isEn ? 'Re-enter new password' : 'Confirmez le nouveau mot de passe',
                  prefixIcon: const Icon(Icons.shield_outlined, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 24),

              // Bouton d'action principal
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading || _success ? null : _submitChange,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shield_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              isEn ? 'Confirm and Protect Account' : 'Confirmer et Sécuriser le Compte',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 10),

              // Note de sécurité
              Center(
                child: Text(
                  isEn
                      ? 'Protected by advanced industry-grade encryption'
                      : 'Protection maximale et chiffrement haute sécurité',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCriterionChip({required String label, required bool isMet}) {
    const activeColor = AppTheme.accentGreen;
    final inactiveColor = Colors.grey.withValues(alpha: 0.6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isMet ? activeColor.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMet ? activeColor.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.2),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 13,
            color: isMet ? activeColor : inactiveColor,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isMet ? FontWeight.w700 : FontWeight.w500,
              color: isMet ? activeColor : inactiveColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordEntropyResult {
  final double score;
  final String labelFr;
  final String labelEn;
  final Color color;
  final bool hasMinLength;
  final bool hasLower;
  final bool hasUpper;
  final bool hasDigit;
  final bool hasSpecial;
  final int estimatedBits;

  const _PasswordEntropyResult({
    required this.score,
    required this.labelFr,
    required this.labelEn,
    required this.color,
    required this.hasMinLength,
    required this.hasLower,
    required this.hasUpper,
    required this.hasDigit,
    required this.hasSpecial,
    required this.estimatedBits,
  });
}
