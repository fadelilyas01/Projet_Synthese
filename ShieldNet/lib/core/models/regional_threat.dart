/// Modèle de données pour les renseignements sur les menaces téléphoniques régionales
/// (Surveillance des vagues d'arnaques ciblées par indicatif régional).
class RegionalThreatSummary {
  final DateTime generatedAt;
  final int totalRegionsTracked;
  final List<RegionalThreatItem> regions;

  const RegionalThreatSummary({
    required this.generatedAt,
    required this.totalRegionsTracked,
    required this.regions,
  });

  factory RegionalThreatSummary.fromJson(Map<String, dynamic> json) {
    final list = (json['regions'] as List?) ?? [];
    return RegionalThreatSummary(
      generatedAt: DateTime.tryParse(json['generated_at']?.toString() ?? '') ?? DateTime.now(),
      totalRegionsTracked: (json['total_regions_tracked'] as int?) ?? 0,
      regions: list
          .whereType<Map>()
          .map((e) => RegionalThreatItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  /// Filtre les alertes régionales pour ne conserver que les indicatifs et villes du Québec.
  RegionalThreatSummary filterByQuebec() {
    final qcRegions = regions.where((r) => r.isQuebec).toList();
    return RegionalThreatSummary(
      generatedAt: generatedAt,
      totalRegionsTracked: qcRegions.length,
      regions: qcRegions,
    );
  }

  /// Filtre les alertes régionales selon la juridiction ou province/état.
  RegionalThreatSummary filterByProvince(String? provinceOrState) {
    if (provinceOrState == null || provinceOrState.isEmpty) return this;
    final prov = provinceOrState.trim().toUpperCase();
    if (prov == 'QC') return filterByQuebec();

    final filtered = regions.where((r) {
      if (r.province.toUpperCase() == prov) return true;
      if (r.regionName.toUpperCase().contains('($prov)')) return true;
      return false;
    }).toList();

    return RegionalThreatSummary(
      generatedAt: generatedAt,
      totalRegionsTracked: filtered.length,
      regions: filtered,
    );
  }

  /// Retourne la menace la plus critique s'il en existe une
  RegionalThreatItem? get highestAlert {
    if (regions.isEmpty) return null;
    try {
      return regions.firstWhere((r) => r.isCritical);
    } catch (_) {
      try {
        return regions.firstWhere((r) => r.isHigh);
      } catch (_) {
        return regions.first;
      }
    }
  }
}

class RegionalThreatItem {
  /// Ensemble officiel des indicatifs régionaux NANP réservés à la province de Québec
  static const Set<String> quebecAreaCodes = {
    '514', '438', '263', // Grand Montréal
    '450', '579', '354', // Laval, Laurentides, Montérégie, Rive-Sud
    '418', '581', '367', // Ville de Québec, Capitale-Nationale, Est, Saguenay
    '819', '873', '468', // Gatineau, Outaouais, Sherbrooke, Mauricie, Abitibi
  };

  final String areaCode;
  final String regionName;
  final String province;
  final int totalSpams;
  final String topCategory;
  final int maxRiskScore;
  final String alertLevel;

  const RegionalThreatItem({
    required this.areaCode,
    required this.regionName,
    this.province = '',
    required this.totalSpams,
    required this.topCategory,
    required this.maxRiskScore,
    required this.alertLevel,
  });

  factory RegionalThreatItem.fromJson(Map<String, dynamic> json) {
    return RegionalThreatItem(
      areaCode: json['area_code']?.toString() ?? '',
      regionName: json['region_name']?.toString() ?? 'Région indéterminée',
      province: json['province']?.toString() ?? '',
      totalSpams: (json['total_spams'] as int?) ?? 0,
      topCategory: json['top_category']?.toString() ?? 'fraud',
      maxRiskScore: (json['max_risk_score'] as int?) ?? 0,
      alertLevel: json['alert_level']?.toString() ?? 'MODÉRÉ',
    );
  }

  /// Indique si cet indicatif et cette ville appartiennent formellement au Québec
  bool get isQuebec {
    final cleanCode = areaCode.trim();
    if (quebecAreaCodes.contains(cleanCode)) return true;
    if (province.trim().toUpperCase() == 'QC') return true;

    final upper = regionName.toUpperCase();
    return upper.contains('(QC)') ||
        upper.contains('QUÉBEC') ||
        upper.contains('QUEBEC') ||
        upper.contains('MONTRÉAL') ||
        upper.contains('MONTREAL') ||
        upper.contains('GATINEAU') ||
        upper.contains('LAVAL') ||
        upper.contains('OUTAOUAIS') ||
        upper.contains('LAURENTIDES');
  }

  bool get isCritical => alertLevel.toUpperCase().contains('CRITIQUE');
  bool get isHigh => alertLevel.toUpperCase().contains('ÉLEVÉ') || alertLevel.toUpperCase().contains('ELEVE');
}
