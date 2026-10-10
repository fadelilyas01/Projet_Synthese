import 'package:shieldnet/core/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/security/crypto_utils.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../controllers/blacklist_controller.dart';
import '../../../../core/services/night_shield_service.dart';
import '../../../../core/services/call_log_helper.dart';
import '../../domain/services/serenity_score_calculator.dart';
import '../widgets/clipboard_banner.dart';
import '../widgets/action_hub_row.dart';
import '../widgets/zen_shield_card.dart';
import '../widgets/simple_metric_card.dart';
import '../widgets/serenity_score_card.dart';
import '../widgets/regional_threat_card.dart';
import '../widgets/device_integrity_banner.dart';
import '../../../community/presentation/widgets/citizen_impact_card.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../../core/widgets/app_logo.dart';
import '../widgets/telecom_security_tip_card.dart';
import '../widgets/peace_of_mind_summary_card.dart';
import 'call_screening_demo_page.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage>
    with WidgetsBindingObserver {
  int _interceptedCallsCount = 0;
  final _quickCheckController = TextEditingController();
  String? _detectedClipboardNumber;
  String? _dismissedClipboardNumber;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInterceptedMetrics();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboard());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _quickCheckController.dispose();
    super.dispose();
  }

  DateTime? _lastResumeCheck;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (_lastResumeCheck == null || now.difference(_lastResumeCheck!).inSeconds > 15) {
        _lastResumeCheck = now;
        ref.read(protectionStatusProvider.notifier).checkStatus();
        _loadInterceptedMetrics();
      }
      _checkClipboard();
    }
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.isEmpty) return;

      final digitCount = text.replaceAll(RegExp(r'\D'), '').length;
      final isValidPhone = digitCount >= 7 && digitCount <= 16 && RegExp(r'^[\+]?[\d\s\-\.\(\)]{7,20}$').hasMatch(text);

      if (isValidPhone && text != _detectedClipboardNumber && text != _dismissedClipboardNumber) {
        if (mounted) {
          setState(() {
            _detectedClipboardNumber = text;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadInterceptedMetrics() async {
    try {
      final status = await Permission.phone.status;
      if (!status.isGranted) return;

      final list = await DatabaseHelper.instance.getAllBlacklistedNumbers();
      final entries = await CallLogHelper.getSafeEntries(limit: 100);
      final hashes = list.map((e) => e.phoneHash).toSet();
      int intercepted = 0;
      for (var entry in entries) {
        if (entry.number != null && hashes.contains(CryptoUtils.hashPhoneNumber(entry.number!))) {
          intercepted++;
        }
      }
      if (mounted) {
        setState(() => _interceptedCallsCount = intercepted);
      }
    } catch (e) {
      AppLogger.log('[DashboardPage] Impossible de charger les métriques d\'interception: $e');
    }
  }

  void _showQuickVerificationDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEn = (l10n?.localeName == 'en') || (Localizations.localeOf(context).languageCode == 'en');
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.search_rounded, color: AppTheme.primaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n?.dialogCheckNumber ?? (isEn ? 'Verify a Number' : 'Vérifier un Numéro'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.dialogCheckPrompt ??
                      (isEn
                          ? 'Received a call from an unfamiliar number? Check here instantly to know if it is safe to answer:'
                          : 'Vous avez reçu un appel d\'un numéro inconnu ? Vérifiez immédiatement s\'il s\'agit d\'un correspondant fiable ou d\'un spam :'),
                  style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _quickCheckController,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: '+1 800 123 4567',
                    prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n?.btnCancel ?? 'Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  final phone = _quickCheckController.text.trim();
                  if (phone.isNotEmpty) {
                    Navigator.pop(ctx);
                    _executeVerification(phone);
                  }
                },
                child: Text(l10n?.btnVerify ?? 'Vérifier'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _executeVerification(String rawPhone) async {
    final l10n = AppLocalizations.of(context);
    final isEn = (l10n?.localeName == 'en') || (Localizations.localeOf(context).languageCode == 'en');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final checkUseCase = ref.read(checkNumberUseCaseProvider);
      final analysisEither = await checkUseCase(rawPhone);

      if (!mounted) return;
      Navigator.pop(context);

      analysisEither.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message), backgroundColor: AppTheme.accentRed),
          );
        },
        (analysis) {
          final isSpam = analysis.isSpam;
          final isWhitelisted = analysis.isWhitelisted;

          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(
                    isWhitelisted
                        ? Icons.verified_user_rounded
                        : (isSpam ? Icons.warning_amber_rounded : Icons.check_circle_rounded),
                    color: isWhitelisted
                        ? AppTheme.primaryColor
                        : (isSpam ? AppTheme.accentRed : AppTheme.accentGreen),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isWhitelisted
                          ? (l10n?.dialogVerified ?? 'Numéro Vérifié')
                          : (isSpam ? (l10n?.dialogSpamDetected ?? 'Attention : Spam Détecté') : (l10n?.dialogSafeNumber ?? 'Numéro Sûr')),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    CryptoUtils.maskPhoneNumber(rawPhone),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isWhitelisted
                        ? (l10n?.dialogVerifiedDesc ??
                            (isEn ? 'This caller is verified and certified safe.' : 'Ce correspondant est vérifié et certifié de confiance.'))
                        : (isSpam
                            ? (l10n?.dialogSpamDesc ??
                                (isEn
                                    ? 'This caller has been reported by the community. ShieldNet recommends not answering or calling back.'
                                    : 'Ce correspondant a été signalé comme indésirable par la communauté. ShieldNet vous recommande de ne pas décrocher ni rappeler.'))
                            : (l10n?.dialogSafeDesc ??
                                (isEn
                                    ? 'No malicious reports found. This number appears safe to answer.'
                                    : 'Aucun signalement suspect. Vous pouvez communiquer en toute sérénité.'))),
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n?.btnUnderstood ?? 'Compris')),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEn ? 'Error during phone number verification: $e' : 'Erreur lors de la vérification du numéro: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  String _formatCategory(String category, bool isEn) {
    final cat = category.toLowerCase().trim();
    if (isEn) {
      if (cat.contains('fraud') || cat.contains('arnaque')) return 'FRAUD / SCAM';
      if (cat.contains('telemarketing') || cat.contains('démarchage') || cat.contains('demarchage')) return 'TELEMARKETING';
      if (cat.contains('phishing') || cat.contains('hameçonnage')) return 'PHISHING';
      if (cat.contains('robocall') || cat.contains('automate') || cat.contains('silence')) return 'ROBOCALL';
      return category.toUpperCase();
    } else {
      if (cat.contains('fraud') || cat.contains('arnaque')) return 'ARNAQUE';
      if (cat.contains('telemarketing') || cat.contains('démarchage') || cat.contains('demarchage')) return 'DÉMARCHAGE';
      if (cat.contains('phishing') || cat.contains('hameçonnage')) return 'HAMEÇONNAGE';
      if (cat.contains('robocall') || cat.contains('automate') || cat.contains('silence')) return 'AUTOMATE';
      return category.toUpperCase();
    }
  }

  Widget _buildCalmBadge({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final protectionState = ref.watch(protectionStatusProvider);
    final blacklistAsync = ref.watch(blacklistControllerProvider);
    final isContactsOnly = ref.watch(contactsOnlyProvider);
    final nightShieldState = ref.watch(nightShieldProvider);
    final impactAsync = ref.watch(citizenImpactProvider(_interceptedCallsCount));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AppTheme.cardBg(isDark);
    final borderColor = AppTheme.borderColor(isDark);

    final totalBlocked = blacklistAsync.value?.length ?? 0;
    final l10n = AppLocalizations.of(context);
    final isEn = (l10n?.localeName == 'en') || (Localizations.localeOf(context).languageCode == 'en');
    final isProtectionActive = protectionState.value ?? false;
    final isSeniorMode = ref.watch(seniorModeProvider);
    final integrityAsync = ref.watch(deviceIntegrityProvider);
    final regionalThreatsAsync = ref.watch(regionalThreatsProvider);

    final serenityResult = SerenityScoreCalculator.compute(
      isCallScreeningActive: isProtectionActive,
      isAutoBlockEnabled: true,
      isBiometricEnabled: true,
      isContactsOnlyEnabled: isContactsOnly,
      isCacheFresh: totalBlocked > 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const ShieldNetLogo.withText(size: 26, fontSize: 18),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: l10n?.dialogCheckNumber ?? 'Vérifier un numéro',
            onPressed: () => _showQuickVerificationDialog(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(blacklistControllerProvider.notifier).syncWithServer();
          ref.invalidate(citizenImpactProvider);
          ref.invalidate(regionalThreatsProvider);
          ref.invalidate(deviceIntegrityProvider);
          ref.invalidate(bloomFilterProvider);
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          children: [
            // Salutation humaine & bienveillante avec badge de statut
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0, top: 2.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEn ? 'Hello!' : 'Bonjour !',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isProtectionActive
                              ? (isEn
                                  ? 'Your phone is protected. Have a peaceful day!'
                                  : 'Votre téléphone veille sur vous. Passez une excellente journée !')
                              : (isEn
                                  ? 'Protection is paused. Tap below to shield your calls.'
                                  : 'Protection suspendue. Touchez le bouclier pour réactiver.'),
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: (isProtectionActive ? AppTheme.accentGreen : Colors.grey).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (isProtectionActive ? AppTheme.accentGreen : Colors.grey).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: isProtectionActive ? AppTheme.accentGreen : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isProtectionActive
                              ? (isEn ? 'Protected' : 'Protégé')
                              : (isEn ? 'Paused' : 'En pause'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isProtectionActive ? AppTheme.accentGreen : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // BANDEAU ALERTE INTÉGRITÉ APPAREIL (ROOT)
            integrityAsync.maybeWhen(
              data: (integrity) => DeviceIntegrityBanner(result: integrity),
              orElse: () => const SizedBox.shrink(),
            ),

            // BANDEAU MODE SÉNIORS / ACCESSIBILITÉ RENFORCÉE
            if (isSeniorMode) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.16 : 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primaryColor, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.accessibility_new_rounded, color: AppTheme.primaryColor, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n?.seniorModeActiveTitle ?? 'Mode Simplifié Actif',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppTheme.primaryColor),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isEn
                                    ? 'High readability & automatic peace of mind.'
                                    : 'Lisibilité renforcée & protection silencieuse.',
                                style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isEn ? 'Your family & contacts can always reach you' : 'Vos proches peuvent vous appeler normalement',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isEn ? 'Scammers and automated bots are blocked in silence' : 'Les arnaques et robots sont bloqués sans sonnerie',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isEn ? 'Emergency numbers (911, 811) are strictly allowed' : 'Urgences 911 et santé 811 toujours autorisés',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.phone_in_talk_rounded, size: 20),
                        label: Text(
                          isEn ? 'Check an Unknown Number' : 'Vérifier un numéro suspect',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: () => _showQuickVerificationDialog(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // BANDEAU ALERTE MENACES RÉGIONALES (SPOOFING CIBLÉ)
            regionalThreatsAsync.maybeWhen(
              data: (summary) => summary != null ? RegionalThreatCard(summary: summary) : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),

            // BANDEAU DU PRESSE-PAPIER
            if (_detectedClipboardNumber != null) ...[
              ClipboardBanner(
                detectedNumber: _detectedClipboardNumber!,
                onVerify: () {
                  final phone = _detectedClipboardNumber!;
                  setState(() => _detectedClipboardNumber = null);
                  _executeVerification(phone);
                },
                onDismiss: () {
                  setState(() {
                    _dismissedClipboardNumber = _detectedClipboardNumber;
                    _detectedClipboardNumber = null;
                  });
                },
              ),
              const SizedBox(height: 16),
            ],

            // Carte principale de statut de protection
            protectionState.when(
              data: (isActive) => ZenShieldCard(
                isActive: isActive,
                isContactsOnly: isContactsOnly,
                isNightWindow: nightShieldState.isCurrentlyInNightWindow,
                onToggleProtection: () {
                  ref.read(protectionStatusProvider.notifier).toggleProtection();
                },
                onActivateProtection: () async {
                  final activated = await ref.read(protectionStatusProvider.notifier).requestPermission();
                  if (!context.mounted) return;
                  HapticFeedback.mediumImpact();
                  final successMsg = l10n?.protectionActiveSuccess ?? 'Protection ShieldNet activée avec succès !';
                  final permMsg = l10n?.protectionPermissionRequired ?? 'Veuillez accorder les autorisations pour activer la protection.';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(activated ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(child: Text(activated ? successMsg : permMsg, style: const TextStyle(fontWeight: FontWeight.w600))),
                        ],
                      ),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: activated ? AppTheme.accentGreen : AppTheme.accentRed,
                    ),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text(isEn ? 'Error: $err' : 'Erreur: $err'),
            ),
            const SizedBox(height: 16),

            // Raccourcis d'actions immédiates : Vérifier un numéro & Inspecteur SMS
            ActionHubRow(onVerifyNumber: () => _showQuickVerificationDialog(context)),
            const SizedBox(height: 14),

            // Espace Démonstration Jury & Conformité
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentCyan.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.science_rounded, color: AppTheme.accentCyan, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEn ? 'Jury Demonstration Space' : 'Espace Démonstration Jury',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          isEn ? 'Native call simulation < 3ms' : 'Simulateur d\'appels < 3ms & logs natifs',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.play_circle_outline_rounded, size: 16, color: AppTheme.accentCyan),
                    label: Text(isEn ? 'Test' : 'Tester', style: const TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CallScreeningDemoPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Compteurs statistiques d'activité locale & télémétrie moteur
            Row(
              children: [
                Expanded(
                  child: SimpleMetricCard(
                    icon: Icons.call_end_rounded,
                    color: AppTheme.accentRed,
                    count: '$_interceptedCallsCount',
                    label: l10n?.statSpamIntercepted ?? 'Spams interceptés',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SimpleMetricCard(
                    icon: Icons.shield_outlined,
                    color: AppTheme.primaryColor,
                    count: '$totalBlocked',
                    label: l10n?.statNumbersBlocked ?? 'Numéros protégés',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Bilan valorisant de tranquillité au quotidien
            PeaceOfMindSummaryCard(
              interceptedCount: _interceptedCallsCount,
              isProtectionActive: isProtectionActive,
            ),
            const SizedBox(height: 24),

            // Historique des derniers spams interceptés
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    l10n?.recentBlockedSpams ?? 'Derniers Spams Bloqués',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Flexible(
                  child: TextButton(
                    onPressed: () => _showQuickVerificationDialog(context),
                    child: Text(
                      l10n?.verifyCallAction ?? 'Vérifier un appel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            blacklistAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
              error: (err, stack) => const SizedBox(),
              data: (entries) {
                if (entries.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGreen.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_circle_outline_rounded, color: AppTheme.accentGreen, size: 36),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n?.calmLineTitle ?? 'Ligne calme et sécurisée',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n?.calmLineDesc ?? 'Aucune menace récente détectée sur votre appareil.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildCalmBadge(
                              icon: Icons.check_rounded,
                              label: isEn ? 'Real-time protection' : 'Protection active',
                              color: AppTheme.accentGreen,
                              isDark: isDark,
                            ),
                            _buildCalmBadge(
                              icon: Icons.shield_outlined,
                              label: isEn ? 'Up to date' : 'Protection à jour',
                              color: AppTheme.primaryColor,
                              isDark: isDark,
                            ),
                            _buildCalmBadge(
                              icon: Icons.health_and_safety_outlined,
                              label: isEn ? 'Emergency 911/811 priority' : 'Urgences 911 prioritaires',
                              color: Colors.teal,
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }

                final recentItems = entries.take(4).toList();
                return Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentItems.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 56),
                    itemBuilder: (ctx, index) {
                      final item = recentItems[index];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.accentRed.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.call_end_rounded, color: AppTheme.accentRed, size: 18),
                        ),
                        title: Text(
                          item.maskedNumber.isNotEmpty ? item.maskedNumber : (l10n?.maskedNumberDefault ?? 'Numéro masqué'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          _formatCategory(item.category, isEn),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.accentRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            l10n?.badgeBlocked ?? 'Bloqué',
                            style: const TextStyle(color: AppTheme.accentRed, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Conseil cybersécurité & prévention télécom
            const TelecomSecurityTipCard(),
            const SizedBox(height: 24),

            // Diagnostic et niveau de sécurité (masqué en mode aînés pour une clarté maximale)
            if (!isSeniorMode) ...[
              SerenityScoreCard(
                result: serenityResult,
                onOpenSettings: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
                },
              ),
              const SizedBox(height: 16),

              // Engagement communautaire citoyen
              impactAsync.maybeWhen(
                data: (impactData) => CitizenImpactCard(
                  data: impactData,
                  onReportSpam: () => _showQuickVerificationDialog(context),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}
