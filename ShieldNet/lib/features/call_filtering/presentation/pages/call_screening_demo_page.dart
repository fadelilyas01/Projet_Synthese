import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/demo_mode_service.dart';
import '../../../../core/services/observability_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Page de Démonstration Visuelle du Filtrage d'Appels en Temps Réel
/// Permet à un jury ou client d'observer la mécanique d'interception d'appel
/// native Android CallScreeningService sans faire sonner le téléphone.
class CallScreeningDemoPage extends StatefulWidget {
  const CallScreeningDemoPage({super.key});

  @override
  State<CallScreeningDemoPage> createState() => _CallScreeningDemoPageState();
}

class _CallScreeningDemoPageState extends State<CallScreeningDemoPage> with SingleTickerProviderStateMixin {
  int _selectedScenarioIndex = 0;
  bool _isSimulating = false;
  bool _simulationDone = false;
  Map<String, dynamic>? _lastResult;
  final List<String> _consoleLogs = [];
  final ScrollController _logScrollController = ScrollController();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  void _addLog(String log) {
    if (!mounted) return;
    setState(() {
      _consoleLogs.add(log);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startSimulation() async {
    HapticFeedback.heavyImpact();
    ObservabilityService.instance.recordFeatureUsage('call_screening_demo');
    setState(() {
      _isSimulating = true;
      _simulationDone = false;
      _consoleLogs.clear();
      _lastResult = null;
    });

    final scenario = DemoModeService.demoScenarios[_selectedScenarioIndex];
    final callerName = scenario['caller_name'] as String;
    final phoneNumber = scenario['phone_number'] as String;
    final isBlocked = scenario['is_blocked'] as bool;
    final category = scenario['category'] as String;
    final riskScore = scenario['risk_score'] as int;
    final ms = scenario['processing_time_ms'] as double;

    _addLog('[0.0ms] 📞 TelecomManager : Détection d\'appel entrant : $callerName ($phoneNumber)...');
    await Future.delayed(const Duration(milliseconds: 300));

    _addLog('[0.5ms] 🛡️ ShieldNetCallScreeningService.onScreenCall(details) activé');
    await Future.delayed(const Duration(milliseconds: 250));

    _addLog('[1.1ms] 🔄 Normalisation E.164 : $phoneNumber validé');
    await Future.delayed(const Duration(milliseconds: 250));

    _addLog('[1.8ms] 🔐 Android Keystore HMAC-SHA256 : Sel matériel appliqué');
    await Future.delayed(const Duration(milliseconds: 300));

    if (isBlocked) {
      _addLog('[2.3ms] 🔍 SQLite Index Query : Correspondance trouvée dans liste noire !');
      _addLog('        ↳ Catégorie: $category | Score de risque: $riskScore%');
      await Future.delayed(const Duration(milliseconds: 200));

      _addLog('[${ms}ms] 🚫 CallResponse.Builder().setDisallowCall(true).setRejectCall(true)');
      _addLog('[${ms}ms] ✅ RÉSULTAT : APPEL REJETÉ SILENCIEUSEMENT AVANT TOUTE SONNERIE.');
    } else {
      _addLog('[1.9ms] 🏛️ EmergencyWhitelistService : Vérification de priorité vitale');
      _addLog('        ↳ Numéro institutionnel ou d\'urgence reconnu');
      await Future.delayed(const Duration(milliseconds: 200));

      _addLog('[${ms}ms] 🟢 CallResponse.Builder().setDisallowCall(false).build()');
      _addLog('[${ms}ms] ✅ RÉSULTAT : APPEL AUTORISÉ (Priorité citoyenne garantie).');
    }

    if (mounted) {
      setState(() {
        _isSimulating = false;
        _simulationDone = true;
        _lastResult = {
          ...scenario,
          'executed_ms': ms,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AppTheme.cardBg(isDark);
    final borderColor = AppTheme.borderColor(isDark);
    final currentScenario = DemoModeService.demoScenarios[_selectedScenarioIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulateur de Filtrage d\'Appels', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.accentCyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.speed_rounded, color: AppTheme.accentCyan, size: 14),
                SizedBox(width: 4),
                Text('< 3 ms local', style: TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.bold, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Bannière explicative
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                    : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phone_locked_rounded, color: AppTheme.primaryColor, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Interception Native Android',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Démontre le rejet silencieux en temps réel par CallScreeningService sans sonnerie ni latence réseau.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Sélecteur de scénarios
          const Text(
            'CHOISIR UN SCÉNARIO D\'APPEL ENTRANT',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.0),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(DemoModeService.demoScenarios.length, (idx) {
                final sc = DemoModeService.demoScenarios[idx];
                final isSelected = _selectedScenarioIndex == idx;
                final isBlocked = sc['is_blocked'] as bool;
                final color = isBlocked ? AppTheme.accentRed : AppTheme.accentGreen;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isBlocked ? Icons.block_rounded : Icons.verified_rounded,
                          size: 14,
                          color: isSelected ? Colors.white : color,
                        ),
                        const SizedBox(width: 6),
                        Text(sc['caller_name'] as String),
                      ],
                    ),
                    selected: isSelected,
                    selectedColor: isBlocked ? AppTheme.accentRed : AppTheme.accentGreen,
                    backgroundColor: cardBg,
                    side: BorderSide(color: isSelected ? Colors.transparent : borderColor),
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _selectedScenarioIndex = idx;
                          _simulationDone = false;
                          _consoleLogs.clear();
                        });
                      }
                    },
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),

          // Carte de simulation d'appel
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _simulationDone
                    ? ((_lastResult?['is_blocked'] == true) ? AppTheme.accentRed : AppTheme.accentGreen)
                    : borderColor,
                width: _simulationDone ? 1.8 : 1.0,
              ),
              boxShadow: [
                if (_simulationDone)
                  BoxShadow(
                    color: ((_lastResult?['is_blocked'] == true) ? AppTheme.accentRed : AppTheme.accentGreen)
                        .withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Column(
              children: [
                // Avatar animé de l'appel entrant
                ScaleTransition(
                  scale: _isSimulating
                      ? Tween<double>(begin: 0.95, end: 1.06).animate(_pulseController)
                      : const AlwaysStoppedAnimation(1.0),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _simulationDone
                          ? ((_lastResult?['is_blocked'] == true)
                              ? AppTheme.accentRed.withValues(alpha: 0.15)
                              : AppTheme.accentGreen.withValues(alpha: 0.15))
                          : AppTheme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _simulationDone
                          ? ((_lastResult?['is_blocked'] == true)
                              ? Icons.call_end_rounded
                              : Icons.call_made_rounded)
                          : Icons.ring_volume_rounded,
                      size: 40,
                      color: _simulationDone
                          ? ((_lastResult?['is_blocked'] == true)
                              ? AppTheme.accentRed
                              : AppTheme.accentGreen)
                          : AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                Text(
                  currentScenario['caller_name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  currentScenario['phone_number'] as String,
                  style: const TextStyle(fontSize: 14, color: Colors.grey, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 8),

                // Badge d'état
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: (currentScenario['is_blocked'] as bool)
                        ? AppTheme.accentRed.withValues(alpha: 0.12)
                        : AppTheme.accentGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    (currentScenario['is_blocked'] as bool)
                        ? 'MENACE IDENTIFIÉE • SCORE ${currentScenario['risk_score']}%'
                        : 'NUMÉRO AUTHENTIFIÉ ET SÉCURISÉ',
                    style: TextStyle(
                      color: (currentScenario['is_blocked'] as bool) ? AppTheme.accentRed : AppTheme.accentGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Bouton de déclenchement de la simulation
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isSimulating ? null : _startSimulation,
                    icon: _isSimulating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.play_arrow_rounded, size: 22),
                    label: Text(
                      _isSimulating
                          ? 'Interception en cours...'
                          : (_simulationDone ? 'Rejouer la Démonstration' : 'Simuler l\'Appel Entrant'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Console de logs natifs en temps réel
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LOGS DU SERVICE NATIF (CALLSCREENING)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.0),
              ),
              if (_consoleLogs.isNotEmpty)
                Text(
                  '${_consoleLogs.length} événements',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ),
          const SizedBox(height: 8),

          Container(
            height: 180,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF090D16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: _consoleLogs.isEmpty
                ? const Center(
                    child: Text(
                      'Appuyez sur "Simuler l\'Appel Entrant" pour visualiser l\'exécution native...',
                      style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    controller: _logScrollController,
                    itemCount: _consoleLogs.length,
                    itemBuilder: (context, idx) {
                      final line = _consoleLogs[idx];
                      Color logColor = const Color(0xFF94A3B8);
                      if (line.contains('REJETÉ')) logColor = const Color(0xFFEF4444);
                      if (line.contains('AUTORISÉ')) logColor = const Color(0xFF10B981);
                      if (line.contains('SQLite')) logColor = const Color(0xFF38BDF8);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          line,
                          style: TextStyle(color: logColor, fontSize: 11.5, fontFamily: 'monospace'),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 24),

          // Tableau comparatif : Filtrage Local ShieldNet vs Traitement Cloud Distant
          const Text(
            'POURQUOI LE TRAITEMENT LOCAL EST SUPÉRIEUR',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.0),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                _buildComparisonRow(
                  label: 'Temps de décision',
                  shieldNetValue: '2.4 ms',
                  shieldNetGood: true,
                  cloudValue: '650 - 1200 ms',
                  cloudGood: false,
                ),
                const Divider(height: 20),
                _buildComparisonRow(
                  label: 'Confidentialité (Loi 25)',
                  shieldNetValue: '0 octet transmis (100% privé)',
                  shieldNetGood: true,
                  cloudValue: 'Numéro & IP envoyés au serveur',
                  cloudGood: false,
                ),
                const Divider(height: 20),
                _buildComparisonRow(
                  label: 'Fonctionnement hors-ligne',
                  shieldNetValue: 'Oui (Métro, Mode Avion)',
                  shieldNetGood: true,
                  cloudValue: 'Non (Échec si coupure 4G/5G)',
                  cloudGood: false,
                ),
                const Divider(height: 20),
                _buildComparisonRow(
                  label: 'Impact Batterie',
                  shieldNetValue: 'Négligeable (Index B-Tree SQLite)',
                  shieldNetGood: true,
                  cloudValue: 'Élevé (Sockets & requêtes HTTP)',
                  cloudGood: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow({
    required String label,
    required String shieldNetValue,
    required bool shieldNetGood,
    required String cloudValue,
    required bool cloudGood,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'ShieldNet: $shieldNetValue',
                        style: const TextStyle(color: AppTheme.accentGreen, fontSize: 11, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off_rounded, color: Colors.grey, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Cloud: $cloudValue',
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
