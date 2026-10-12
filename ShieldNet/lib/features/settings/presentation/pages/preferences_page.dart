import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';

/// Page dédiée regroupant les préférences d'affichage, d'accessibilité et de langue
class PreferencesPage extends ConsumerWidget {
  const PreferencesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final currentLocale = ref.watch(localeProvider);
    final settings = ref.watch(appSettingsProvider);
    final isEn = currentLocale.languageCode == 'en';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AppTheme.cardBg(isDark);
    final borderColor = AppTheme.borderColor(isDark);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEn ? 'App Preferences' : 'Préférences de l\'application',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Section 1 : Affichage et Accessibilité
          _buildSectionHeader(isEn ? 'DISPLAY & ACCESSIBILITY' : 'AFFICHAGE & ACCESSIBILITÉ'),
          _buildCard(
            cardBg: cardBg,
            borderColor: borderColor,
            children: [
              SwitchListTile(
                value: settings.seniorMode,
                onChanged: (val) {
                  ref.read(appSettingsProvider.notifier).setSeniorMode(val);
                },
                title: Text(
                  l10n?.settingSeniorMode ?? (isEn ? 'Simplified Interface (Seniors)' : 'Mode Interface Simplifiée (Aînés)'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  l10n?.settingSeniorModeDesc ?? (isEn ? 'Enlarges text, boosts contrast, and streamlines the interface' : 'Agrandit les textes, renforce les contrastes et simplifie l\'accueil'),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                secondary: const Icon(Icons.accessibility_new_rounded, color: AppTheme.primaryColor, size: 24),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.palette_rounded, color: AppTheme.accentOrange, size: 24),
                title: Text(
                  l10n?.settingTheme ?? (isEn ? 'Theme' : 'Thème visuel'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  isEn ? 'Choose between light, dark, or system mode' : 'Choisir entre mode clair, sombre ou automatique',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                trailing: DropdownButtonHideUnderline(
                  child: DropdownButton<ThemeMode>(
                    value: themeMode,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                    items: [
                      DropdownMenuItem(value: ThemeMode.system, child: Text(l10n?.themeSystem ?? (isEn ? 'System' : 'Système'))),
                      DropdownMenuItem(value: ThemeMode.light, child: Text(l10n?.themeLight ?? (isEn ? 'Light' : 'Clair'))),
                      DropdownMenuItem(value: ThemeMode.dark, child: Text(l10n?.themeDark ?? (isEn ? 'Dark' : 'Sombre'))),
                    ],
                    onChanged: (mode) {
                      if (mode != null) ref.read(themeModeProvider.notifier).setThemeMode(mode);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Section 2 : Langue
          _buildSectionHeader(isEn ? 'LANGUAGE' : 'LANGUE'),
          _buildCard(
            cardBg: cardBg,
            borderColor: borderColor,
            children: [
              ListTile(
                leading: const Icon(Icons.language_rounded, color: AppTheme.primaryColor, size: 24),
                title: Text(
                  l10n?.settingLanguage ?? (isEn ? 'Language' : 'Langue d\'affichage'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  isEn ? 'Application interface language' : 'Langue utilisée dans l\'application',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                trailing: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: currentLocale.languageCode,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                    items: [
                      DropdownMenuItem(value: 'fr', child: Text(l10n?.langFrench ?? 'Français')),
                      DropdownMenuItem(value: 'en', child: Text(l10n?.langEnglish ?? 'English')),
                    ],
                    onChanged: (langCode) {
                      if (langCode != null) {
                        ref.read(localeProvider.notifier).setLocale(langCode);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.grey,
          letterSpacing: 1.0,
        ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }
}
