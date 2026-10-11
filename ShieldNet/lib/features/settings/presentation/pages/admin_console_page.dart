import 'package:shieldnet/core/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/database/database_helper.dart';
import '../widgets/admin_overview_tab.dart';
import '../widgets/admin_blacklist_tab.dart';
import '../widgets/admin_reports_tab.dart';
import '../widgets/admin_users_tab.dart';
import '../widgets/admin_audit_tab.dart';
import 'observability_page.dart';
import '../../../call_filtering/presentation/controllers/blacklist_controller.dart';

class AdminConsolePage extends ConsumerStatefulWidget {
  const AdminConsolePage({super.key});

  @override
  ConsumerState<AdminConsolePage> createState() => _AdminConsolePageState();
}

class _AdminConsolePageState extends ConsumerState<AdminConsolePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Données
  bool _isLoadingStats = true;
  Map<String, dynamic>? _stats;

  bool _isLoadingBlacklist = false;
  List<Map<String, dynamic>> _blacklist = [];
  String _blacklistFilter = 'all';
  final _searchBlacklistController = TextEditingController();
  
  // Pagination
  int _blacklistPage = 1;
  bool _hasMoreBlacklist = true;
  bool _isLoadingMoreBlacklist = false;
  final ScrollController _blacklistScrollController = ScrollController();

  bool _isLoadingReports = false;
  List<Map<String, dynamic>> _reports = [];

  bool _isLoadingUsers = false;
  List<Map<String, dynamic>> _users = [];

  bool _isLoadingAuditLogs = false;
  List<Map<String, dynamic>> _auditLogs = [];

  Map<String, dynamic>? _syncStatus;
  bool _isSyncingClient = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authNotifierProvider);
    final isSuperAdmin = user?.isSuperAdmin ?? false;
    _tabController = TabController(length: isSuperAdmin ? 5 : 4, vsync: this);
    _blacklistScrollController.addListener(_onBlacklistScroll);
    _loadAllAdminData();
  }

  void _onBlacklistScroll() {
    if (_blacklistScrollController.position.pixels >= _blacklistScrollController.position.maxScrollExtent - 200) {
      _loadMoreBlacklist();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchBlacklistController.dispose();
    _blacklistScrollController.dispose();
    super.dispose();
  }

  // ==================== CHARGEMENT DES DONNÉES ====================

  Future<void> _loadAllAdminData() async {
    final user = ref.read(authNotifierProvider);
    _loadStats();
    _loadSyncStatus();
    _loadBlacklist();
    _loadReports();
    if (user?.isSuperAdmin ?? false) {
      _loadUsers();
    }
    _loadAuditLogs();
  }

  Future<void> _loadSyncStatus() async {
    try {
      final auth = ref.read(authServiceProvider);
      final status = await auth.getSyncStatus();
      if (mounted) setState(() => _syncStatus = status);
    } catch (e) {
      AppLogger.log('[AdminConsole] Erreur chargement sync status: $e');
    }
  }

  Future<void> _loadAuditLogs() async {
    setState(() => _isLoadingAuditLogs = true);
    try {
      final auth = ref.read(authServiceProvider);
      final logs = await auth.getAdminAuditLogs();
      if (mounted) setState(() { _auditLogs = logs; _isLoadingAuditLogs = false; });
    } catch (e) {
      AppLogger.log('[AdminConsole] Erreur chargement audit logs: $e');
      if (mounted) setState(() => _isLoadingAuditLogs = false);
    }
  }

  Future<void> _triggerManualSync({required bool delta}) async {
    setState(() => _isSyncingClient = true);
    final l10n = AppLocalizations.of(context);
    final isEn = (l10n?.localeName == 'en') || (Localizations.localeOf(context).languageCode == 'en');
    try {
      final api = ref.read(apiServiceProvider);
      final count = await api.syncBlacklistWithBackend(delta: delta);
      await DatabaseHelper.instance.checkpointWAL();
      ref.invalidate(bloomFilterProvider);
      ref.invalidate(citizenImpactProvider);
      ref.invalidate(offlineQueueCountProvider);
      await ref.read(blacklistControllerProvider.notifier).loadBlacklist();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(delta
                ? (isEn
                    ? 'Differential sync successful: $count item(s) synchronized/purged.'
                    : 'Sync différentielle réussie: $count élément(s) synchronisés/purgés.')
                : (isEn
                    ? 'Full sync successful: $count numbers in local cache.'
                    : 'Sync complète réussie: $count numéros en cache local.')),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
      _loadSyncStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEn ? 'Sync failed: $e' : 'Échec de la synchronisation: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncingClient = false);
    }
  }

  Future<void> _loadStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final auth = ref.read(authServiceProvider);
      final stats = await auth.getAdminStats();
      if (mounted) setState(() { _stats = stats; _isLoadingStats = false; });
    } catch (e) {
      AppLogger.log('[AdminConsole] Erreur chargement statistiques: $e');
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _loadBlacklist({bool refresh = true}) async {
    if (refresh) {
      setState(() {
        _isLoadingBlacklist = true;
        _blacklistPage = 1;
        _hasMoreBlacklist = true;
        _blacklist.clear();
      });
    }

    try {
      final auth = ref.read(authServiceProvider);
      final list = await auth.getAdminBlacklist(
        query: _searchBlacklistController.text.trim(),
        filter: _blacklistFilter,
        page: _blacklistPage,
        limit: 50,
      );
      
      if (mounted) {
        setState(() {
          if (refresh) {
            _blacklist = list;
          } else {
            _blacklist.addAll(list);
          }
          if (list.length < 50) {
            _hasMoreBlacklist = false;
          }
          _isLoadingBlacklist = false;
          _isLoadingMoreBlacklist = false;
        });
      }
    } catch (e) {
      AppLogger.log('[AdminConsole] Erreur chargement liste noire: $e');
      if (mounted) {
        setState(() {
          _isLoadingBlacklist = false;
          _isLoadingMoreBlacklist = false;
        });
      }
    }
  }

  Future<void> _loadMoreBlacklist() async {
    if (_isLoadingBlacklist || _isLoadingMoreBlacklist || !_hasMoreBlacklist) return;
    setState(() {
      _isLoadingMoreBlacklist = true;
      _blacklistPage++;
    });
    await _loadBlacklist(refresh: false);
  }

  Future<void> _loadReports() async {
    setState(() => _isLoadingReports = true);
    try {
      final auth = ref.read(authServiceProvider);
      final reports = await auth.getAdminReports();
      if (mounted) setState(() { _reports = reports; _isLoadingReports = false; });
    } catch (e) {
      AppLogger.log('[AdminConsole] Erreur chargement signalements: $e');
      if (mounted) setState(() => _isLoadingReports = false);
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final auth = ref.read(authServiceProvider);
      final users = await auth.getAdminUsers();
      if (mounted) setState(() { _users = users; _isLoadingUsers = false; });
    } catch (e) {
      AppLogger.log('[AdminConsole] Erreur chargement utilisateurs: $e');
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  // ==================== ACTIONS ====================

  Future<void> _moderate(String phoneHash, String action) async {
    try {
      final auth = ref.read(authServiceProvider);
      final msg = await auth.moderateNumber(phoneHash: phoneHash, action: action);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: action == 'whitelist' ? AppTheme.accentGreen : AppTheme.accentRed),
        );
        _loadStats();
        _loadBlacklist();
        _loadReports();
        _loadAuditLogs();
        _loadSyncStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.accentRed),
        );
      }
    }
  }

  Future<void> _deleteNumber(String phoneHash) async {
    try {
      final auth = ref.read(authServiceProvider);
      await auth.deleteAdminBlacklistNumber(phoneHash);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Numéro supprimé de la liste noire.'), backgroundColor: AppTheme.accentGreen),
        );
        _loadStats();
        _loadBlacklist();
        _loadAuditLogs();
        _loadSyncStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.accentRed),
        );
      }
    }
  }

  Future<void> _deleteReport(String reportId) async {
    try {
      final auth = ref.read(authServiceProvider);
      await auth.deleteAdminReport(reportId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signalement supprimé.'), backgroundColor: AppTheme.accentGreen),
        );
        _loadStats();
        _loadReports();
        _loadAuditLogs();
        _loadSyncStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.accentRed),
        );
      }
    }
  }

  Future<void> _purgeJunk() async {
    try {
      final auth = ref.read(authServiceProvider);
      final res = await auth.purgeDatabase();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['detail'] as String? ?? 'Nettoyage terminé.'), backgroundColor: AppTheme.accentGreen),
        );
        _loadAllAdminData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.accentRed),
        );
      }
    }
  }

  Future<void> _runConsensusAudit() async {
    try {
      final auth = ref.read(authServiceProvider);
      final res = await auth.runConsensusAudit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['detail'] as String? ?? 'Audit de consensualité terminé.'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
        _loadAllAdminData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.accentRed),
        );
      }
    }
  }

  void _showAddNumberDialog() {
    final phoneController = TextEditingController();
    String category = 'fraud';
    int riskScore = 80;
    bool isBlocked = true;
    bool isWhitelisted = false;
    final l10n = AppLocalizations.of(context);
    final isEn = (l10n?.localeName == 'en') || (Localizations.localeOf(context).languageCode == 'en');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.add_moderator_rounded, color: AppTheme.accentOrange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isEn ? 'Add a Number' : 'Ajouter un Numéro',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: isEn ? 'Phone number' : 'Numéro de téléphone',
                    hintText: '+1 819 123 4567',
                    prefixIcon: const Icon(Icons.phone_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: InputDecoration(labelText: isEn ? 'Category' : 'Catégorie'),
                  items: [
                    DropdownMenuItem(value: 'fraud', child: Text(isEn ? 'Fraud / Scam' : 'Fraude / Arnaque')),
                    DropdownMenuItem(value: 'financial_scam', child: Text(isEn ? 'Financial Scam' : 'Arnaque Financière')),
                    DropdownMenuItem(value: 'phishing', child: Text(isEn ? 'Phishing' : 'Hameçonnage / Phishing')),
                    DropdownMenuItem(value: 'robocall', child: Text(isEn ? 'Automated Robocall' : 'Robocall Automatisé')),
                    DropdownMenuItem(value: 'telemarketing', child: Text(isEn ? 'Commercial Telemarketing' : 'Démarchage Commercial')),
                    DropdownMenuItem(value: 'other', child: Text(isEn ? 'Other Nuisance' : 'Autre Nuisance')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => category = val);
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  isEn ? 'Risk Score : $riskScore/100' : 'Score de Risque : $riskScore/100',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Slider(
                  value: riskScore.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '$riskScore',
                  onChanged: (val) => setDialogState(() => riskScore = val.toInt()),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(isEn ? 'Block immediately' : 'Bloquer immédiatement', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  value: isBlocked,
                  onChanged: (val) => setDialogState(() {
                    isBlocked = val;
                    if (val) isWhitelisted = false;
                  }),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(isEn ? 'Whitelist (False positive)' : 'Blanchir (Faux positif)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  value: isWhitelisted,
                  onChanged: (val) => setDialogState(() {
                    isWhitelisted = val;
                    if (val) isBlocked = false;
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isEn ? 'Cancel' : 'Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final phone = phoneController.text.trim();
                if (phone.isEmpty) return;
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                try {
                  final auth = ref.read(authServiceProvider);
                  await auth.addAdminBlacklistNumber(
                    phoneNumber: phone,
                    category: category,
                    riskScore: riskScore,
                    isBlocked: isBlocked,
                    isWhitelisted: isWhitelisted,
                  );
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(isEn ? 'Number registered successfully.' : 'Numéro enregistré avec succès.'),
                      backgroundColor: AppTheme.accentGreen,
                    ),
                  );
                  _loadAllAdminData();
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(isEn ? 'Error: $e' : 'Erreur: $e'), backgroundColor: AppTheme.accentRed),
                  );
                }
              },
              child: Text(isEn ? 'Save' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final user = ref.watch(authNotifierProvider);
    final isSuperAdmin = user?.isSuperAdmin ?? false;
    final l10n = AppLocalizations.of(context);
    final isEn = (l10n?.localeName == 'en') || (Localizations.localeOf(context).languageCode == 'en');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              isSuperAdmin ? Icons.admin_panel_settings_rounded : Icons.verified_user_rounded,
              color: isSuperAdmin ? AppTheme.accentOrange : AppTheme.primaryColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isSuperAdmin
                    ? (l10n?.adminFullAdmin ?? (isEn ? 'Full Administration' : 'Administration Totale'))
                    : (l10n?.adminManagerSpace ?? (isEn ? 'Manager Space & Moderation' : 'Espace Gestionnaire & Modération')),
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: isEn ? 'Observability & Feedback' : 'Observabilité & Retours Utilisateurs',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ObservabilityPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: l10n?.adminRefreshAll ?? (isEn ? 'Refresh all' : 'Tout actualiser'),
            onPressed: _loadAllAdminData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: isSuperAdmin ? AppTheme.accentOrange : AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: isSuperAdmin ? AppTheme.accentOrange : AppTheme.primaryColor,
          tabs: [
            Tab(icon: const Icon(Icons.dashboard_rounded), text: l10n?.adminTabOverview ?? (isEn ? 'Overview' : 'Vue d\'ensemble')),
            Tab(icon: const Icon(Icons.format_list_bulleted_rounded), text: l10n?.adminTabBlacklist ?? (isEn ? 'Blacklist' : 'Liste Noire')),
            Tab(icon: const Icon(Icons.report_problem_rounded), text: l10n?.adminTabReports ?? (isEn ? 'Reports' : 'Signalements')),
            if (isSuperAdmin)
              Tab(icon: const Icon(Icons.people_alt_rounded), text: l10n?.adminTabUsers ?? (isEn ? 'Users' : 'Utilisateurs')),
            Tab(icon: const Icon(Icons.history_rounded), text: l10n?.adminTabAudit ?? (isEn ? 'Audit & Logs' : 'Audit & Traces')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          AdminOverviewTab(
            stats: _stats,
            syncStatus: _syncStatus,
            isLoadingStats: _isLoadingStats,
            isSyncingClient: _isSyncingClient,
            onPurge: _purgeJunk,
            onConsensusAudit: _runConsensusAudit,
            onDeltaSync: () => _triggerManualSync(delta: true),
            onFullSync: () => _triggerManualSync(delta: false),
            onRefresh: _loadAllAdminData,
          ),
          AdminBlacklistTab(
            blacklist: _blacklist,
            isLoading: _isLoadingBlacklist,
            hasMore: _hasMoreBlacklist,
            currentFilter: _blacklistFilter,
            searchController: _searchBlacklistController,
            scrollController: _blacklistScrollController,
            onFilterChanged: (filter) { setState(() => _blacklistFilter = filter); _loadBlacklist(); },
            onSearch: () => _loadBlacklist(),
            onClearSearch: () { _searchBlacklistController.clear(); _loadBlacklist(); },
            onModerate: _moderate,
            onDelete: _deleteNumber,
          ),
          AdminReportsTab(
            reports: _reports,
            isLoading: _isLoadingReports,
            onModerate: _moderate,
            onDeleteReport: _deleteReport,
          ),
          if (isSuperAdmin)
            AdminUsersTab(
              users: _users,
              isLoading: _isLoadingUsers,
            ),
          AdminAuditTab(
            auditLogs: _auditLogs,
            isLoading: _isLoadingAuditLogs,
            onRefresh: _loadAuditLogs,
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.accentOrange,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n?.adminAddNumber ?? (isEn ? 'Add a Number' : 'Ajouter un Numéro')),
              onPressed: _showAddNumberDialog,
            )
          : null,
    );
  }
}
