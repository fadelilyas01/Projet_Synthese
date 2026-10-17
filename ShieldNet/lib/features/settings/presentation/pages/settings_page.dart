import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/services/background_sync_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../widgets/auth_bottom_sheet.dart';
import 'admin_console_page.dart';
import '../../../../core/services/offline_sync_service.dart';
import '../../../../core/services/regional_compliance_service.dart';
import '../widgets/region_selection_sheet.dart';
import 'faq_page.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/change_password_sheet.dart';
import '../../../../core/services/biometric_service.dart';
import 'legal_compliance_page.dart';
import 'security_settings_page.dart';
import 'preferences_page.dart';
import '../../../call_filtering/presentation/controllers/blacklist_controller.dart';

/// Page d'accueil épurée et professionnelle des Paramètres (Architecture Hub)
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _isSyncing = false;
  bool _biometricEnabled = false;
  final BiometricService _biometricService = BiometricService();

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final enabled = await _biometricService.isBiometricEnabled();
    if (mounted) {
      setState(() => _biometricEnabled = enabled);
    }
  }

  Future<void> _flushOfflineQueue() async {
    setState(() => _isSyncing = true);
    try {
      final res = await OfflineSyncService.instance.flushQueue();
      ref.invalidate(offlineQueueCountProvider);
      ref.invalidate(citizenImpactProvider);
      await ref.read(blacklistControllerProvider.notifier).loadBlacklist();
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
            content: Text(isEn ? 'Error flushing offline queue: $e' : 'Erreur vidage file hors-ligne : $e'),
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
      await ref.read(blacklistControllerProvider.notifier).loadBlacklist();
      ref.invalidate(offlineQueueCountProvider);
      ref.invalidate(bloomFilterProvider);
      ref.invalidate(citizenImpactProvider);

      if (mounted) {
        setState(() => _isSyncing = false);
        final isEn = ref.read(localeProvider).languageCode == 'en';
        final String msg;
        if (count > 0) {
          msg = isEn
              ? 'Protection updated: $count threat rule(s) synchronized.'
              : 'Protection à jour : $count nouveau(x) numéro(s) synchronisé(s).';
        } else {
          msg = isEn
              ? 'Protection up to date: your shields already have the latest rules.'
              : 'Protection à jour : vos règles de filtrage sont déjà au niveau le plus récent.';
        }
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
          SnackBar(
            content: Text(isEn ? 'Network error: $e' : 'Erreur de connexion : $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authNotifierProvider);
    final currentLocale = ref.watch(localeProvider);
    final isEn = currentLocale.languageCode == 'en';
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
          // 1. Profil utilisateur et état d'authentification
          _buildUserAccountCard(user, cardBg, borderColor, isDark, l10n),
          const SizedBox(height: 14),

          // 2. Posture de Sécurité & Télémétrie d'Ingénierie
          _buildSecurityPostureBanner(isDark, borderColor, isEn, user),
          const SizedBox(height: 18),

          // 3. Hub Principal : Sécurité & Filtrage
          _buildSectionHeader(l10n?.sectionSecurity ?? (isEn ? 'SECURITY' : 'SÉCURITÉ')),
          _buildCard(
            cardBg: cardBg,
            borderColor: borderColor,
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shield_rounded, color: AppTheme.accentGreen, size: 26),
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        isEn ? 'Security & Protection' : 'Sécurité & Protection',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isEn ? 'Active' : 'Actif',
                        style: const TextStyle(
                          color: AppTheme.accentGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    isEn
                        ? 'Call & SMS filtering, biometric lock, emergency contacts'
                        : 'Filtrage d\'appels et SMS, empreinte digitale, numéros protégés',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SecuritySettingsPage()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 3. Hub Préférences de l'application
          _buildSectionHeader(l10n?.sectionPreferences ?? (isEn ? 'PREFERENCES' : 'PRÉFÉRENCES')),
          _buildCard(
            cardBg: cardBg,
            borderColor: borderColor,
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.tune_rounded, color: AppTheme.primaryColor, size: 26),
                ),
                title: Text(
                  isEn ? 'App Preferences' : 'Préférences de l\'application',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    isEn
                        ? 'Display theme, language, simplified interface for seniors'
                        : 'Thème d\'affichage, langue, mode interface simplifiée',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PreferencesPage()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 4. Région & Confidentialité
          _buildSectionHeader(l10n?.sectionJurisdiction ?? (isEn ? 'REGION & PRIVACY' : 'RÉGION & CONFIDENTIALITÉ')),
          _buildCard(
            cardBg: cardBg,
            borderColor: borderColor,
            children: [
              Consumer(
                builder: (context, ref, _) {
                  final regionalState = ref.watch(regionalComplianceProvider);
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
                      ListTile(
                        leading: const Icon(Icons.verified_user_rounded, color: AppTheme.accentGreen, size: 24),
                        title: Text(
                          isEn ? 'Privacy & Data Protection' : 'Respect de votre vie privée',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: Text(
                          isEn
                              ? 'No address book uploaded. Numbers remain 100% private'
                              : 'Aucun partage de vos contacts. Vos numéros restent 100% confidentiels',
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
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 5. Mises à jour des protections & Hors-ligne
          _buildSectionHeader(isEn ? 'PROTECTION UPDATES' : 'MISES À JOUR DES PROTECTIONS'),
          _buildCard(
            cardBg: cardBg,
            borderColor: borderColor,
            children: [
              ListTile(
                leading: const Icon(Icons.cloud_sync_rounded, color: AppTheme.primaryColor, size: 24),
                title: Text(
                  isEn ? 'Protection Status' : 'Protection en continu',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  isEn ? 'Shields are actively updated against emerging scam campaigns' : 'Filtres de sécurité actualisés contre les arnaques récentes',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                trailing: _isSyncing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : TextButton(
                        onPressed: _isSyncing ? null : () => _syncNow(l10n),
                        child: Text(
                          isEn ? 'Update' : 'Actualiser',
                          style: const TextStyle(color: AppTheme.primaryColor, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
              ),
              Consumer(
                builder: (context, ref, _) {
                  final pendingCountAsync = ref.watch(offlineQueueCountProvider);
                  final count = pendingCountAsync.value ?? 0;
                  if (count <= 0) return const SizedBox.shrink();

                  return Column(
                    children: [
                      const Divider(height: 1, indent: 56),
                      ListTile(
                        leading: const Icon(Icons.cloud_upload_rounded, color: AppTheme.accentOrange, size: 24),
                        title: Text(
                          isEn ? 'Pending Reports' : 'Signalements en attente',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: Text(
                          isEn
                              ? '$count report(s) saved offline, ready to send'
                              : '$count signalement(s) prêts à être transmis',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: ElevatedButton(
                          onPressed: _isSyncing ? null : _flushOfflineQueue,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            backgroundColor: AppTheme.accentOrange,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(isEn ? 'Send' : 'Envoyer', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 6. Espace modération pour les comptes administrateurs
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
                    final biometricEnabled = await _biometricService.isBiometricEnabled();
                    if (biometricEnabled) {
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
            const SizedBox(height: 18),
          ],

          // 7. Assistance & FAQ
          _buildSectionHeader(isEn ? 'HELP & SUPPORT' : 'ASSISTANCE'),
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
                  isEn ? 'Frequently asked questions and guides' : 'Questions fréquentes et fonctionnement',
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
          const SizedBox(height: 24),

          // 8. Informations de version et marque
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ShieldNetLogo(size: 32),
                  const SizedBox(height: 8),
                  Text(
                    l10n?.appVersionFooter ?? 'ShieldNet v1.0.0 • Sérénité & Sécurité Télécom',
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
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => ChangePasswordSheet.show(context),
                    icon: const Icon(Icons.key_rounded, size: 16),
                    label: Text(
                      ref.watch(localeProvider).languageCode == 'en' ? 'Password' : 'Mot de passe',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => RegionSelectionSheet.show(context),
                    icon: const Icon(Icons.public_rounded, size: 16),
                    label: Text(
                      '${user.countryFlag} ${user.provinceOrState}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
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

  Widget _buildSecurityPostureBanner(bool isDark, Color borderColor, bool isEn, UserModel? user) {
    final appSettings = ref.watch(appSettingsProvider);
    final contactsOnly = ref.watch(contactsOnlyProvider);

    int score = 60;
    if (appSettings.autoBlock) score += 15;
    if (appSettings.smsAnalysis) score += 10;
    if (_biometricEnabled) score += 10;
    if (contactsOnly) score += 5;
    if (score > 100) score = 100;

    final Color statusColor;
    final String statusTitle;
    final String statusSubtitle;

    if (score >= 95) {
      statusColor = AppTheme.accentGreen;
      statusTitle = isEn ? 'OPTIMAL SHIELD POSTURE' : 'POSTURE BOUCLIER OPTIMALE';
      statusSubtitle = isEn
          ? 'Autonomous on-device engine with zero telecom data leakage'
          : 'Moteur local autonome avec neutralisation temps réel sans fuite de données';
    } else if (score >= 80) {
      statusColor = AppTheme.primaryLightColor;
      statusTitle = isEn ? 'HIGH PROTECTION ACTIVE' : 'PROTECTION ÉLEVÉE ACTIVE';
      statusSubtitle = isEn
          ? 'Call & SMS filtering armed. Enable biometrics for optimal defense'
          : 'Filtrage actif. Activez la biométrie pour atteindre le niveau optimal';
    } else {
      statusColor = AppTheme.accentOrange;
      statusTitle = isEn ? 'STANDARD DEFENSE' : 'DÉFENSE STANDARD';
      statusSubtitle = isEn
          ? 'Some protection modules are paused or inactive'
          : 'Certains modules de filtrage préventif sont désactivés';
    }

    final bgGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFF1F5F9), Color(0xFFFFFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return Container(
      decoration: BoxDecoration(
        gradient: bgGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: isDark ? 0.08 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.verified_rounded, color: statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$score% ${isEn ? 'Protected' : 'Protégé'}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: score / 100.0,
                      strokeWidth: 4,
                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                    Center(
                      child: Text(
                        '$score%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            statusSubtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.35),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildEngineeringBadge('Filtre Bloom < 2ms', Icons.bolt_rounded, AppTheme.accentGreen),
              _buildEngineeringBadge('Keystore AES-256', Icons.lock_outline_rounded, AppTheme.primaryLightColor),
              _buildEngineeringBadge('Zéro-Fuite SHA-256', Icons.visibility_off_outlined, AppTheme.accentCyan),
              _buildEngineeringBadge('Loi 25 & PIPEDA', Icons.gavel_rounded, AppTheme.accentOrange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEngineeringBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
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
