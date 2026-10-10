import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/services/background_sync_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../widgets/auth_bottom_sheet.dart';
import 'admin_console_page.dart';
import '../../../../core/services/night_shield_service.dart';
import '../../../../core/services/offline_sync_service.dart';
import '../../../sms_inspector/presentation/pages/sms_inspector_page.dart';
import 'emergency_whitelist_page.dart';
import '../../../../core/services/regional_compliance_service.dart';
import '../widgets/region_selection_sheet.dart';
import 'faq_page.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/services/biometric_service.dart';
import '../../../../core/services/demo_mode_service.dart';
import '../../../call_filtering/presentation/pages/call_screening_demo_page.dart';
import 'legal_compliance_page.dart';
import 'observability_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _isSyncing = false;
  final BiometricService _biometricService = BiometricService();
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _isDemoMode = DemoModeService.instance.isDemoActive;

  @override
  void initState() {
    super.initState();
    _initBiometrics();
    _isDemoMode = DemoModeService.instance.isDemoActive;
  }

  Future<void> _toggleDemoMode(bool val) async {
    if (val) {
      await DemoModeService.instance.enableDemoMode();
    } else {
      await DemoModeService.instance.disableDemoMode();
    }
    if (mounted) {
      setState(() => _isDemoMode = val);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(val
              ? 'Mode Démo activé : données réalistes chargées (15 numéros, scénarios).'
              : 'Mode Démo désactivé : retour à l\'état standard.'),
          backgroundColor: val ? AppTheme.accentCyan : AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
    if (val) {
      final authenticated = await _biometricService.authenticate(
        reason: 'Authentifiez-vous pour activer la protection biométrique',
      );
      if (authenticated) {
        await _biometricService.setBiometricEnabled(true);
        if (mounted) setState(() => _biometricEnabled = true);
      }
    } else {
      await _biometricService.setBiometricEnabled(false);
      if (mounted) setState(() => _biometricEnabled = false);
    }
  }

  Future<void> _toggleAutoBlock(bool val) async {
    if (val) {
      final status = await Permission.phone.request();
      if (status.isGranted) {
        await ref.read(appSettingsProvider.notifier).setAutoBlock(true);
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

  Future<void> _toggleAutoSync(bool val) async {
    await ref.read(appSettingsProvider.notifier).setAutoSync(val);
  }

  Future<void> _toggleSeniorMode(bool val) async {
    await ref.read(appSettingsProvider.notifier).setSeniorMode(val);
  }

  Future<void> _flushOfflineQueue() async {
    setState(() => _isSyncing = true);
    try {
      final res = await OfflineSyncService.instance.flushQueue();
      ref.invalidate(offlineQueueCountProvider);
      if (mounted) {
        setState(() => _isSyncing = false);
        final isEn = ref.read(localeProvider).languageCode == 'en';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res.hasWorkDone
                  ? (isEn
                      ? 'Offline queue synchronized: ${res.totalSynced} item(s) sent.'
                      : 'File hors-ligne synchronisée : ${res.totalSynced} élément(s) transmis.')
                  : (isEn
                      ? 'No items pending synchronization.'
                      : 'Aucun élément en attente de synchronisation.'),
            ),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncing = false);
        final isEn = ref.read(localeProvider).languageCode == 'en';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEn ? 'Error flushing offline queue: $e' : 'Erreur vidage file hors-ligne: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  Future<void> _syncNow([AppLocalizations? l10n]) async {
    setState(() => _isSyncing = true);
    try {
      final count = await BackgroundSyncService.instance.syncNow();
      if (mounted) {
        setState(() => _isSyncing = false);
        final isEn = ref.read(localeProvider).languageCode == 'en';
        final defaultMsg = isEn ? 'Protection up to date: $count numbers synchronized.' : 'Protection à jour : $count numéros synchronisés.';
        final detailMsg = l10n?.syncSuccessDetail;
        final msg = detailMsg != null ? detailMsg.replaceAll('numéros', '$count numéros') : defaultMsg;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncing = false);
        final isEn = ref.read(localeProvider).languageCode == 'en';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEn ? 'Network error: $e' : 'Erreur réseau: $e'), backgroundColor: AppTheme.accentRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authNotifierProvider);
    final themeMode = ref.watch(themeModeProvider);
    final currentLocale = ref.watch(localeProvider);
    final nightShield = ref.watch(nightShieldProvider);
    final contactsOnly = ref.watch(contactsOnlyProvider);
    final settings = ref.watch(appSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AppTheme.cardBg(isDark);
    final borderColor = AppTheme.borderColor(isDark);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.settingsTitle ?? 'Paramètres', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Profil utilisateur et état d'authentification
          _buildUserAccountCard(user, cardBg, borderColor, isDark, l10n),
          const SizedBox(height: 16),

          // Options de sécurité et de filtrage
          _buildSectionHeader(l10n?.sectionSecurity ?? 'SÉCURITÉ'),
          _buildCard(
            cardBg: cardBg,
            borderColor: borderColor,
            children: [
              SwitchListTile(
                value: settings.autoBlock,
                onChanged: _toggleAutoBlock,
                title: Text(l10n?.settingCallFiltering ?? 'Filtrage d\'appels', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                secondary: const Icon(Icons.shield, color: AppTheme.accentGreen, size: 24),
              ),
              const Divider(height: 1, indent: 56),
              SwitchListTile(
                value: settings.smsAnalysis,
                onChanged: _toggleSms,
                title: Text(l10n?.settingSmsFiltering ?? 'Filtrage des SMS', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                secondary: const Icon(Icons.sms, color: AppTheme.primaryColor, size: 24),
              ),
              const Divider(height: 1, indent: 56),
              SwitchListTile(
                value: contactsOnly,
                onChanged: _toggleContactsOnly,
                title: Text(l10n?.settingContactsOnly ?? 'Mode Contacts Uniquement', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(l10n?.settingContactsOnlyDesc ?? 'Ne laisser sonner que vos contacts enregistrés', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                secondary: const Icon(Icons.contact_phone_rounded, color: AppTheme.accentOrange, size: 24),
              ),
              const Divider(height: 1, indent: 56),
              SwitchListTile(
                value: nightShield.isEnabled,
                onChanged: (val) {
                  ref.read(nightShieldProvider.notifier).setEnabled(val);
                },
                title: Text(l10n?.settingNightShield ?? 'Mode Bouclier Nocturne', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                  l10n?.localeName == 'en'
                      ? 'Silent filtering from ${nightShield.startHour.toString().padLeft(2, '0')}:${nightShield.startMinute.toString().padLeft(2, '0')} to ${nightShield.endHour.toString().padLeft(2, '0')}:${nightShield.endMinute.toString().padLeft(2, '0')}'
                      : 'Filtrage silencieux de ${nightShield.startHour.toString().padLeft(2, '0')}h${nightShield.startMinute.toString().padLeft(2, '0')} à ${nightShield.endHour.toString().padLeft(2, '0')}h${nightShield.endMinute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                secondary: const Icon(Icons.bedtime_rounded, color: Colors.indigoAccent, size: 24),
              ),
              const Divider(height: 1, indent: 56),
              SwitchListTile(
                value: _biometricEnabled,
                onChanged: _biometricAvailable ? _toggleBiometric : null,
                title: Text(
                  currentLocale.languageCode == 'en' ? 'Biometric Lock (Face ID / Fingerprint)' : 'Protection Biométrique (Face ID / Empreinte)',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  _biometricAvailable
                      ? (currentLocale.languageCode == 'en' ? 'Require biometric check for sensitive settings & admin' : 'Exiger la biométrie pour l\'accès d\'administration')
                      : (currentLocale.languageCode == 'en' ? 'Biometric hardware unavailable' : 'Capteur biométrique non disponible'),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                secondary: const Icon(Icons.fingerprint_rounded, color: AppTheme.accentOrange, size: 24),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.mark_email_read_rounded, color: AppTheme.accentCyan, size: 24),
                title: Text(l10n?.settingSmsInspector ?? 'Inspecteur de SMS & Liens', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(l10n?.settingSmsInspectorDesc ?? 'Analyser un message suspect ou un lien de livraison', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SmsInspectorPage()),
                  );
                },
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.health_and_safety_rounded, color: AppTheme.accentGreen, size: 24),
                title: Text(l10n?.settingEmergencyWhitelist ?? (currentLocale.languageCode == 'en' ? 'Emergency Numbers & Whitelist' : 'Numéros d\'Urgence & Liste Blanche'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                  l10n?.settingEmergencyWhitelistDesc ??
                      (currentLocale.languageCode == 'en'
                          ? '911, 988 and guaranteed priority contacts'
                          : '911, 811 et contacts autorisés prioritaires'),
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
              SwitchListTile(
                value: settings.autoSync,
                onChanged: _toggleAutoSync,
                title: Text(l10n?.settingBgSync ?? 'Sync en arrière-plan', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                secondary: const Icon(Icons.sync, color: AppTheme.primaryColor, size: 24),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.cloud_download, color: AppTheme.primaryColor, size: 24),
                title: Text(l10n?.settingUpdateDb ?? 'Mettre à jour la base', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                trailing: _isSyncing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        l10n?.btnSync ?? 'Synchroniser',
                        style: const TextStyle(color: AppTheme.primaryColor, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                onTap: _isSyncing ? null : () => _syncNow(l10n),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Résilience & File d'attente hors-ligne
          _buildSectionHeader(l10n?.sectionOfflineResilience ?? (currentLocale.languageCode == 'en' ? 'OFFLINE SYNCHRONIZATION' : 'SYNCHRONISATION & HORS-LIGNE')),
          _buildCard(
            cardBg: cardBg,
            borderColor: borderColor,
            children: [
              Consumer(
                builder: (context, ref, _) {
                  final pendingCountAsync = ref.watch(offlineQueueCountProvider);
                  final count = pendingCountAsync.value ?? 0;
                  return ListTile(
                    leading: Icon(
                      count > 0 ? Icons.cloud_queue_rounded : Icons.cloud_done_rounded,
                      color: count > 0 ? AppTheme.accentOrange : AppTheme.accentGreen,
                      size: 24,
                    ),
                    title: Text(
                      l10n?.settingOfflineQueue ?? (currentLocale.languageCode == 'en' ? 'Pending offline reports' : 'Envois en attente de connexion'),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text(
                      count > 0
                          ? (l10n?.settingOfflineQueuePending(count) ?? (currentLocale.languageCode == 'en' ? '$count report(s) waiting to sync' : '$count signalement(s) en attente de réseau'))
                          : (l10n?.settingOfflineQueueAllSynced ?? (currentLocale.languageCode == 'en' ? 'All reports and disputes are synchronized' : 'Toutes vos données sont synchronisées')),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: count > 0
                        ? ElevatedButton.icon(
                            onPressed: _isSyncing ? null : _flushOfflineQueue,
                            icon: const Icon(Icons.upload_rounded, size: 14),
                            label: Text(l10n?.localeName == 'en' ? 'Send' : 'Envoyer', style: const TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              backgroundColor: AppTheme.accentOrange,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline, color: AppTheme.accentGreen, size: 20),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Préférences d'affichage et de langue
          _buildSectionHeader(l10n?.sectionPreferences ?? 'PRÉFÉRENCES'),
          _buildCard(
            cardBg: cardBg,
            borderColor: borderColor,
            children: [
              SwitchListTile(
                value: settings.seniorMode,
                onChanged: _toggleSeniorMode,
                title: Text(
                  l10n?.settingSeniorMode ?? 'Mode Interface Simplifiée (Aînés)',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  l10n?.settingSeniorModeDesc ?? 'Agrandit les textes, renforce les contrastes et simplifie l\'accueil',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                secondary: const Icon(Icons.accessibility_new_rounded, color: AppTheme.primaryColor, size: 24),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.palette, color: AppTheme.accentOrange, size: 24),
                title: Text(l10n?.settingTheme ?? 'Thème', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                trailing: DropdownButtonHideUnderline(
                  child: DropdownButton<ThemeMode>(
                    value: themeMode,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                    items: [
                      DropdownMenuItem(value: ThemeMode.system, child: Text(l10n?.themeSystem ?? 'Système')),
                      DropdownMenuItem(value: ThemeMode.light, child: Text(l10n?.themeLight ?? 'Clair')),
                      DropdownMenuItem(value: ThemeMode.dark, child: Text(l10n?.themeDark ?? 'Sombre')),
                    ],
                    onChanged: (mode) {
                      if (mode != null) ref.read(themeModeProvider.notifier).setThemeMode(mode);
                    },
                  ),
                ),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.language, color: AppTheme.primaryColor, size: 24),
                title: Text(l10n?.settingLanguage ?? 'Langue', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                trailing: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: currentLocale.languageCode,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                    items: [
                      DropdownMenuItem(value: 'fr', child: Text(l10n?.langFrench ?? 'Français')),
                      DropdownMenuItem(value: 'en', child: Text(l10n?.langEnglish ?? 'English')),
                    ],
                    onChanged: (langCode) {
                      if (langCode != null) {
                        ref.read(localeProvider.notifier).setLocale(langCode);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Juridiction & Conformité Régionale (Loi 25 QC, PIPEDA, TCPA, CCPA)
          // Région & Confidentialité
          _buildSectionHeader(l10n?.sectionJurisdiction ?? (currentLocale.languageCode == 'en' ? 'REGION & PRIVACY' : 'RÉGION & CONFIDENTIALITÉ')),
          _buildCard(
            cardBg: cardBg,
            borderColor: borderColor,
            children: [
              Consumer(
                builder: (context, ref, _) {
                  final regionalState = ref.watch(regionalComplianceProvider);
                  final isEn = currentLocale.languageCode == 'en';
                  final countryName = regionalState.getLocalizedCountryName(currentLocale.languageCode);
                  final provinceName = regionalState.getLocalizedProvinceName(currentLocale.languageCode);

                  return Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                          child: Text(regionalState.countryFlag, style: const TextStyle(fontSize: 18)),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                '$countryName • $provinceName',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                regionalState.provinceOrState,
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          isEn
                              ? 'Local area codes and emergency numbers protected'
                              : 'Indicatifs locaux et numéros d\'urgence protégés',
                          style: const TextStyle(fontSize: 12, color: AppTheme.accentGreen, fontWeight: FontWeight.w600),
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => RegionSelectionSheet.show(context),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(isEn ? 'Change' : 'Modifier', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const Divider(height: 1, indent: 56),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                isEn
                                    ? 'Your personal communications remain strictly private.'
                                    : 'Vos communications personnelles restent strictement privées.',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.accentGreen.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isEn ? '100% Private' : '100% Confidentiel',
                                style: const TextStyle(color: AppTheme.accentGreen, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.verified_user_rounded, color: AppTheme.accentGreen, size: 24),
                title: Text(
                  currentLocale.languageCode == 'en' ? 'Legal Compliance & Ethics' : 'Conformité Loi 25 & Éthique',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  currentLocale.languageCode == 'en'
                      ? 'Zero address book collection, cryptographic hashing'
                      : 'Zéro carnet d\'adresses collecté, chiffrement salé',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LegalCompliancePage()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Démonstration Jury & Outils Avancés
          _buildSectionHeader(currentLocale.languageCode == 'en' ? 'JURY DEMO & TOOLS' : 'DÉMONSTRATION JURY & OUTILS'),
          _buildCard(
            cardBg: cardBg,
            borderColor: borderColor,
            children: [
              SwitchListTile(
                value: _isDemoMode,
                onChanged: _toggleDemoMode,
                title: Text(
                  currentLocale.languageCode == 'en' ? 'Jury Demo Mode' : 'Mode Démonstration Jury',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  currentLocale.languageCode == 'en'
                      ? 'Preloads realistic blocked numbers, logs, and fleet stats'
                      : 'Charge 15 numéros réalistes, scénarios d\'appels et stats de flotte',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                secondary: const Icon(Icons.science_rounded, color: AppTheme.accentCyan, size: 24),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.phone_locked_rounded, color: AppTheme.primaryColor, size: 24),
                title: Text(
                  currentLocale.languageCode == 'en' ? 'Native Call Screening Demo' : 'Simulateur de Filtrage d\'Appels',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  currentLocale.languageCode == 'en'
                      ? 'Real-time Android CallScreeningService interception logs'
                      : 'Démonstration d\'interception < 3 ms sans sonnerie',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CallScreeningDemoPage()),
                  );
                },
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.insights_rounded, color: Colors.cyan, size: 24),
                title: Text(
                  currentLocale.languageCode == 'en' ? 'User Observability & Feedback' : 'Observabilité & Retours Utilisateur',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  currentLocale.languageCode == 'en'
                      ? 'Adoption metrics and structured feedback system'
                      : 'Mesure d\'adoption, fonctionnalités clés et avis structurés',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ObservabilityPage()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Espace modération pour les comptes administrateurs et gestionnaires
          if (user != null && user.canModerate) ...[
            _buildSectionHeader(user.isSuperAdmin ? (l10n?.sectionAdmin ?? 'ADMINISTRATION') : (l10n?.sectionModeration ?? 'GESTION & MODÉRATION')),
            _buildCard(
              cardBg: cardBg,
              borderColor: borderColor,
              children: [
                ListTile(
                  leading: Icon(
                    user.isSuperAdmin ? Icons.admin_panel_settings : Icons.verified_user_rounded,
                    color: user.isSuperAdmin ? AppTheme.accentOrange : AppTheme.primaryColor,
                    size: 24,
                  ),
                  title: Text(
                    user.isSuperAdmin ? (l10n?.adminConsoleTitle ?? 'Console d\'Administration') : (l10n?.consoleModerationTitle ?? 'Console de Gestion & Modération'),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                  onTap: () async {
                    final isEn = currentLocale.languageCode == 'en';
                    if (_biometricEnabled) {
                      final ok = await _biometricService.authenticate(
                        reason: isEn
                            ? 'Biometric authentication required to access Admin Console'
                            : 'Authentification biométrique requise pour accéder à la Console Admin',
                      );
                      if (!ok) return;
                    }
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminConsolePage()),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Assistance, FAQ & Documentation Web — visible pour tous les utilisateurs
          _buildSectionHeader(currentLocale.languageCode == 'en' ? 'HELP & DOCUMENTATION' : 'ASSISTANCE & DOCUMENTATION'),
          _buildCard(
            cardBg: cardBg,
            borderColor: borderColor,
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.help_outline_rounded, color: AppTheme.primaryColor, size: 20),
                ),
                title: Text(
                  l10n?.helpFaqTitle ?? 'Centre d\'Aide & FAQ',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  l10n?.helpFaqSubtitle ?? 'Questions fréquentes, confidentialité et portail web',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HelpFaqPage()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Informations de version et licence
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ShieldNetLogo(size: 32),
                  const SizedBox(height: 8),
                  Text(
                    l10n?.appVersionFooter ?? 'ShieldNet v1.0.0 • Sécurité Télécom',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAccountCard(UserModel? user, Color cardBg, Color borderColor, bool isDark, AppLocalizations? l10n) {
    if (user != null) {
      return _buildCard(
        cardBg: cardBg,
        borderColor: borderColor,
        children: [
          ListTile(
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                user.email.isNotEmpty ? user.email[0].toUpperCase() : 'U',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    user.name.isNotEmpty ? user.name : user.email.split('@')[0],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (user.isSuperAdmin) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('ADMIN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentOrange)),
                  ),
                ] else if (user.isManager) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ref.watch(localeProvider).languageCode == 'en' ? 'MANAGER' : 'GESTIONNAIRE',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              user.email,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
            trailing: TextButton(
              onPressed: () async {
                await ref.read(authNotifierProvider.notifier).logout();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n?.logoutSuccess ?? 'Déconnexion réussie.')),
                  );
                }
              },
              child: Text(l10n?.btnLogout ?? 'Déconnexion', style: const TextStyle(color: AppTheme.accentRed, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    }

    final isEn = ref.watch(localeProvider).languageCode == 'en';
    return _buildCard(
      cardBg: cardBg,
      borderColor: borderColor,
      children: [
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_circle_outlined, color: AppTheme.primaryColor, size: 24),
          ),
          title: Text(
            isEn ? 'Sign In / Account' : 'Se connecter',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: Text(
            isEn ? 'Access your account or create a new one' : 'Accéder à votre compte ou vous inscrire',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
          onTap: () => AuthBottomSheet.show(context),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
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
