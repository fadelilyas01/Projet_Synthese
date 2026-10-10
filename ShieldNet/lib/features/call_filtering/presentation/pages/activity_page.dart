import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:call_log/call_log.dart' as call_log;
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

import '../../../../core/security/crypto_utils.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/services/citizen_impact_service.dart';
import '../../../../core/network/api_service.dart';
import '../controllers/blacklist_controller.dart';
import '../../domain/entities/blacklisted_entry.dart';
import '../../../../core/services/call_log_helper.dart';

class ActivityPage extends ConsumerStatefulWidget {
  const ActivityPage({super.key});

  @override
  ConsumerState<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends ConsumerState<ActivityPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<call_log.CallLogEntry> _recentCalls = [];
  bool _isLoadingCalls = true;
  bool _isAuditingCalls = false;
  String _searchFilter = '';

  String _formatRelativeTime(int? timestampMs, AppLocalizations? l10n) {
    if (timestampMs == null || timestampMs <= 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return l10n?.timeJustNow ?? 'À l\'instant';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    } else if (diff.inHours < 24 && date.day == now.day) {
      final prefix = l10n?.timeTodayAt ?? 'Aujourd\'hui à';
      return '$prefix ${DateFormat('HH:mm').format(date)}';
    } else if (diff.inDays < 2 && date.day == now.subtract(const Duration(days: 1)).day) {
      final prefix = l10n?.timeYesterdayAt ?? 'Hier à';
      return '$prefix ${DateFormat('HH:mm').format(date)}';
    } else {
      return DateFormat('dd/MM HH:mm').format(date);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCallHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCallHistory() async {
    setState(() => _isLoadingCalls = true);
    try {
      final status = await Permission.phone.status;
      if (!status.isGranted) {
        final req = await Permission.phone.request();
        if (!req.isGranted) {
          if (mounted) setState(() => _isLoadingCalls = false);
          return;
        }
      }
      final entries = await CallLogHelper.getSafeEntries(limit: 50);
      if (mounted) {
        setState(() {
          _recentCalls = entries;
          _isLoadingCalls = false;
        });
      }
    } catch (e) {
      AppLogger.log('[ActivityPage] Erreur chargement journal d\'appels: $e');
      if (mounted) setState(() => _isLoadingCalls = false);
    }
  }

  void _showOneTapReportModal(BuildContext context, String rawNumber) {
    String selectedCategory = 'fraud';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final l10n = AppLocalizations.of(context);
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          l10n?.blockAndReport ?? 'Bloquer & Signaler',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    CryptoUtils.maskPhoneNumber(rawNumber),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.accentRed),
                  ),
                  const SizedBox(height: 16),
                  Text(l10n?.reportReason ?? 'Motif du signalement :', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChoiceChip(l10n?.categoryScam ?? 'Arnaque', 'fraud', selectedCategory, (cat) => setModalState(() => selectedCategory = cat)),
                      _buildChoiceChip(l10n?.categoryTelemarketing ?? 'Démarchage', 'telemarketing', selectedCategory, (cat) => setModalState(() => selectedCategory = cat)),
                      _buildChoiceChip(l10n?.categoryPhishing ?? 'Phishing', 'phishing', selectedCategory, (cat) => setModalState(() => selectedCategory = cat)),
                      _buildChoiceChip(l10n?.categoryRobocall ?? 'Automate / Silence', 'robocall', selectedCategory, (cat) => setModalState(() => selectedCategory = cat)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            setModalState(() => isSubmitting = true);
                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(ctx);
                            final result = await ref.read(blacklistProvider.notifier).reportSpam(
                              rawPhoneNumber: rawNumber,
                              category: selectedCategory,
                            );

                            navigator.pop();
                            result.fold(
                              (failure) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text(failure.message), backgroundColor: AppTheme.accentRed),
                                );
                              },
                              (_) async {
                                await CitizenImpactService.incrementReportsCount();
                                ref.read(blacklistControllerProvider.notifier).loadBlacklist();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(l10n?.reportSuccessMessage ?? 'Numéro bloqué et signalé avec succès.'),
                                    backgroundColor: AppTheme.accentGreen,
                                  ),
                                );
                              },
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(l10n?.btnBlockThisNumber ?? 'Bloquer ce numéro', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChoiceChip(String label, String value, String current, ValueChanged<String> onSelected, {Color? activeColor}) {
    final selected = current == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: selected ? Colors.white : null, fontSize: 12)),
      selected: selected,
      selectedColor: activeColor ?? AppTheme.accentRed,
      onSelected: (_) => onSelected(value),
    );
  }

  Future<void> _auditRecentCalls() async {
    if (_isAuditingCalls) return;
    setState(() => _isAuditingCalls = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);

    try {
      final numbersToAudit = _recentCalls
          .map((c) => c.number?.trim() ?? '')
          .where((phoneNum) => phoneNum.isNotEmpty && phoneNum.length >= 7)
          .toSet()
          .toList();

      if (numbersToAudit.isEmpty) {
        if (mounted) setState(() => _isAuditingCalls = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n?.auditNoVerifiableNumbers ?? 'Aucun numéro vérifiable dans le journal récent.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final results = await ApiService().checkNumbersBatch(numbersToAudit);
      if (mounted) setState(() => _isAuditingCalls = false);

      if (results != null) {
        int spamCount = 0;
        results.forEach((phoneStr, data) {
          if (data['is_spam'] == true || (data['risk_score'] as int? ?? 0) >= 50) {
            spamCount++;
          }
        });

        if (spamCount > 0) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(l10n?.auditCompletedSpam(spamCount) ?? 'Audit terminé : $spamCount numéro(s) suspect(s) identifié(s) dans votre journal.'),
              backgroundColor: AppTheme.accentRed,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          messenger.showSnackBar(
            SnackBar(
              content: Text(l10n?.auditCompletedClean(numbersToAudit.length) ?? 'Audit terminé : Vos ${numbersToAudit.length} appels récents sont sains.'),
              backgroundColor: AppTheme.accentGreen,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n?.auditNetworkError ?? 'Impossible d\'effectuer l\'audit réseau.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isAuditingCalls = false);
      AppLogger.log('[ActivityPage] Erreur audit appels: $e');
    }
  }

  void _showBlockedDetailsModal(BuildContext context, BlacklistedEntry item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final l10n = AppLocalizations.of(context);
        final isEn = (l10n?.localeName == 'en') || (Localizations.localeOf(context).languageCode == 'en');
        final catColor = _getCategoryColor(item.category);
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatCategory(item.category, isEn),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: catColor),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.maskedNumber.isNotEmpty ? item.maskedNumber : (l10n?.disputeProtectedNumber ?? 'Numéro protégé'),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.accentRed),
                    const SizedBox(width: 6),
                    Text(
                      l10n?.disputeRiskScore(item.riskScore, item.reportsCount) ?? 'Score de risque : ${item.riskScore}% (${item.reportsCount} signalement(s))',
                      style: const TextStyle(fontSize: 13, color: AppTheme.accentRed, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    l10n?.disputeFilteredNotice ?? 'Ce numéro est actuellement filtré par ShieldNet. S\'il s\'agit d\'un médecin, d\'un livreur ou d\'un proche légitime, vous pouvez contester ce blocage pour accélérer sa réhabilitation.',
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.verified_outlined, size: 18, color: AppTheme.accentGreen),
                        label: Text(
                          l10n?.disputeBtnContest ?? 'Contester (Faux positif)',
                          style: const TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showContestModal(context, item);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showContestModal(BuildContext context, BlacklistedEntry item) {
    String selectedReason = 'service';
    final commentController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final l10n = AppLocalizations.of(context);
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          l10n?.disputeModalTitle ?? 'Contestation de Faux-Positif',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.maskedNumber,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                ),
                const SizedBox(height: 14),
                Text(
                  l10n?.disputeCallNature ?? 'Nature de l\'appel légitime :',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChoiceChip(l10n?.disputeReasonService ?? 'Service / Entreprise', 'service', selectedReason, (r) => setModalState(() => selectedReason = r), activeColor: AppTheme.accentGreen),
                    _buildChoiceChip(l10n?.disputeReasonPersonal ?? 'Personnel / Proche', 'personal', selectedReason, (r) => setModalState(() => selectedReason = r), activeColor: AppTheme.accentGreen),
                    _buildChoiceChip(l10n?.disputeReasonDelivery ?? 'Livraison / Colis', 'delivery', selectedReason, (r) => setModalState(() => selectedReason = r), activeColor: AppTheme.accentGreen),
                    _buildChoiceChip(l10n?.disputeReasonMedical ?? 'Santé / Médical', 'medical', selectedReason, (r) => setModalState(() => selectedReason = r), activeColor: AppTheme.accentGreen),
                    _buildChoiceChip(l10n?.disputeReasonMistake ?? 'Erreur de signalement', 'mistake', selectedReason, (r) => setModalState(() => selectedReason = r), activeColor: AppTheme.accentGreen),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: commentController,
                  maxLength: 500,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: l10n?.disputeCommentHint ?? 'Précisions utiles (ex: cabinet de mon médecin traitant)',
                    hintStyle: const TextStyle(fontSize: 13),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setModalState(() => isSubmitting = true);
                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(ctx);

                          try {
                            // Retrait réactif immédiat de la liste affichée
                            ref.read(blacklistProvider.notifier).removeEntryLocally(item.phoneHash);

                            final res = await ApiService().submitSafeReport(
                              phoneHash: item.phoneHash,
                              maskedNumber: item.maskedNumber,
                              reason: selectedReason,
                              comment: commentController.text.trim(),
                            );

                            nav.pop();
                            if (res != null) {
                              await CitizenImpactService.incrementReportsCount();
                              final isAutoWhitelisted = res['auto_whitelisted'] == true;
                              final isOfflineQueued = res['offline_queued'] == true;

                              String toastMessage;
                              if (isAutoWhitelisted) {
                                toastMessage = 'Numéro débloqué ! Consensus citoyen validé : réhabilité pour toute la communauté.';
                              } else if (isOfflineQueued) {
                                toastMessage = 'Numéro débloqué localement ! Contestation mise en file d\'attente.';
                              } else {
                                toastMessage = l10n?.disputeSuccessToast ?? 'Numéro débloqué sur votre appareil ! Avis transmis pour réhabilitation.';
                              }

                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(toastMessage),
                                  backgroundColor: AppTheme.accentGreen,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } else {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(l10n?.disputeErrorToast ?? 'Impossible d\'enregistrer votre contestation.'),
                                  backgroundColor: AppTheme.accentRed,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            nav.pop();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Erreur: $e'),
                                backgroundColor: AppTheme.accentRed,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          l10n?.disputeSubmitBtn ?? 'Transmettre la contestation',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final blacklistAsync = ref.watch(blacklistControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AppTheme.cardBg(isDark);
    final borderColor = AppTheme.borderColor(isDark);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.activityTitle ?? 'Activité Téléphonique', style: const TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: [
            Tab(text: l10n?.tabRecentCalls ?? 'Appels Récents'),
            Tab(text: l10n?.tabBlockedNumbers ?? 'Numéros Bloqués'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: HISTORIQUE DES APPELS
          _buildCallsTab(blacklistAsync.value ?? [], cardBg, borderColor, l10n),

          // TAB 2: NUMÉROS BLOQUÉS
          _buildBlockedListTab(blacklistAsync, cardBg, borderColor, isDark, l10n),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'fraud':
      case 'arnaque':
        return AppTheme.accentRed;
      case 'telemarketing':
      case 'démarchage':
        return AppTheme.accentOrange;
      case 'phishing':
        return const Color(0xFFDC2626);
      case 'robocall':
      case 'automate':
        return AppTheme.primaryDarkColor;
      default:
        return AppTheme.primaryColor;
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

  Widget _buildCallsTab(List<BlacklistedEntry> blockedList, Color cardBg, Color borderColor, AppLocalizations? l10n) {
    if (_isLoadingCalls) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_recentCalls.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone_paused_rounded, size: 48, color: AppTheme.primaryColor),
              ),
              const SizedBox(height: 18),
              Text(
                l10n?.noRecentCalls ?? 'Aucun appel récent',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                l10n?.noRecentCallsDesc ?? 'Les appels récents s\'afficheront ici avec leur état de sécurité.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    final blockedHashes = blockedList.map((b) => b.phoneHash).toSet();

    final auditHeader = Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.security_update_good_rounded, color: AppTheme.primaryColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.auditHeaderTitle ?? 'Audit de sécurité du journal',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  l10n?.auditHeaderDesc ?? 'Vérifie vos 50 derniers appels via le Cloud',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _isAuditingCalls ? null : _auditRecentCalls,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: _isAuditingCalls
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    l10n?.auditHeaderBtn ?? 'Lancer',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
          ),
        ],
      ),
    );

    return RefreshIndicator(
      onRefresh: _loadCallHistory,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: _recentCalls.length + 1,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (ctx, index) {
          if (index == 0) {
            return auditHeader;
          }
          final call = _recentCalls[index - 1];
          final rawNum = call.number ?? '';
          final hash = rawNum.isNotEmpty ? CryptoUtils.hashPhoneNumber(rawNum) : '';
          final isBlocked = blockedHashes.contains(hash);
          final dateStr = _formatRelativeTime(call.timestamp, l10n);
          final isEn = (l10n?.localeName == 'en') || (Localizations.localeOf(context).languageCode == 'en');

          IconData callIcon;
          Color callColor;
          String statusDesc;

          if (isBlocked || call.callType == call_log.CallType.blocked || call.callType == call_log.CallType.rejected) {
            callIcon = Icons.call_end_rounded;
            callColor = AppTheme.accentRed;
            statusDesc = l10n?.spamBlocked ?? (isEn ? 'Spam bloqué' : 'Spam bloqué');
          } else if (call.callType == call_log.CallType.outgoing) {
            callIcon = Icons.call_made_rounded;
            callColor = AppTheme.primaryColor;
            statusDesc = isEn ? 'Appel sortant' : 'Appel sortant';
          } else if (call.callType == call_log.CallType.missed) {
            callIcon = Icons.call_missed_rounded;
            callColor = AppTheme.accentOrange;
            statusDesc = isEn ? 'Appel manqué' : 'Appel manqué';
          } else {
            callIcon = Icons.call_received_rounded;
            callColor = AppTheme.accentGreen;
            statusDesc = l10n?.incomingCall ?? (isEn ? 'Appel entrant' : 'Appel entrant');
          }

          final defaultUnknown = l10n?.unknownCaller ?? 'Inconnu';
          final titleText = call.name?.isNotEmpty == true ? call.name! : (rawNum.isNotEmpty ? CryptoUtils.maskPhoneNumber(rawNum) : defaultUnknown);

          final itemWidget = Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: callColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  callIcon,
                  color: callColor,
                  size: 20,
                ),
              ),
              title: Text(
                titleText,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '$dateStr • $statusDesc',
                style: TextStyle(fontSize: 12, color: isBlocked ? AppTheme.accentRed : Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: isBlocked
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(l10n?.badgeBlocked ?? 'Bloqué', style: const TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.bold, fontSize: 11)),
                    )
                  : IconButton(
                      icon: const Icon(Icons.shield_outlined, color: AppTheme.accentRed, size: 20),
                      tooltip: l10n?.btnBlockThisNumber ?? 'Bloquer ce numéro',
                      onPressed: rawNum.isNotEmpty
                          ? () {
                              HapticFeedback.lightImpact();
                              _showOneTapReportModal(context, rawNum);
                            }
                          : null,
                    ),
            ),
          );

          if (isBlocked || rawNum.isEmpty) {
            return itemWidget;
          }

          return Dismissible(
            key: ValueKey('call_${call.timestamp}_$index'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppTheme.accentRed,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(l10n?.blockAndReport ?? 'Bloquer & Signaler', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
            confirmDismiss: (direction) async {
              HapticFeedback.mediumImpact();
              _showOneTapReportModal(context, rawNum);
              return false;
            },
            child: itemWidget,
          );
        },
      ),
    );
  }

  Widget _buildBlockedListTab(AsyncValue<List<BlacklistedEntry>> blacklistAsync, Color cardBg, Color borderColor, bool isDark, AppLocalizations? l10n) {
    final isEn = (l10n?.localeName == 'en') || (Localizations.localeOf(context).languageCode == 'en');
    return blacklistAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text(isEn ? 'Error: $err' : 'Erreur: $err')),
      data: (entries) {
        final filtered = entries.where((e) {
          if (_searchFilter.isEmpty) return true;
          return e.maskedNumber.toLowerCase().contains(_searchFilter) ||
              e.category.toLowerCase().contains(_searchFilter);
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: TextField(
                onChanged: (val) => setState(() => _searchFilter = val.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: l10n?.searchBlockedPlaceholder ?? 'Rechercher un numéro bloqué...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppTheme.accentGreen.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.verified_user_rounded, size: 48, color: AppTheme.accentGreen),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              _searchFilter.isEmpty
                                  ? (l10n?.noBlockedNumbers ?? 'Aucun numéro bloqué')
                                  : (l10n?.noResultsFound ?? 'Aucun résultat trouvé'),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _searchFilter.isEmpty
                                  ? (l10n?.noBlockedNumbersDesc ?? 'Tous les numéros signalés ou bloqués par le filtre automatique apparaîtront ici.')
                                  : (l10n?.tryAnotherSearch ?? 'Essayez avec un autre terme de recherche.'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (ctx, index) {
                        final item = filtered[index];
                        final catColor = _getCategoryColor(item.category);
                        return Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: ListTile(
                            onTap: () => _showBlockedDetailsModal(context, item),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.block_rounded, color: catColor, size: 18),
                            ),
                            title: Text(
                              item.maskedNumber.isNotEmpty ? item.maskedNumber : (l10n?.maskedNumberDefault ?? 'Numéro masqué'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Row(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: catColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _formatCategory(item.category, isEn),
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: catColor),
                                  ),
                                ),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.accentRed.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${item.riskScore}% ${l10n?.riskWord ?? "risque"}',
                                style: const TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
