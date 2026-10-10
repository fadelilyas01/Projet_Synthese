import 'package:flutter/material.dart';
import '../../../../core/services/observability_service.dart';

class ObservabilityPage extends StatefulWidget {
  const ObservabilityPage({super.key});

  @override
  State<ObservabilityPage> createState() => _ObservabilityPageState();
}

class _ObservabilityPageState extends State<ObservabilityPage> {
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
                      const Text(
                        'Retour Utilisateur Structuré',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Votre évaluation globale :',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
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
                  const Text(
                    'Catégorie de retour :',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
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
                    items: const [
                      DropdownMenuItem(value: 'Satisfaction', child: Text('Expérience globale & Satisfaction')),
                      DropdownMenuItem(value: 'Bug', child: Text('Anomalie / Bug rencontré')),
                      DropdownMenuItem(value: 'Suggestion', child: Text('Suggestion d\'amélioration')),
                      DropdownMenuItem(value: 'Prise en main', child: Text('Ergonomie / Prise en main')),
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
                      hintText: 'Vos remarques, difficultés ou suggestions pour le jury...',
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
                      label: const Text('Transmettre mon avis', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final comment = commentController.text.trim();
                        final nav = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);

                        await ObservabilityService.instance.submitStructuredFeedback(
                          rating: selectedRating,
                          category: selectedCategory,
                          comment: comment.isEmpty ? 'Évaluation rapide' : comment,
                        );

                        if (!mounted) return;
                        nav.pop();
                        _loadData();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Merci ! Votre avis structuré a été enregistré avec succès.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const featureLabels = {
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
        title: const Text('Observabilité & Adoption', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blueAccent,
        icon: const Icon(Icons.rate_review, color: Colors.white),
        label: const Text('Donner un avis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Observabilité & Adoption',
                                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Métriques anonymes conformes Loi 25 (Sans PII)',
                                    style: TextStyle(color: Colors.white54, fontSize: 12),
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
                                label: 'Actions mesurées',
                                value: '$totalUsage',
                                icon: Icons.touch_app,
                                color: Colors.cyan,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMetricTile(
                                label: 'Retours recueillis',
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
                  const Text(
                    'UTILISATION DES FONCTIONNALITÉS',
                    style: TextStyle(
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
                                      '$count fois (${(fraction * 100).toStringAsFixed(0)}%)',
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
                      const Text(
                        'RETOURS UTILISATEURS STRUCTURÉS',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Ajouter'),
                        onPressed: _showFeedbackModal,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_feedbacks.isEmpty)
                    Card(
                      color: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'Aucun avis soumis pour le moment.\nUtilisez le bouton ci-dessous pour tester le recueil.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white38, fontSize: 13),
                          ),
                        ),
                      ),
                    )
                  else
                    ..._feedbacks.reversed.map((fb) {
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
                                  fb.category,
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
