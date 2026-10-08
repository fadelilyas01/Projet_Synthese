import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Carte éducative dynamique présentant les bonnes pratiques de sécurité télécom
/// et comblant les espaces vides avec des informations concrètes et utiles.
class TelecomSecurityTipCard extends StatefulWidget {
  const TelecomSecurityTipCard({super.key});

  @override
  State<TelecomSecurityTipCard> createState() => _TelecomSecurityTipCardState();
}

class _TelecomSecurityTipCardState extends State<TelecomSecurityTipCard> {
  int _tipIndex = 0;

  static const List<Map<String, String>> _tipsFr = [
    {
      'tag': 'TRANQUILLITÉ',
      'title': 'Votre ligne reste sereine',
      'desc': 'ShieldNet filtre automatiquement les appels indésirables en arrière-plan. Vous profitez de votre téléphone en toute tranquillité d\'esprit.',
      'icon': 'phone_in_talk_rounded',
    },
    {
      'tag': 'VIE PRIVÉE',
      'title': 'Vos contacts restent chez vous',
      'desc': 'Votre carnet d\'adresses et vos échanges personnels restent strictement confidentiels et ne quittent jamais votre téléphone.',
      'icon': 'security_rounded',
    },
    {
      'tag': 'SÉCURITÉ DU QUOTIDIEN',
      'title': 'Conseil pour les appels officiels',
      'desc': 'Votre banque ne vous demandera jamais de mot de passe par téléphone. En cas de doute, raccrochez et rappelez le numéro officiel de votre agence.',
      'icon': 'account_balance_rounded',
    },
    {
      'tag': 'ACCÈS D\'URGENCE',
      'title': 'Les numéros essentiels toujours disponibles',
      'desc': 'Les services d\'assistance et d\'urgence (911, 811, secours) restent toujours prioritaires et accessibles sans interruption.',
      'icon': 'health_and_safety_rounded',
    },
  ];

  static const List<Map<String, String>> _tipsEn = [
    {
      'tag': 'PEACE OF MIND',
      'title': 'Your Phone Stays Peaceful',
      'desc': 'ShieldNet filters unwanted disturbance in the background so you can enjoy your day without intrusive calls.',
      'icon': 'phone_in_talk_rounded',
    },
    {
      'tag': 'PRIVACY FIRST',
      'title': 'Your Contacts Stay On Your Device',
      'desc': 'Your address book and personal conversations remain strictly confidential and never leave your phone.',
      'icon': 'security_rounded',
    },
    {
      'tag': 'EVERYDAY SAFETY',
      'title': 'A Good Habit for Bank Calls',
      'desc': 'Legitimate bank representatives never request passwords over the phone. When in doubt, simply hang up and call the official number on your card.',
      'icon': 'account_balance_rounded',
    },
    {
      'tag': 'EMERGENCY SANCTUARY',
      'title': 'Essential Services Always Reach You',
      'desc': 'Public safety and emergency numbers (911, 811, local services) are always guaranteed to ring through uninterrupted.',
      'icon': 'health_and_safety_rounded',
    },
  ];

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'phone_in_talk_rounded':
        return Icons.phone_in_talk_rounded;
      case 'ring_volume_rounded':
        return Icons.ring_volume_rounded;
      case 'account_balance_rounded':
        return Icons.account_balance_rounded;
      case 'health_and_safety_rounded':
        return Icons.health_and_safety_rounded;
      case 'security_rounded':
      default:
        return Icons.security_rounded;
    }
  }

  void _nextTip(int total) {
    setState(() {
      _tipIndex = (_tipIndex + 1) % total;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = AppTheme.cardBg(isDark);
    final borderColor = AppTheme.borderColor(isDark);
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final tips = isEn ? _tipsEn : _tipsFr;
    final current = tips[_tipIndex];

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lightbulb_rounded, color: AppTheme.primaryColor, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        current['tag']!,
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '${_tipIndex + 1}/${tips.length}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => _nextTip(tips.length),
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getIconData(current['icon']!),
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        current['title']!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        current['desc']!,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
