import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/services/biometric_service.dart';
import '../../../../core/services/night_shield_service.dart';
import '../../../../core/widgets/forgot_password_sheet.dart';
import 'emergency_whitelist_page.dart';
import '../../../sms_inspector/presentation/pages/sms_inspector_page.dart';

/// Page dédiée regroupant l'ensemble des réglages de sécurité et de filtrage
class SecuritySettingsPage extends ConsumerStatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  ConsumerState<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends ConsumerState<SecuritySettingsPage> {
  final BiometricService _biometricService = BiometricService();
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _initBiometrics();
  }

  Future<void> _initBiometrics() async {
    final available = await _biometricService.isBiometricsAvailable();
    final enabled = await _biometricService.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
      });
    }
  }

  Future<void> _toggleBiometric(bool val) async {
    final isEn = mounted ? Localizations.localeOf(context).languageCode == 'en' : false;
    if (val) {
      final available = await _biometricService.isBiometricsAvailable();
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEn
                    ? 'No biometric hardware or enrolled fingerprint found. Please configure a fingerprint in your phone Settings first.'
                    : 'Aucune biométrie enregistrée sur l\'appareil. Veuillez d\'abord configurer une empreinte dans les Paramètres de votre téléphone.',
              ),
              backgroundColor: AppTheme.accentOrange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      final authenticated = await _biometricService.authenticate(
        reason: isEn
            ? 'Authenticate to enable biometric protection'
            : 'Authentifiez-vous pour activer la protection biométrique',
        biometricOnly: true,
      );
      if (authenticated) {
        await _biometricService.setBiometricEnabled(true);
        if (mounted) setState(() => _biometricEnabled = true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEn
                    ? 'Biometric verification failed or cancelled.'
                    : 'Échec ou annulation de la vérification biométrique.',
              ),
              backgroundColor: AppTheme.accentRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else {
      // Exiger l'authentification biométrique AVANT de permettre la désactivation
      final authenticated = await _biometricService.authenticate(
        reason: isEn
            ? 'Confirm your identity to disable biometric protection'
            : 'Confirmez votre identité pour désactiver la protection biométrique',
        biometricOnly: true,
      );
      if (authenticated) {
        await _biometricService.setBiometricEnabled(false);
        if (mounted) setState(() => _biometricEnabled = false);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEn
                    ? 'Deactivation cancelled: identity not verified.'
                    : 'Désactivation annulée : identité non confirmée.',
              ),
              backgroundColor: AppTheme.accentRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleAutoBlock(bool val) async {
    if (val) {
      final status = await Permission.phone.request();
      if (status.isGranted) {
        await ref.read(appSettingsProvider.notifier).setAutoBlock(true);
      } else {
        if (mounted) {
          final isEn = ref.read(localeProvider).languageCode == 'en';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEn
                  ? 'Phone permission required to block calls automatically.'
                  : 'Permission téléphone requise pour le filtrage automatique.'),
              backgroundColor: AppTheme.accentOrange,
            ),
          );
        }
      }
    } else {
      await ref.read(appSettingsProvider.notifier).setAutoBlock(false);
    }
  }

  Future<void> _toggleSms(bool val) async {
    await ref.read(appSettingsProvider.notifier).setSmsAnalysis(val);
  }

  Future<void> _toggleContactsOnly(bool val) async {
    if (val) {
      final status = await Permission.contacts.request();
      if (status.isGranted) {
        await ref.read(contactsOnlyProvider.notifier).toggle(true);
        if (mounted) {
          final isEn = ref.read(localeProvider).languageCode == 'en';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEn
                  ? 'Strict Shield mode active: only contacts will ring.'
                  : 'Mode Bouclier Strict activé : seuls vos contacts feront sonner le téléphone.'),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
        }
      } else {
        if (mounted) {
          final isEn = ref.read(localeProvider).languageCode == 'en';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEn
                  ? 'Contacts permission required for this mode.'
                  : 'Permission d\'accès aux contacts requise pour ce mode.'),
              backgroundColor: AppTheme.accentOrange,
            ),
          );
        }
      }
    } else {
      await ref.read(contactsOnlyProvider.notifier).toggle(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authNotifierProvider);
    final currentLocale = ref.watch(localeProvider);
    final isEn = currentLocale.languageCode == 'en';
    final nightShield = ref.watch(nightShieldProvider);
    final contactsOnly = ref.watch(contactsOnlyProvider);
    final settings = ref.watch(appSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AppTheme.cardBg(isDark);
    final borderColor = AppTheme.borderColor(isDark);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEn ? 'Security & Protection' : 'Sécurité & Protection',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Section 1 : Filtrage des appels et messages
          _buildSectionHeader(isEn ? 'CALL & SMS FILTERING' : 'FILTRAGE DES APPELS & MESSAGES'),
          _buildCard(
            cardBg: cardBg,
            borderColor: borderColor,
            children: [
              SwitchListTile(
                value: settings.autoBlock,
                onChanged: _toggleAutoBlock,
                title: Text(
                  l10n?.settingCallFiltering ?? (isEn ? 'Call Filtering' : 'Filtrage d\'appels'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  isEn ? 'Blocks known nuisance and scam callers' : 'Bloque les numéros malveillants identifiés',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                secondary: const Icon(Icons.shield_rounded, color: AppTheme.accentGreen, size: 24),
              ),
              const Divider(height: 1, indent: 56),
              SwitchListTile(
                value: settings.smsAnalysis,
                onChanged: _toggleSms,
                title: Text(
                  l10n?.settingSmsFiltering ?? (isEn ? 'SMS Filtering' : 'Filtrage des SMS'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  isEn ? 'Detects fraudulent text messages and suspicious links' : 'Détecte les messages et liens douteux',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                secondary: const Icon(Icons.sms_rounded, color: AppTheme.primaryColor, size: 24),
              ),
              const Divider(height: 1, indent: 56),
              SwitchListTile(
                value: contactsOnly,
                onChanged: _toggleContactsOnly,
                title: Text(
                  l10n?.settingContactsOnly ?? (isEn ? 'Contacts Only Mode' : 'Mode Contacts Uniquement'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  l10n?.settingContactsOnlyDesc ?? (isEn ? 'Only your saved contacts will ring' : 'Ne laisser sonner que vos contacts enregistrés'),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                secondary: const Icon(Icons.contact_phone_rounded, color: AppTheme.accentOrange, size: 24),
              ),
              const Divider(height: 1, indent: 56),
              SwitchListTile(
                value: nightShield.isEnabled,
                onChanged: (val) {
                  ref.read(nightShieldProvider.notifier).setEnabled(val);
                },
                title: Text(
                  l10n?.settingNightShield ?? (isEn ? 'Night Shield Mode' : 'Mode Bouclier Nocturne'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  isEn
                      ? 'Silent filtering from ${nightShield.startHour.toString().padLeft(2, '0')}:${nightShield.startMinute.toString().padLeft(2, '0')} to ${nightShield.endHour.toString().padLeft(2, '0')}:${nightShield.endMinute.toString().padLeft(2, '0')}'
                      : 'Filtrage silencieux de ${nightShield.startHour.toString().padLeft(2, '0')}h${nightShield.startMinute.toString().padLeft(2, '0')} à ${nightShield.endHour.toString().padLeft(2, '0')}h${nightShield.endMinute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                secondary: const Icon(Icons.bedtime_rounded, color: Colors.indigoAccent, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Section 2 : Accès et verrouillage
          _buildSectionHeader(isEn ? 'ACCESS & LOCK' : 'ACCÈS & VERROUILLAGE'),
          _buildCard(
            cardBg: cardBg,
            borderColor: borderColor,
            children: [
              SwitchListTile(
                value: _biometricEnabled,
                onChanged: _biometricAvailable ? _toggleBiometric : null,
                title: Text(
                  isEn ? 'Biometric App Lock' : 'Verrouillage par Empreinte / Face ID',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  _biometricAvailable
                      ? (isEn ? 'Require biometric confirmation to open ShieldNet' : 'Exiger votre empreinte ou visage pour ouvrir l\'application')
                      : (isEn ? 'Biometric sensor unavailable on this device' : 'Capteur biométrique non configuré'),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                secondary: const Icon(Icons.fingerprint_rounded, color: AppTheme.accentOrange, size: 24),
              ),
              if (user != null) ...[
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.lock_reset_rounded, color: AppTheme.primaryColor, size: 24),
                  title: Text(
                    isEn ? 'Change Password' : 'Modifier mon mot de passe',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    isEn
                        ? 'Receive a secure verification code by email'
                        : 'Recevoir un code de sécurité par courriel',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                  onTap: () {
                    ForgotPasswordSheet.show(
                      context,
                      initialEmail: user.email,
                    );
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // Section 3 : Outils et contacts protégés
          _buildSectionHeader(isEn ? 'TOOLS & PROTECTED CONTACTS' : 'OUTILS & CONTACTS PROTÉGÉS'),
          _buildCard(
            cardBg: cardBg,
            borderColor: borderColor,
            children: [
              ListTile(
                leading: const Icon(Icons.health_and_safety_rounded, color: AppTheme.accentGreen, size: 24),
                title: Text(
                  l10n?.settingEmergencyWhitelist ?? (isEn ? 'Emergency & Priority Contacts' : 'Numéros d\'Urgence & Contacts Protégés'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  l10n?.settingEmergencyWhitelistDesc ??
                      (isEn
                          ? '911, 811 and your priority contacts are never blocked'
                          : '911, 811 et vos proches prioritaires ne sont jamais bloqués'),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EmergencyWhitelistPage()),
                  );
                },
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.mark_email_read_rounded, color: AppTheme.accentCyan, size: 24),
                title: Text(
                  l10n?.settingSmsInspector ?? (isEn ? 'SMS & Link Inspector' : 'Vérificateur de SMS & Liens'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  l10n?.settingSmsInspectorDesc ?? (isEn ? 'Analyze suspicious messages or parcel delivery links' : 'Tester un message suspect ou un avis de colis douteux'),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SmsInspectorPage()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.grey,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildCard({
    required Color cardBg,
    required Color borderColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }
}
