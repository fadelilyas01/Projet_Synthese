import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/services/observability_service.dart';

class ObservabilityPage extends ConsumerStatefulWidget {
  const ObservabilityPage({super.key});

  @override
  ConsumerState<ObservabilityPage> createState() => _ObservabilityPageState();
}

class _ObservabilityPageState extends ConsumerState<ObservabilityPage> {
  Map<String, int> _usageStats = {};
  List<StructuredFeedback> _feedbacks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final stats = await ObservabilityService.instance.getFeatureUsageStats();
    final feedbacks = await ObservabilityService.instance.getAllFeedbacks();
    if (mounted) {
      setState(() {
        _usageStats = stats;
        _feedbacks = feedbacks;
        _isLoading = false;
      });
    }
  }

  void _showFeedbackModal() {
    final isEn = ref.read(localeProvider).languageCode == 'en';
    int selectedRating = 5;
    String selectedCategory = 'Satisfaction';
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.rate_review, color: Colors.amber, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isEn ? 'Structured User Feedback' : 'Retour Utilisateur Structuré',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  Text(
                    isEn ? 'Your overall rating:' : 'Votre évaluation globale :',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starValue = index + 1;
                      return IconButton(
                        icon: Icon(
                          starValue <= selectedRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () {
                          setModalState(() => selectedRating = starValue);
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isEn ? 'Feedback category:' : 'Catégorie de retour :',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    dropdownColor: const Color(0xFF0F172A),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'Satisfaction',
                        child: Text(isEn ? 'Overall experience & Satisfaction' : 'Expérience globale & Satisfaction'),
                      ),
                      DropdownMenuItem(
                        value: 'Bug',
                        child: Text(isEn ? 'Issue / Bug encountered' : 'Anomalie / Bug rencontré'),
                      ),
                      DropdownMenuItem(
                        value: 'Suggestion',
                        child: Text(isEn ? 'Improvement suggestion' : 'Suggestion d\'amélioration'),
                      ),
                      DropdownMenuItem(
                        value: 'Prise en main',
                        child: Text(isEn ? 'Ergonomics / Ease of use' : 'Ergonomie / Prise en main'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: isEn
                          ? 'Your remarks, difficulties, or suggestions...'
                          : 'Vos remarques, difficultés ou suggestions...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.send, size: 18),
                      label: Text(
                        isEn ? 'Submit my feedback' : 'Transmettre mon avis',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        final comment = commentController.text.trim();
                        final nav = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);

                        await ObservabilityService.instance.submitStructuredFeedback(
                          rating: selectedRating,
                          category: selectedCategory,
                          comment: comment.isEmpty ? (isEn ? 'Quick evaluation' : 'Évaluation rapide') : comment,
                        );

                        if (!mounted) return;
                        nav.pop();
                        _loadData();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              isEn
                                  ? 'Thank you! Your structured feedback has been recorded.'
                                  : 'Merci ! Votre avis structuré a été enregistré avec succès.',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final isEn = ref.watch(localeProvider).languageCode == 'en';

    final featureLabels = isEn
        ? {
            'sms_inspection': 'Fraudulent SMS Inspector',
            'call_screening_demo': 'Native Call Screening Demo',
            'compliance_check': 'Law 25 Compliance Check',
            'threat_map_view': 'Regional Threat Heatmap',
            'whitelist_addition': 'Whitelist Addition',
            'dispute_filed': 'False-Positive Dispute',
            'offline_sync': 'Local Delta Sync',
          }
        : {
            'sms_inspection': 'Analyseur de SMS frauduleux',
            'call_screening_demo': 'Simulateur d\'appels natif',
            'compliance_check': 'Consultation Conformité Loi 25',
            'threat_map_view': 'Carte des menaces régionales',
            'whitelist_addition': 'Ajout en Liste Blanche',
            'dispute_filed': 'Contestation faux-positif',
            'offline_sync': 'Synchronisation Delta locale',
          };

    final totalUsage = _usageStats.values.fold<int>(0, (sum, count) => sum + count);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          isEn ? 'Observability & Adoption' : 'Observabilité & Adoption',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: isEn ? 'Refresh' : 'Actualiser',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blueAccent,
        icon: const Icon(Icons.rate_review, color: Colors.white),
        label: Text(
          isEn ? 'Leave feedback' : 'Donner un avis',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: _showFeedbackModal,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Carte de synthèse
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFF1E293B), const Color(0xFF334155).withValues(alpha: 0.5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.cyan.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.insights, color: Colors.cyan, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isEn ? 'Observability & Adoption' : 'Observabilité & Adoption',
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    isEn
                                        ? 'Anonymous Law 25 compliant metrics (Zero PII)'
                                        : 'Métriques anonymes conformes Loi 25 (Sans PII)',
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricTile(
                                label: isEn ? 'Measured actions' : 'Actions mesurées',
                                value: '$totalUsage',
                                icon: Icons.touch_app,
                                color: Colors.cyan,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMetricTile(
                                label: isEn ? 'Feedbacks collected' : 'Retours recueillis',
                                value: '${_feedbacks.length}',
                                icon: Icons.rate_review,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Section Fonctionnalités les plus utilisées
                  Text(
                    isEn ? 'FEATURE USAGE' : 'UTILISATION DES FONCTIONNALITÉS',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Card(
                    color: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: featureLabels.entries.map((entry) {
                          final count = _usageStats[entry.key] ?? 0;
                          final fraction = totalUsage > 0 ? count / totalUsage : 0.0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      entry.value,
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      '$count ${isEn ? "times" : "fois"} (${(fraction * 100).toStringAsFixed(0)}%)',
                                      style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: fraction,
                                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyan),
                                    minHeight: 6,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Section Retours utilisateurs
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEn ? 'STRUCTURED USER FEEDBACK' : 'RETOURS UTILISATEURS STRUCTURÉS',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(isEn ? 'Add' : 'Ajouter'),
                        onPressed: _showFeedbackModal,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_feedbacks.isEmpty)
                    Card(
                      color: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            isEn
                                ? 'No feedback submitted yet.\nUse the button below to test collection.'
                                : 'Aucun avis soumis pour le moment.\nUtilisez le bouton ci-dessous pour tester le recueil.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white38, fontSize: 13),
                          ),
                        ),
                      ),
                    )
                  else
                    ..._feedbacks.reversed.map((fb) {
                      String displayedCategory = fb.category;
                      if (isEn) {
                        if (fb.category == 'Prise en main') displayedCategory = 'Ease of use';
                      }
                      return Card(
                        color: const Color(0xFF1E293B),
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Row(
                            children: [
                              ...List.generate(
                                fb.rating,
                                (i) => const Icon(Icons.star, color: Colors.amber, size: 16),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  displayedCategory,
                                  style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              fb.comment,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ),
                          trailing: Text(
                            '${fb.submittedAt.hour.toString().padLeft(2, '0')}:${fb.submittedAt.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
