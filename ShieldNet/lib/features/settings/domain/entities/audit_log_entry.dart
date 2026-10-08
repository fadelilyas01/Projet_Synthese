/// Modèle typé représentant une entrée du journal d'audit ShieldNet
class AuditLogEntry {
  final String id;
  final String action;
  final String source;
  final String userUsername;
  final String targetHash;
  final String createdAt;
  final Map<String, dynamic>? details;

  const AuditLogEntry({
    required this.id,
    required this.action,
    required this.source,
    required this.userUsername,
    required this.targetHash,
    required this.createdAt,
    this.details,
  });

  /// Désérialise depuis la réponse JSON de l'API admin/audit-logs/
  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: json['id']?.toString() ?? '',
      action: json['action'] as String? ?? '',
      source: json['source'] as String? ?? 'web',
      userUsername: (json['username'] ?? json['user_username']) as String? ?? 'Système',
      targetHash: json['target_hash'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      details: json['details'] is Map<String, dynamic>
          ? json['details'] as Map<String, dynamic>
          : (json['details'] != null && json['details'].toString().isNotEmpty
              ? {'info': json['details'].toString()}
              : null),
    );
  }

  /// Convertit en Map pour compatibilité descendante avec les widgets existants
  Map<String, dynamic> toMap() => {
    'id': id,
    'action': action,
    'source': source,
    'user_username': userUsername,
    'target_hash': targetHash,
    'created_at': createdAt,
    'details': details,
  };

  /// Vérifie si l'action est de type blocage
  bool get isBlockAction => action.contains('BLOCK') && !action.contains('UNBLOCK');

  /// Vérifie si l'action est de type déblocage/blanchiment
  bool get isUnblockAction => action.contains('UNBLOCK') || action.contains('WHITELIST');

  /// Vérifie si la source est l'interface web
  bool get isWebSource => source.toLowerCase() == 'web';
}
