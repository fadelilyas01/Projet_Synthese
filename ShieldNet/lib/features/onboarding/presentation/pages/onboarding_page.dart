import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shieldnet/core/theme/app_theme.dart';
import 'package:shieldnet/core/services/regional_compliance_service.dart';
import 'package:shieldnet/l10n/app_localizations.dart';
import 'package:shieldnet/main.dart';
import 'package:shieldnet/core/widgets/app_logo.dart';
import 'package:shieldnet/core/widgets/auth_gate.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndPromptLanguage();
    });
  }

  Future<void> _checkAndPromptLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString('settings_language');
      if (savedLang == null && mounted) {
        _showLanguageSelectionBottomSheet();
      }
    } catch (_) {}
  }

  void _showLanguageSelectionBottomSheet() {
    final currentLocale = ref.read(localeProvider);
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.language_rounded, color: AppTheme.primaryColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bienvenue / Welcome',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Sélectionnez / Select language',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Option Français
              _buildLanguageOption(
                label: 'Français (Canada)',
                flag: '🇨🇦',
                code: 'fr',
                isSelected: currentLocale.languageCode == 'fr',
                onTap: () {
                  ref.read(localeProvider.notifier).setLocale('fr');
                  Navigator.pop(ctx);
                },
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              // Option Anglais
              _buildLanguageOption(
                label: 'English (United States / Canada)',
                flag: '🇺🇸',
                code: 'en',
                isSelected: currentLocale.languageCode == 'en',
                onTap: () {
                  ref.read(localeProvider.notifier).setLocale('en');
                  Navigator.pop(ctx);
                },
                isDark: isDark,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption({
    required String label,
    required String flag,
    required String code,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 15,
                  color: isSelected ? AppTheme.primaryColor : null,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor, size: 22)
            else
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 14),
          ],
        ),
      ),
    );
  }

  Future<void> _requestPermissionsAndFinish() async {
    HapticFeedback.mediumImpact();
    await [
      Permission.phone,
      Permission.contacts,
      Permission.sms,
    ].request();

    const storage = FlutterSecureStorage();
    await storage.write(key: 'has_seen_onboarding', value: 'true');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_onboarding', true);
    } catch (_) {}

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthGate(child: MainTabNavigationScreen())),
      );
    }
  }

  void _nextPage() {
    HapticFeedback.selectionClick();
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _requestPermissionsAndFinish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentLocale = ref.watch(localeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLastPage = _currentPage == 3;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // Barre supérieure : Logo, Sélecteur de langue & Bouton Passer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo — Expanded pour éviter l'overflow
                  const Expanded(
                    child: ShieldNetLogo.withText(size: 26, fontSize: 18),
                  ),

                  // Sélecteur de langue interactif FR / EN
                  Container(
                    height: 32,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLangPill(
                          code: 'fr',
                          label: 'FR',
                          isSelected: currentLocale.languageCode == 'fr',
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref.read(localeProvider.notifier).setLocale('fr');
                          },
                        ),
                        _buildLangPill(
                          code: 'en',
                          label: 'EN',
                          isSelected: currentLocale.languageCode == 'en',
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref.read(localeProvider.notifier).setLocale('en');
                          },
                        ),
                      ],
                    ),
                  ),

                  // Bouton Passer
                  if (!isLastPage)
                    TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _requestPermissionsAndFinish();
                      },
                      child: Text(
                        l10n?.onboardingSkip ?? 'Passer',
                        style: TextStyle(
                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),

            // Carrousel de diapositives
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                children: [
                  _buildSlide1(isDark, l10n),
                  _buildSlide2(isDark, l10n),
                  _buildSlideRegion(isDark, l10n),
                  _buildSlide3(isDark, l10n),
                ],
              ),
            ),

            // Navigation inférieure : Indicateurs de progression et Bouton d'action
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Indicateurs à étapes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 28 : 8,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppTheme.primaryColor
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  // Bouton Suivant / Activer la protection
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              isLastPage
                                  ? (l10n?.onboardingActivate ?? 'Activer la protection')
                                  : (l10n?.onboardingContinue ?? 'Continuer'),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isLastPage ? Icons.check_circle_outline_rounded : Icons.arrow_forward_rounded,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLangPill({
    required String code,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Diapositive 1 : Interception Temps Réel & Simulation d'Appel Filtré
  Widget _buildSlide1(bool isDark, AppLocalizations? l10n) {
    final title = l10n?.onboardingSlide1Title ?? 'Protection Anti-Spam';
    final desc = l10n?.onboardingSlide1Text ??
        'ShieldNet filtre les appels malveillants et le démarchage agressif en temps réel sans jamais perturber votre ligne.';
    final isEn = ref.watch(localeProvider).languageCode == 'en';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // Maquette d'appel bloqué authentique (Simulation Android)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.accentRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.call_end_rounded, color: AppTheme.accentRed, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEn ? 'Incoming call intercepted' : 'Appel entrant intercepté',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  isEn ? '2 minutes ago' : 'Il y a 2 minutes',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isEn ? 'Blocked instantly' : 'Bloqué instantanément',
                        style: const TextStyle(color: AppTheme.accentRed, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text(
                        '+1 (800) 555-0199',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isEn ? 'Robocall' : 'Démarchage',
                      style: const TextStyle(color: AppTheme.accentRed, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  // Diapositive 2 : Confidentialité & Données locales
  Widget _buildSlide2(bool isDark, AppLocalizations? l10n) {
    final isEn = ref.watch(localeProvider).languageCode == 'en';
    final title = l10n?.onboardingSlide2Title ?? (isEn ? 'Complete Privacy' : 'Confidentialité Totale');
    final desc = l10n?.onboardingSlide2Text ??
        (isEn
            ? 'Your contacts stay strictly on your phone. Suspicious calls are checked anonymously without ever exposing your private address book.'
            : 'Votre carnet d\'adresses ne quitte jamais votre appareil. Les numéros sont vérifiés de manière 100% anonyme sans transmettre vos contacts personnels.');

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // Schéma de flux de données étanche
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
            ),
            child: Column(
              children: [
                _buildPrivacyRow(
                  icon: Icons.contacts_outlined,
                  title: isEn ? 'Private Address Book' : 'Contacts 100% Privés',
                  desc: isEn
                      ? 'Stored securely on your phone. Never sent to any server or third party.'
                      : 'Restent en sécurité sur votre appareil. Jamais envoyés sur Internet.',
                  color: AppTheme.accentGreen,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Divider(height: 1),
                ),
                _buildPrivacyRow(
                  icon: Icons.lock_outline_rounded,
                  title: isEn ? 'Anonymous Verification' : 'Anonymat Garanti',
                  desc: isEn
                      ? 'Phone numbers are securely anonymized so caller identities are never revealed.'
                      : 'Les numéros sont convertis en codes anonymes chiffrés : vos appels restent confidentiels.',
                  color: AppTheme.primaryColor,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Divider(height: 1),
                ),
                _buildPrivacyRow(
                  icon: Icons.verified_user_outlined,
                  title: isEn ? 'Certified Privacy' : 'Respect de la Vie Privée',
                  desc: isEn
                      ? 'Built from the ground up to keep your personal data secure and confidential.'
                      : 'Conçu dès le départ pour protéger vos données personnelles et votre vie privée.',
                  color: AppTheme.accentCyan,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  // Diapositive Région & Juridiction : Demande de pays puis de province avec adaptation des normes
  Widget _buildSlideRegion(bool isDark, AppLocalizations? l10n) {
    final regionalState = ref.watch(regionalComplianceProvider);
    final isEn = ref.watch(localeProvider).languageCode == 'en';
    final cardBg = isDark ? AppTheme.surfaceDark : Colors.white;
    final borderColor = isDark ? AppTheme.borderDark : AppTheme.borderLight;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.public_rounded, color: AppTheme.primaryColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEn ? 'Your Region' : 'Votre Région',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            isEn ? 'Optimizes detection for your local area codes' : 'Optimise le filtrage selon vos indicatifs locaux',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Étape 1 : Choix du Pays (Canada ou États-Unis)
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(regionalComplianceProvider.notifier).setRegion(
                            country: 'CA',
                            provinceOrState: 'QC',
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          decoration: BoxDecoration(
                            color: regionalState.country == 'CA'
                                ? AppTheme.primaryColor.withValues(alpha: 0.12)
                                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: regionalState.country == 'CA' ? AppTheme.primaryColor : borderColor,
                              width: regionalState.country == 'CA' ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🇨🇦', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Canada',
                                  style: TextStyle(
                                    fontWeight: regionalState.country == 'CA' ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 13,
                                    color: regionalState.country == 'CA' ? AppTheme.primaryColor : null,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(regionalComplianceProvider.notifier).setRegion(
                            country: 'US',
                            provinceOrState: 'NY',
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          decoration: BoxDecoration(
                            color: regionalState.country == 'US'
                                ? AppTheme.primaryColor.withValues(alpha: 0.12)
                                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: regionalState.country == 'US' ? AppTheme.primaryColor : borderColor,
                              width: regionalState.country == 'US' ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🇺🇸', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  isEn ? 'United States' : 'États-Unis',
                                  style: TextStyle(
                                    fontWeight: regionalState.country == 'US' ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 13,
                                    color: regionalState.country == 'US' ? AppTheme.primaryColor : null,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Étape 2 : Choix Province ou État
                Text(
                  regionalState.country == 'CA'
                      ? (isEn ? 'Province or Territory' : 'Province ou Territoire')
                      : (isEn ? 'State' : 'État américain (State)'),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: regionalState.provinceOrState,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down_rounded),
                      items: regionalState.country == 'CA'
                          ? (isEn ? RegionalComplianceManager.canadianProvincesEn : RegionalComplianceManager.canadianProvinces).entries.map((e) {
                              return DropdownMenuItem<String>(
                                value: e.key,
                                child: Text(
                                  e.value,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: e.key == regionalState.provinceOrState ? FontWeight.bold : FontWeight.normal,
                                    color: e.key == regionalState.provinceOrState ? AppTheme.primaryColor : null,
                                  ),
                                ),
                              );
                            }).toList()
                          : (isEn ? RegionalComplianceManager.usStatesEn : RegionalComplianceManager.usStates).entries.map((e) {
                              return DropdownMenuItem<String>(
                                value: e.key,
                                child: Text(
                                  e.value,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: e.key == regionalState.provinceOrState ? FontWeight.bold : FontWeight.normal,
                                    color: e.key == regionalState.provinceOrState ? AppTheme.accentOrange : null,
                                  ),
                                ),
                              );
                            }).toList(),
                      onChanged: (newProv) {
                        if (newProv != null) {
                          HapticFeedback.selectionClick();
                          ref.read(regionalComplianceProvider.notifier).setRegion(
                            country: regionalState.country,
                            provinceOrState: newProv,
                          );
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Étape 3 : Carte d'Adaptation Locale & Sérénité
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.accentGreen.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified_user_rounded, size: 16, color: AppTheme.accentGreen),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              isEn ? 'Tailored Local Protection' : 'Protection Locale Calibrée',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.accentGreen),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isEn
                            ? 'ShieldNet recognizes your area codes to block suspicious spoofing, while ensuring legitimate callers and family reach you.'
                            : 'ShieldNet reconnaît vos indicatifs régionaux pour bloquer les faux numéros locaux, tout en garantissant que vos proches puissent vous joindre.',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87, height: 1.35),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accentCyan.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isEn ? '100% Confidential' : 'Confidentialité Totale',
                              style: const TextStyle(color: AppTheme.accentCyan, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isEn ? 'Emergencies: 911 / 811 / 988' : 'Urgences : 911 / 811 / 988',
                              style: const TextStyle(color: AppTheme.accentGreen, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isEn ? 'Local Security & Peace of Mind' : 'Sécurité Locale & Sérénité',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isEn
                ? 'Your regional selection helps ShieldNet detect local spoofing tactics while keeping all personal communication strictly confidential.'
                : 'Votre région permet à ShieldNet de mieux cibler les techniques de démarchage de proximité, tout en assurant une confidentialité absolue.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  // Diapositive 3 : Configuration des permissions système Android
  Widget _buildSlide3(bool isDark, AppLocalizations? l10n) {
    final title = l10n?.onboardingSlide3Title ?? 'Prêt en 1 Geste';
    final desc = l10n?.onboardingSlide3Text ??
        'Accordez les autorisations nécessaires pour permettre à ShieldNet d\'intercepter les spams avant qu\'ils ne sonnent.';
    final isEn = ref.watch(localeProvider).languageCode == 'en';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
            ),
            child: Column(
              children: [
                _buildPermissionRow(
                  icon: Icons.phone_in_talk_outlined,
                  title: isEn ? 'Call Protection' : 'Filtrage des Appels',
                  desc: isEn
                      ? 'Allows ShieldNet to silence and block unwanted calls before your phone rings'
                      : 'Permet à ShieldNet de bloquer les appels indésirables avant même qu\'ils ne sonnent',
                  isDark: isDark,
                ),
                const SizedBox(height: 14),
                _buildPermissionRow(
                  icon: Icons.emergency_outlined,
                  title: isEn ? 'Emergency Numbers Protected' : 'Numéros d\'Urgence Prioritaires',
                  desc: isEn
                      ? 'Always guarantees your family and emergency services (911, 988, 811) reach you'
                      : 'Vos proches et les services d\'urgence (911, 988, 811) peuvent toujours vous joindre',
                  isDark: isDark,
                ),
                const SizedBox(height: 14),
                _buildPermissionRow(
                  icon: Icons.sms_outlined,
                  title: isEn ? 'SMS & Link Inspector' : 'Inspecteur de SMS & Liens',
                  desc: isEn
                      ? 'Warns you about suspicious delivery notices and scam links without reading private chats'
                      : 'Vous alerte face aux faux colis et faux remboursements, sans jamais lire vos textos privés',
                  isDark: isDark,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyRow({
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionRow({
    required IconData icon,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }
}
