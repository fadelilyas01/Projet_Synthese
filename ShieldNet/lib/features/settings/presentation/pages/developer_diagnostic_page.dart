import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_theme.dart';
import 'observability_page.dart';

/// Page d'outils avancés & diagnostic technique (isolée pour ne pas surcharger l'utilisateur)
class DeveloperDiagnosticPage extends ConsumerStatefulWidget {
  const DeveloperDiagnosticPage({super.key});

  @override
  ConsumerState<DeveloperDiagnosticPage> createState() => _DeveloperDiagnosticPageState();
}

class _DeveloperDiagnosticPageState extends ConsumerState<DeveloperDiagnosticPage> {
  bool _isTestingBridge = false;
  Map<String, dynamic>? _bridgeDiagnostic;
  final TextEditingController _testPhoneController = TextEditingController();
  bool? _testPhoneBlockedResult;
  bool _isTestingPhone = false;
  String? _apiTestResult;
  bool _isTestingApi = false;
  String _dbPath = '';

  @override
  void initState() {
    super.initState();
    _loadDbPath();
    _runBridgeDiagnostic(silent: true);
  }

  @override
  void dispose() {
    _testPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadDbPath() async {
    try {
      final db = await DatabaseHelper.instance.database;
      if (mounted) setState(() => _dbPath = db.path);
    } catch (_) {}
  }

  Future<void> _runBridgeDiagnostic({bool silent = false}) async {
    if (!silent) setState(() => _isTestingBridge = true);
    final screeningService = ref.read(callScreeningServiceProvider);
    final diag = await screeningService.testDatabaseBridge();

    if (mounted) {
      setState(() {
        _bridgeDiagnostic = diag;
        _isTestingBridge = false;
      });

      if (!silent) {
        final isEn = ref.read(localeProvider).languageCode == 'en';
        final isOk = diag['connected'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(diag['message']?.toString() ?? (isOk ? (isEn ? 'Native bridge active' : 'Pont natif actif') : (isEn ? 'Native bridge error' : 'Erreur pont natif'))),
            backgroundColor: isOk ? AppTheme.accentGreen : AppTheme.accentRed,
          ),
        );
      }
    }
  }

  Future<void> _testNumberWithNative() async {
    final number = _testPhoneController.text.trim();
    if (number.isEmpty) return;

    setState(() {
      _isTestingPhone = true;
      _testPhoneBlockedResult = null;
    });

    final screeningService = ref.read(callScreeningServiceProvider);
    final isBlocked = await screeningService.checkNumberWithNative(number);

    if (mounted) {
      setState(() {
        _testPhoneBlockedResult = isBlocked;
        _isTestingPhone = false;
      });
    }
  }

  Future<void> _forceWALCheckpoint() async {
    await DatabaseHelper.instance.checkpointWAL();
    await _runBridgeDiagnostic(silent: true);
    if (mounted) {
      final isEn = ref.read(localeProvider).languageCode == 'en';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEn ? 'SQLite WAL checkpoint forced successfully.' : 'Checkpoint SQLite WAL forcé avec succès.'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    }
  }

  Future<void> _testApiConnection() async {
    setState(() {
      _isTestingApi = true;
      _apiTestResult = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final stopwatch = Stopwatch()..start();
      await api.checkNumberOnBackend('+10000000000');
      stopwatch.stop();

      if (mounted) {
        final isEn = ref.read(localeProvider).languageCode == 'en';
        setState(() {
          _isTestingApi = false;
          _apiTestResult = isEn ? 'API Connected (${stopwatch.elapsedMilliseconds} ms)' : 'API Connectée (${stopwatch.elapsedMilliseconds} ms)';
        });
      }
    } catch (e) {
      if (mounted) {
        final isEn = ref.read(localeProvider).languageCode == 'en';
        setState(() {
          _isTestingApi = false;
          _apiTestResult = isEn ? 'Error: $e' : 'Erreur: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final isEn = ref.watch(localeProvider).languageCode == 'en';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AppTheme.cardBg(isDark);
    final borderColor = AppTheme.borderColor(isDark);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEn ? 'Technical Diagnostics & Tools' : 'Diagnostic & Outils Avancés',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // Pont Natif
          _buildCard(
            cardBg: cardBg,
            borderColor: borderColor,
            children: [
              ListTile(
                title: Text(isEn ? 'Native Bridge SQLite ↔ Android' : 'Pont Natif SQLite ↔ Android', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  _bridgeDiagnostic?['connected'] == true
                      ? (isEn ? 'Operational (${_bridgeDiagnostic?['count'] ?? 0} numbers read by Android)' : 'Opérationnel (${_bridgeDiagnostic?['count'] ?? 0} numéros lus par Android)')
                      : (isEn ? 'Not connected' : 'Non connecté'),
                  style: TextStyle(
                    color: _bridgeDiagnostic?['connected'] == true ? AppTheme.accentGreen : AppTheme.accentRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: _isTestingBridge
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : ElevatedButton(
                        onPressed: () => _runBridgeDiagnostic(silent: false),
                        child: Text(isEn ? 'Test' : 'Tester'),
                      ),
              ),
              if (_bridgeDiagnostic != null) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isEn ? 'DB Path: ${_bridgeDiagnostic!['path']}' : 'Emplacement DB : ${_bridgeDiagnostic!['path']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(isEn ? 'Message: ${_bridgeDiagnostic!['message']}' : 'Message : ${_bridgeDiagnostic!['message']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isEn ? 'Test a number with Kotlin Telecom:' : 'Tester un numéro avec Kotlin Telecom :', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _testPhoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              hintText: '+18005550199',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isTestingPhone ? null : _testNumberWithNative,
                          child: _isTestingPhone
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(isEn ? 'Verify' : 'Vérifier'),
                        ),
                      ],
                    ),
                    if (_testPhoneBlockedResult != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _testPhoneBlockedResult == true
                            ? (isEn ? 'Verdict: BLOCKED (Present in blacklist)' : 'Verdict : BLOQUÉ (Présent dans la blacklist)')
                            : (isEn ? 'Verdict: ALLOWED' : 'Verdict : AUTORISÉ'),
                        style: TextStyle(
                          color: _testPhoneBlockedResult == true ? AppTheme.accentRed : AppTheme.accentGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Forcer Checkpoint WAL
          _buildCard(
            cardBg: cardBg,
            borderColor: borderColor,
            children: [
              ListTile(
                title: Text(isEn ? 'SQLite WAL Synchronization' : 'Synchronisation SQLite WAL', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(isEn ? 'Forces WAL transaction commit to disk' : 'Force l\'écriture des transactions WAL sur le disque', style: const TextStyle(fontSize: 12)),
                trailing: ElevatedButton(
                  onPressed: _forceWALCheckpoint,
                  child: Text(isEn ? 'Force WAL' : 'Forcer WAL'),
                ),
              ),
              if (_dbPath.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(isEn ? 'Local file: $_dbPath' : 'Fichier local : $_dbPath', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Test Connexion Backend
          _buildCard(
            cardBg: cardBg,
            borderColor: borderColor,
            children: [
              ListTile(
                title: Text(isEn ? 'Django Backend Connection' : 'Connexion Backend Django', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000/api/v1', style: const TextStyle(fontSize: 11)),
                trailing: ElevatedButton(
                  onPressed: _isTestingApi ? null : _testApiConnection,
                  child: _isTestingApi
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(isEn ? 'Test API' : 'Tester API'),
                ),
              ),
              if (_apiTestResult != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    _apiTestResult!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: (_apiTestResult!.startsWith('API Connectée') || _apiTestResult!.startsWith('API Connected')) ? AppTheme.accentGreen : AppTheme.accentRed,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCard(
            cardBg: cardBg,
            borderColor: borderColor,
            children: [
              ListTile(
                leading: const Icon(Icons.analytics_rounded, color: Colors.cyan),
                title: Text(
                  isEn ? 'Observability & User Feedback' : 'Observabilité & Retours Utilisateurs',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  isEn
                      ? 'View feature telemetry and structured feedback logs'
                      : 'Télémétrie d\'utilisation et retours utilisateurs structurés',
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
        ],
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
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }
}
