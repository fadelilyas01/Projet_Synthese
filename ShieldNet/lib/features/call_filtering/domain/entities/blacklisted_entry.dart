/// Entité métier pure représentant un numéro indésirable dans le domaine ShieldNet
class BlacklistedEntry {
  final String phoneHash;
  final String maskedNumber;
  final String category;
  final int riskScore;
  final int reportsCount;
  final DateTime updatedAt;
  final bool isUserReported;

  const BlacklistedEntry({
    required this.phoneHash,
    required this.maskedNumber,
    required this.category,
    required this.riskScore,
    required this.reportsCount,
    required this.updatedAt,
    this.isUserReported = false,
  });

  bool get isHighRisk => riskScore >= 70;
  bool get isModerateRisk => riskScore >= 40 && riskScore < 70;
}
