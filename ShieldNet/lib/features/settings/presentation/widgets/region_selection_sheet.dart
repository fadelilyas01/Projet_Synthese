import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/services/regional_compliance_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';

/// Boîte modale interactive pour sélectionner le Pays (Canada / États-Unis)
/// et la Province / État correspondant avec aperçu dynamique de la norme juridique appliquée.
class RegionSelectionSheet extends ConsumerStatefulWidget {
  final bool isOnboarding;
  final VoidCallback? onSaved;

  const RegionSelectionSheet({
    super.key,
    this.isOnboarding = false,
    this.onSaved,
  });

  static Future<void> show(BuildContext context, {bool isOnboarding = false, VoidCallback? onSaved}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RegionSelectionSheet(
        isOnboarding: isOnboarding,
        onSaved: onSaved,
      ),
    );
  }

  @override
  ConsumerState<RegionSelectionSheet> createState() => _RegionSelectionSheetState();
}

class _RegionSelectionSheetState extends ConsumerState<RegionSelectionSheet> {
  late String _selectedCountry;
  late String _selectedProvince;

  @override
  void initState() {
    super.initState();
    final current = ref.read(regionalComplianceProvider);
    _selectedCountry = current.country;
    _selectedProvince = current.provinceOrState;
  }

  void _onCountryChanged(String newCountry) {
    setState(() {
      _selectedCountry = newCountry;
      if (newCountry == 'CA') {
        _selectedProvince = 'QC';
      } else {
        _selectedProvince = 'NY';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final user = ref.watch(authNotifierProvider);
    final currentLocale = ref.watch(localeProvider);
    final isEn = currentLocale.languageCode == 'en';

    final normPreview = RegionalComplianceManager.getLocalNorm(_selectedCountry, _selectedProvince, lang: isEn ? 'en' : 'fr');
    final normName = normPreview['norm_name'] as String? ?? (isEn ? 'Protection Standard' : 'Norme de protection');
    final normDesc = normPreview['description'] as String? ?? '';
    final retentionDays = normPreview['data_retention_days'] as int? ?? 30;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barre de préhension
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // En-tête
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.public_rounded, color: AppTheme.primaryColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n?.regionSelectionTitle ?? (isEn ? 'Your Region' : 'Votre Région'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        l10n?.regionSelectionSubtitle ??
                            (isEn
                                ? 'Protection tailored to your area code & territory'
                                : 'Protection adaptée à vos indicatifs et territoire'),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Étape 1 : Choix du Pays
            Text(
              l10n?.selectCountryPrompt ?? (isEn ? '1. SELECT YOUR COUNTRY' : '1. SÉLECTIONNEZ VOTRE PAYS'),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.8),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildCountryCard(
                    code: 'CA',
                    flag: '🇨🇦',
                    name: 'Canada',
                    isSelected: _selectedCountry == 'CA',
                    borderColor: borderColor,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCountryCard(
                    code: 'US',
                    flag: '🇺🇸',
                    name: isEn ? 'United States' : 'États-Unis',
                    isSelected: _selectedCountry == 'US',
                    borderColor: borderColor,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Étape 2 : Choix de la Province / de l'État
            Text(
              _selectedCountry == 'CA'
                  ? (l10n?.selectProvincePrompt ?? (isEn ? '2. SELECT YOUR PROVINCE / TERRITORY' : '2. SÉLECTIONNEZ VOTRE PROVINCE / TERRITOIRE'))
                  : (l10n?.selectStatePrompt ?? (isEn ? '2. SELECT YOUR STATE' : '2. SÉLECTIONNEZ VOTRE ÉTAT (STATE)')),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.8),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedProvince,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  items: _selectedCountry == 'CA'
                      ? (isEn ? RegionalComplianceManager.canadianProvincesEn : RegionalComplianceManager.canadianProvinces).entries.map((e) {
                          return DropdownMenuItem<String>(
                            value: e.key,
                            child: Text(
                              '🇨🇦 ${e.value}',
                              style: TextStyle(
                                fontWeight: e.key == 'QC' ? FontWeight.bold : FontWeight.w500,
                                color: e.key == 'QC' ? AppTheme.primaryColor : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList()
                      : (isEn ? RegionalComplianceManager.usStatesEn : RegionalComplianceManager.usStates).entries.map((e) {
                          return DropdownMenuItem<String>(
                            value: e.key,
                            child: Text(
                              '🇺🇸 ${e.value}',
                              style: TextStyle(
                                fontWeight: e.key == 'CA' ? FontWeight.bold : FontWeight.w500,
                                color: e.key == 'CA' ? AppTheme.accentOrange : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedProvince = val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Étape 3 : Carte d'Adaptation & Normes Appliquées en Temps Réel
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _selectedCountry == 'CA' && _selectedProvince == 'QC'
                      ? [const Color(0xFF0284C7).withValues(alpha: 0.12), const Color(0xFF0369A1).withValues(alpha: 0.05)]
                      : [AppTheme.primaryColor.withValues(alpha: 0.12), AppTheme.primaryColor.withValues(alpha: 0.04)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedCountry == 'CA' && _selectedProvince == 'QC'
                      ? const Color(0xFF0284C7).withValues(alpha: 0.3)
                      : AppTheme.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_user_rounded, color: AppTheme.accentGreen, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          normName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.accentGreen),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    normDesc,
                    style: TextStyle(fontSize: 12, height: 1.4, color: isDark ? Colors.white70 : Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accentCyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isEn ? 'Automatic purge: $retentionDays days' : 'Purge automatique\u00a0: $retentionDays jours',
                          style: const TextStyle(color: AppTheme.accentCyan, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isEn ? '911 / 811 / 988 guaranteed' : 'Urgences 911\u00a0/ 811\u00a0/ 988 garanties',
                          style: const TextStyle(color: AppTheme.accentGreen, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Bouton de confirmation
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () async {
                  await ref.read(regionalComplianceProvider.notifier).setRegion(
                        country: _selectedCountry,
                        provinceOrState: _selectedProvince,
                      );
                  if (user != null) {
                    await ref.read(authNotifierProvider.notifier).updateRegion(_selectedCountry, _selectedProvince);
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                    widget.onSaved?.call();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEn
                              ? 'Region updated: ${_selectedCountry == 'CA' ? '🇨🇦 Canada' : '🇺🇸 United States'} — $_selectedProvince. Local protection active.'
                              : 'Région mise à jour\u00a0: ${_selectedCountry == 'CA' ? '🇨🇦 Canada' : '🇺🇸 États-Unis'} — $_selectedProvince. Protection locale active.',
                        ),
                        backgroundColor: AppTheme.accentGreen,
                      ),
                    );
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l10n?.applyRegionBtn ?? (isEn ? 'Apply this region' : 'Appliquer cette région'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryCard({
    required String code,
    required String flag,
    required String name,
    required bool isSelected,
    required Color borderColor,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () => _onCountryChanged(code),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(flag, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(
              name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 14,
                color: isSelected ? AppTheme.primaryColor : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
