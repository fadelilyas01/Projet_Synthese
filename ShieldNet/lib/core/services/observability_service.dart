import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// Modèle pour un retour utilisateur structuré
class StructuredFeedback {
  final String id;
  final int rating; // 1 à 5 étoiles
  final String category; // 'Satisfaction', 'Bug', 'Suggestion', 'Prise en main'
  final String comment;
  final DateTime submittedAt;

  StructuredFeedback({
    required this.id,
    required this.rating,
    required this.category,
    required this.comment,
    required this.submittedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'rating': rating,
    'category': category,
    'comment': comment,
    'submittedAt': submittedAt.toIso8601String(),
  };

  factory StructuredFeedback.fromMap(Map<String, dynamic> map) => StructuredFeedback(
    id: map['id'] ?? '',
    rating: map['rating'] ?? 5,
    category: map['category'] ?? 'Satisfaction',
    comment: map['comment'] ?? '',
    submittedAt: DateTime.tryParse(map['submittedAt'] ?? '') ?? DateTime.now(),
  );
}

/// Service d'Observabilité Utilisateur & Mesure d'Adoption (Pillar 14)
/// 100% conforme à la Loi 25 (Zéro-Collecte de PII, métriques strictement agrégées en local).
class ObservabilityService {
  static final ObservabilityService instance = ObservabilityService._internal();
  ObservabilityService._internal();

  static const String _prefUsagePrefix = 'obs_usage_';
  static const String _prefFeedbackListKey = 'obs_feedback_list';

  /// Enregistre une interaction avec une fonctionnalité clé
  Future<void> recordFeatureUsage(String featureKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefUsagePrefix$featureKey';
      final current = prefs.getInt(key) ?? 0;
      await prefs.setInt(key, current + 1);
      AppLogger.log('[Observability] Feature $featureKey incrémentée à ${current + 1}');
    } catch (e) {
      if (kDebugMode) print('Erreur observability: $e');
    }
  }

  /// Récupère le dictionnaire de comptage des fonctionnalités
  Future<Map<String, int>> getFeatureUsageStats() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = [
      'sms_inspection',
      'call_screening_demo',
      'compliance_check',
      'threat_map_view',
      'whitelist_addition',
      'dispute_filed',
      'offline_sync',
    ];

    final stats = <String, int>{};
    for (final k in keys) {
      stats[k] = prefs.getInt('$_prefUsagePrefix$k') ?? 0;
    }
    return stats;
  }

  /// Enregistre un avis utilisateur structuré
  Future<void> submitStructuredFeedback({
    required int rating,
    required String category,
    required String comment,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getStringList(_prefFeedbackListKey) ?? [];
      
      final feedback = StructuredFeedback(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        rating: rating,
        category: category,
        comment: comment.trim(),
        submittedAt: DateTime.now(),
      );

      listJson.add(jsonEncode(feedback.toMap()));
      await prefs.setStringList(_prefFeedbackListKey, listJson);
      AppLogger.log('[Observability] Nouveau retour enregistré : ${feedback.category} ($rating/5)');
    } catch (e) {
      if (kDebugMode) print('Erreur enregistrement feedback: $e');
    }
  }

  /// Récupère tous les retours enregistrés
  Future<List<StructuredFeedback>> getAllFeedbacks() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_prefFeedbackListKey) ?? [];
    return rawList.map((raw) {
      try {
        return StructuredFeedback.fromMap(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<StructuredFeedback>().toList();
  }

  /// Réinitialise les métriques (utile pour les démonstrations de jury)
  Future<void> resetMetrics() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys().where((k) => k.startsWith(_prefUsagePrefix));
    for (final key in allKeys) {
      await prefs.remove(key);
    }
    await prefs.remove(_prefFeedbackListKey);
  }
}
