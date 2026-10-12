import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo.dart';

class FaqCategoryInfo {
  final String id;
  final String title;
  final String description;
  final IconData icon;

  const FaqCategoryInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });
}

class FaqItemData {
  final String categoryId;
  final String category;
  final String question;
  final String answer;

  const FaqItemData({
    required this.categoryId,
    required this.category,
    required this.question,
    required this.answer,
  });
}

class HelpFaqPage extends StatefulWidget {
  const HelpFaqPage({super.key});

  @override
  State<HelpFaqPage> createState() => _HelpFaqPageState();
}

class _HelpFaqPageState extends State<HelpFaqPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategoryId = 'all';
  final Map<String, bool> _feedbackGiven = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _resolveWebHelpUrl() {
    final base = ApiClient.initialBaseUrl;
    if (base.contains('/api/v1/')) {
      return base.replaceAll('/api/v1/', '/help/');
    }
    final uri = Uri.tryParse(base);
    if (uri != null) {
      final portStr = uri.hasPort ? ':${uri.port}' : '';
      return '${uri.scheme}://${uri.host}$portStr/help/';
    }
    return 'https://shieldnet.app/help/';
  }

  Future<void> _openWebHelp() async {
    final urlStr = _resolveWebHelpUrl();
    final uri = Uri.parse(urlStr);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d\'ouvrir l\'URL: $urlStr')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'ouverture du navigateur: $e')),
        );
      }
    }
  }

  Future<void> _sendEmailToSupport() async {
    final uri = Uri.parse('mailto:support@shieldnet.app?subject=Demande%20d%27assistance%20ShieldNet');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        _copySupportEmail();
      }
    } catch (_) {
      if (mounted) _copySupportEmail();
    }
  }

  void _copySupportEmail() {
    Clipboard.setData(const ClipboardData(text: 'support@shieldnet.app'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
            SizedBox(width: 10),
            Text('Adresse support@shieldnet.app copiée !'),
          ],
        ),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<FaqCategoryInfo> _getCategories(bool isFr) {
    if (isFr) {
      return const [
        FaqCategoryInfo(
          id: 'protection',
          title: 'Protection des appels',
          description: 'Comment ShieldNet analyse, filtre et bloque les numéros malveillants.',
          icon: Icons.verified_user_rounded,
        ),
        FaqCategoryInfo(
          id: 'confidentialite',
          title: 'Vos informations personnelles',
          description: 'Ce que ShieldNet protège, et ce qu\'il ne consulte jamais.',
          icon: Icons.lock_rounded,
        ),
        FaqCategoryInfo(
          id: 'urgences',
          title: 'Numéros importants & Déblocage',
          description: 'Numéros d\'urgence et comment débloquer un appel légitime.',
          icon: Icons.emergency_rounded,
        ),
        FaqCategoryInfo(
          id: 'autorisations',
          title: 'Autorisations système Android',
          description: 'Pourquoi certaines permissions sont nécessaires pour agir à temps.',
          icon: Icons.phonelink_setup_rounded,
        ),
      ];
    } else {
      return const [
        FaqCategoryInfo(
          id: 'protection',
          title: 'Call Protection',
          description: 'How ShieldNet detects, filters, and blocks fraudulent calls.',
          icon: Icons.verified_user_rounded,
        ),
        FaqCategoryInfo(
          id: 'confidentialite',
          title: 'Your Personal Information',
          description: 'What ShieldNet safeguards, and what it never accesses.',
          icon: Icons.lock_rounded,
        ),
        FaqCategoryInfo(
          id: 'urgences',
          title: 'Important Numbers & Disputes',
          description: 'Emergency exemptions, false positives, and unblocking legit callers.',
          icon: Icons.emergency_rounded,
        ),
        FaqCategoryInfo(
          id: 'autorisations',
          title: 'Android System Permissions',
          description: 'Why specific system permissions are required to act before ring.',
          icon: Icons.phonelink_setup_rounded,
        ),
      ];
    }
  }

  List<FaqItemData> _getFaqData(bool isFr) {
    if (isFr) {
      return const [
        // ── Catégorie 1 : Protection des appels
        FaqItemData(
          categoryId: 'protection',
          category: 'Protection des appels',
          question: 'Comment ShieldNet bloque-t-il les appels indésirables ?',
          answer:
              'Dès qu\'un appel arrive sur votre téléphone, ShieldNet vérifie ce numéro en une fraction de seconde dans sa base de données locale. Si ce numéro est identifié comme dangereux, votre téléphone ne sonne pas du tout — vous n\'êtes jamais dérangé.\n\nImaginez un portier discret posté devant votre porte : il vérifie chaque visiteur avant même de vous appeler. Les démarcheurs agressifs et les fraudeurs n\'arrivent simplement jamais jusqu\'à vous.',
        ),
        FaqItemData(
          categoryId: 'protection',
          category: 'Protection des appels',
          question: 'La protection fonctionne-t-elle sans connexion Internet ?',
          answer:
              'Oui, en permanence ! La liste des numéros dangereux est synchronisée et stockée directement sur votre téléphone. Même en voyage, dans un sous-sol sans réseau ou en mode avion avec Wi-Fi coupé, la protection reste active.\n\nLa connexion Internet sert uniquement à synchroniser les nouvelles mises à jour de la base de données. Entre les synchronisations, tout fonctionne de manière 100% autonome et locale.',
        ),
        FaqItemData(
          categoryId: 'protection',
          category: 'Protection des appels',
          question: 'Est-ce que l\'application consomme beaucoup de batterie ?',
          answer:
              'Non, pratiquement rien. ShieldNet reste totalement silencieux en arrière-plan et ne se réveille qu\'une fraction de seconde lorsqu\'un appel arrive sur votre appareil.\n\nGrâce à son moteur de vérification locale ultra-optimisé et à sa conception légère, l\'impact sur votre autonomie est inférieur à 0,5% par jour. C\'est l\'équivalent d\'un détecteur de fumée : il veille en permanence sans dépenser d\'énergie inutile.',
        ),

        // ── Catégorie 2 : Vos informations personnelles
        FaqItemData(
          categoryId: 'confidentialite',
          category: 'Vos informations personnelles',
          question: 'Est-ce que ShieldNet consulte mes contacts ou mes messages privés ?',
          answer:
              'Non, jamais. ShieldNet ne téléverse pas vos contacts, ne lit pas le contenu de vos messages et ne conserve aucun historique nominatif sur des serveurs externes.\n\nPour vérifier un numéro suspect, l\'application génère une empreinte anonyme et chiffrée, totalement irréversible. Seul ce code protégé est confronté à la liste sécurisée. Personne, pas même les créateurs de ShieldNet, ne peut retrouver votre numéro ou l\'identité de vos correspondants.',
        ),
        FaqItemData(
          categoryId: 'confidentialite',
          category: 'Vos informations personnelles',
          question: 'Mes signalements de spam sont-ils vraiment anonymes ?',
          answer:
              'Oui, à 100%. Avant d\'envoyer un signalement, votre téléphone convertit automatiquement le numéro en empreinte chiffrée anonyme. C\'est cette empreinte, associée à la catégorie de fraude, qui alimente la protection collective.\n\nAucun identifiant personnel, nom, adresse ou donnée de géolocalisation n\'est associé au signalement.',
        ),

        // ── Catégorie 3 : Numéros importants & contestations
        FaqItemData(
          categoryId: 'urgences',
          category: 'Numéros importants & contestations',
          question: 'Le 911, mon médecin ou le 811 peuvent-ils être bloqués par erreur ?',
          answer:
              'C\'est strictement impossible. Les services d\'urgence (911, 112, 988, 811, etc.) sont inscrits dans une liste de contournement prioritaire codée en dur dans l\'application mobile.\n\nCette liste est vérifiée en priorité absolue au niveau du système, avant toute évaluation du filtre anti-spam. De plus, vos contacts enregistrés bénéficient par défaut d\'une immunité totale.',
        ),
        FaqItemData(
          categoryId: 'urgences',
          category: 'Numéros importants & contestations',
          question: 'Un livreur ou ma clinique a été bloqué par erreur. Comment corriger ça ?',
          answer:
              'Dans l\'application, ouvrez votre onglet « Activité » (Journal d\'appels), sélectionnez le numéro bloqué et cliquez sur « Contester ce blocage » (Avis Sûr).\n\nNotre algorithme de consensus prend immédiatement en compte votre avis. Dès que plusieurs utilisateurs confirment la légitimité d\'un numéro, celui-ci est retiré de la liste noire générale en moins de 10 minutes.',
        ),

        // ── Catégorie 4 : Autorisations système Android
        FaqItemData(
          categoryId: 'autorisations',
          category: 'Autorisations système Android',
          question: 'Pourquoi définir ShieldNet comme application de filtrage par défaut ?',
          answer:
              'Depuis Android 10, le système exige que toute application capable de couper la sonnerie d\'un appel malveillant possède le rôle officiel de filtrage d\'appels (CallScreeningService).\n\nSans ce rôle, ShieldNet pourrait vous avertir après coup, mais ne pourrait pas empêcher votre téléphone de sonner lors d\'un appel de télémarketing ou d\'escroquerie. Cette autorisation n\'accorde aucun accès à votre microphone ni à vos conversations.',
        ),
        FaqItemData(
          categoryId: 'autorisations',
          category: 'Autorisations système Android',
          question: 'La permission de lecture des SMS est-elle obligatoire ?',
          answer:
              'Non, cette permission est totalement optionnelle. Elle est demandée uniquement si vous activez le Vérificateur de SMS & Liens — un outil qui vous avertit lorsqu\'un SMS contient un lien frauduleux suspect (fausse livraison, faux remboursement fiscal, etc.).\n\nMême activée, cette analyse est réalisée exclusivement en local sur votre appareil. Aucun contenu de message n\'est transmis sur internet.',
        ),
      ];
    } else {
      return const [
        // ── Category 1: Call Protection
        FaqItemData(
          categoryId: 'protection',
          category: 'Call Protection',
          question: 'How does ShieldNet block unwanted calls?',
          answer:
              'The moment an incoming call reaches your phone, ShieldNet checks the number in a fraction of a second against its local database. If identified as dangerous, your phone does not ring at all — you are never disturbed.\n\nPicture a discreet doorman stationed at your door: every visitor is verified before ever reaching you. Known robocallers and scammers simply never get through.',
        ),
        FaqItemData(
          categoryId: 'protection',
          category: 'Call Protection',
          question: 'Does the protection work without an internet connection?',
          answer:
              'Yes, constantly! The list of flagged numbers is synchronized and saved directly onto your device. Even when traveling, in a basement without cellular reception, or in airplane mode, call protection remains active.\n\nInternet access is only needed to receive database updates. Between updates, everything operates 100% locally and autonomously.',
        ),
        FaqItemData(
          categoryId: 'protection',
          category: 'Call Protection',
          question: 'Does the app drain my battery?',
          answer:
              'Barely at all. ShieldNet stays completely idle in the background and only activates for a split second when a call arrives.\n\nThanks to its lightweight local screening engine and efficient design, daily battery usage is less than 0.5%. It is just like a home smoke alarm: constantly vigilant without wasting energy.',
        ),

        // ── Category 2: Your Personal Information
        FaqItemData(
          categoryId: 'confidentialite',
          category: 'Your Personal Information',
          question: 'Does ShieldNet read my contacts or private messages?',
          answer:
              'No, never. ShieldNet does not upload your contacts, does not read your private message text, and keeps zero nominative logs on remote servers.\n\nTo check a suspicious number, the app produces an anonymous, irreversible digital fingerprint. Only this protected code is matched against the database. No one, not even ShieldNet engineers, can identify your phone number or the identity of your callers.',
        ),
        FaqItemData(
          categoryId: 'confidentialite',
          category: 'Your Personal Information',
          question: 'Are my spam reports truly anonymous?',
          answer:
              'Yes, 100%. Before transmitting any report, your phone automatically transforms the number into an anonymous protected fingerprint. Only this secure code, paired with the category of fraud, feeds our community protection.\n\nNo personal identity, name, address, or GPS coordinates are ever attached to a report.',
        ),

        // ── Category 3: Important Numbers & Disputes
        FaqItemData(
          categoryId: 'urgences',
          category: 'Important Numbers & Disputes',
          question: 'Can 911, my doctor, or 811 be blocked by mistake?',
          answer:
              'That is strictly impossible. Emergency services (911, 112, 988, 811, etc.) are permanently protected by a hardcoded bypass rule within the mobile application.\n\nThis bypass is evaluated with absolute top priority at the operating system level, well before any spam filters are consulted. Furthermore, your saved contacts benefit from full immunity by default.',
        ),
        FaqItemData(
          categoryId: 'urgences',
          category: 'Important Numbers & Disputes',
          question: 'A delivery driver or clinic was blocked by mistake. How do I fix it?',
          answer:
              'In the ShieldNet app, navigate to your "Activity" tab (Call Log), select the blocked number, and tap "Contest this block" (Safe Review).\n\nOur community consensus engine immediately accounts for your feedback. As soon as multiple users confirm the number is legitimate, it is automatically unblocked for everyone in under 10 minutes.',
        ),

        // ── Category 4: Android System Permissions
        FaqItemData(
          categoryId: 'autorisations',
          category: 'Android System Permissions',
          question: 'Why set ShieldNet as the default call screening app?',
          answer:
              'Starting with Android 10, the Android operating system requires apps that silence malicious calls to hold the official CallScreeningService system role.\n\nWithout this role, ShieldNet could only notify you after the call finished, but could not prevent the ringtone from interrupting your day. This permission does not grant any access to your microphone or private conversations.',
        ),
        FaqItemData(
          categoryId: 'autorisations',
          category: 'Android System Permissions',
          question: 'Is the SMS read permission mandatory?',
          answer:
              'No, this permission is completely optional. It is requested only if you decide to activate SMS Phishing Protection — a safety tool that alerts you when a message contains suspicious phishing links (fake parcels, fake tax refunds, etc.).\n\nEven when turned on, this analysis is performed 100% locally on your device. Zero message content is ever sent over the internet.',
        ),
      ];
    }
  }

  void _showSupportModal(BuildContext context, bool isFr) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111827) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).padding.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.support_agent_rounded, color: AppTheme.primaryColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isFr ? 'Contacter le Support ShieldNet' : 'Contact ShieldNet Support',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isFr
                                ? 'Équipe de surveillance télécom & cybersécurité'
                                : 'Telecom monitoring & cybersecurity team',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  isFr
                      ? 'Une question sur un numéro bloqué, une anomalie de filtrage ou un problème technique ? Nos équipes sont à votre service.'
                      : 'Have a question about a blocked number, filtering glitch, or technical inquiry? Our team is here to assist.',
                  style: TextStyle(fontSize: 13, height: 1.5, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                ),
                const SizedBox(height: 16),

                // Carte Email Support
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.mail_rounded, size: 18, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            isFr ? 'Courriel direct du support' : 'Direct Support Email',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const SelectableText(
                        'support@shieldnet.app',
                        style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                _copySupportEmail();
                                Navigator.pop(ctx);
                              },
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              label: Text(isFr ? 'Copier l\'adresse' : 'Copy Email'),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _sendEmailToSupport();
                              },
                              icon: const Icon(Icons.send_rounded, size: 16),
                              label: Text(isFr ? 'Écrire' : 'Compose'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Horaires d'intervention
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 20, color: Colors.blueAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isFr
                              ? 'Lundi au Vendredi • 09:00 - 17:00 (EST)\nPrise en charge sous 24h ouvrables'
                              : 'Monday to Friday • 09:00 - 17:00 (EST)\nResponse guaranteed under 24 business hours',
                          style: TextStyle(fontSize: 12, height: 1.4, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Astuce contestation
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: isDark ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.offline_bolt_rounded, size: 20, color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isFr
                              ? 'Débloquer un numéro : Vous pouvez débloquer un contact ou un proche directement depuis l\'onglet Activité en le sélectionnant.'
                              : 'Unblocking a caller: You can unblock any caller directly from the Activity tab by selecting the number.',
                          style: TextStyle(fontSize: 12, height: 1.4, color: isDark ? Colors.green[200] : Colors.green[800]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPrivacyModal(BuildContext context, bool isFr) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111827) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).padding.bottom + 20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.lock_rounded, color: AppTheme.primaryColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      isFr ? 'Politique de Confidentialité' : 'Privacy Policy',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildLegalSection(
                  isDark,
                  isFr ? '1. Engagement Zéro-Connaissance' : '1. Zero-Knowledge Architecture',
                  isFr
                      ? 'ShieldNet applique une minimisation stricte des données. Aucun contenu d\'appel ni texte SMS nominatif n\'est téléversé.'
                      : 'ShieldNet follows strict data minimization principles. Zero audio or identifiable message content is ever uploaded.',
                ),
                _buildLegalSection(
                  isDark,
                  isFr ? '2. Hachage cryptographique local' : '2. Local Cryptographic Hashing',
                  isFr
                      ? 'Lors de la vérification, votre appareil calcule un hash SHA-256 irréversible. Seul ce code anonymisé transite pour alimenter la protection.'
                      : 'During checks, an irreversible SHA-256 hash is generated locally. Only this anonymized hash transits for consensus.',
                ),
                _buildLegalSection(
                  isDark,
                  isFr ? '3. Contacts confinés' : '3. Protected Address Book',
                  isFr
                      ? 'Vos contacts restent dans la mémoire sécurisée de votre téléphone. ShieldNet ne les lit qu\'en local pour immuniser vos proches.'
                      : 'Contacts stay inside your device\'s secure memory. ShieldNet queries them strictly offline to grant immunity to friends & family.',
                ),
                _buildLegalSection(
                  isDark,
                  isFr ? '4. Conformité réglementaire' : '4. Regulatory Standards',
                  isFr
                      ? 'Respect strict de la Loi 25 (Québec), LPRPDE & CRTC (Canada), RGPD (Europe) et TCPA/FCC (USA).'
                      : 'Strict compliance with Law 25 (Quebec), PIPEDA & CRTC (Canada), GDPR (Europe), and TCPA/FCC (USA).',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTermsModal(BuildContext context, bool isFr) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111827) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).padding.bottom + 20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.description_rounded, color: AppTheme.primaryColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      isFr ? 'Conditions d\'Utilisation' : 'Terms of Service',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildLegalSection(
                  isDark,
                  isFr ? '1. Objet du Service' : '1. Scope of Service',
                  isFr
                      ? 'ShieldNet est une solution de cybersécurité collaborative filtrant les appels téléphoniques frauduleux et non sollicités.'
                      : 'ShieldNet is a collaborative telecom cybersecurity solution screening fraudulent and unsolicited phone calls.',
                ),
                _buildLegalSection(
                  isDark,
                  isFr ? '2. Garantie absolue des urgences' : '2. Absolute Emergency Bypass',
                  isFr
                      ? 'L\'application intègre une dérogation matérielle prioritaire interdisant tout rejet des numéros officiels (911, 112, 988, 811).'
                      : 'A hardcoded system-level exemption ensures official emergency numbers (911, 112, 988, 811) are never filtered.',
                ),
                _buildLegalSection(
                  isDark,
                  isFr ? '3. Consensus communautaire' : '3. Community Consensus',
                  isFr
                      ? 'Les signalements et contestations sont validés par consensus pour empêcher les abus ou faux blocages.'
                      : 'Reports and disputes are evaluated using multi-source consensus to prevent malicious or accidental blocks.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegalSection(bool isDark, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(fontSize: 13, height: 1.5, color: isDark ? Colors.grey[400] : Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final isFr = Localizations.localeOf(context).languageCode == 'fr';
    final categories = _getCategories(isFr);
    final allFaqs = _getFaqData(isFr);

    final filteredFaqs = allFaqs.where((f) {
      if (_selectedCategoryId != 'all' && f.categoryId != _selectedCategoryId) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return f.question.toLowerCase().contains(q) ||
            f.answer.toLowerCase().contains(q) ||
            f.category.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    final Map<String, List<FaqItemData>> grouped = {};
    for (final item in filteredFaqs) {
      grouped.putIfAbsent(item.categoryId, () => []).add(item);
    }

    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(
          l10n?.helpFaqTitle ?? (isFr ? 'Centre d\'Aide & FAQ' : 'Help Center & FAQ'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent_rounded),
            tooltip: isFr ? 'Contacter le support' : 'Contact Support',
            onPressed: () => _showSupportModal(context, isFr),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded),
            tooltip: l10n?.openWebHelpBtn ?? (isFr ? 'Ouvrir sur le web' : 'Open in browser'),
            onPressed: _openWebHelp,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // ── 1. Bandeau Portail Web & Support Direct
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E3A8A).withValues(alpha: 0.35), const Color(0xFF0F172A)]
                    : [const Color(0xFFEFF6FF), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const ShieldNetLogo.badge(size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isFr ? 'Centre d\'Assistance ShieldNet' : 'ShieldNet Help & Support',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isFr
                                ? 'Guides officiels, réponses claires et assistance technique certifiée conforme.'
                                : 'Official guides, plain-language answers, and certified technical support.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showSupportModal(context, isFr),
                        icon: const Icon(Icons.mail_outline_rounded, size: 16),
                        label: Text(isFr ? 'Écrire au support' : 'Email Support'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white : AppTheme.primaryColor,
                          side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _openWebHelp,
                        icon: const Icon(Icons.launch_rounded, size: 16),
                        label: Text(isFr ? 'Portail Web' : 'Web Portal'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── 2. Champ de recherche rapide
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            decoration: InputDecoration(
              hintText: l10n?.searchFaqPlaceholder ?? (isFr ? 'Rechercher une question (batterie, urgence, blocage)...' : 'Search question...'),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: cardBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ── 3. Filtres horizontaux par catégorie (synchrones avec les onglets Web)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryChip(
                  id: 'all',
                  label: isFr ? 'Toutes les rubriques' : 'All Topics',
                  count: allFaqs.length,
                  icon: Icons.grid_view_rounded,
                  isSelected: _selectedCategoryId == 'all',
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                ...categories.map((cat) {
                  final catCount = allFaqs.where((f) => f.categoryId == cat.id).length;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildCategoryChip(
                      id: cat.id,
                      label: cat.title,
                      count: catCount,
                      icon: cat.icon,
                      isSelected: _selectedCategoryId == cat.id,
                      isDark: isDark,
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ── 4. Liste des questions groupées par catégorie
          if (grouped.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 48, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      l10n?.noResultsFound ?? (isFr ? 'Aucun résultat trouvé pour votre recherche' : 'No results found'),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isFr ? 'Essayez avec un mot-clé plus simple ou réinitialisez le filtre.' : 'Try a different keyword or reset filters.',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                    ),
                    const SizedBox(height: 14),
                    TextButton.icon(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _selectedCategoryId = 'all';
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(isFr ? 'Réinitialiser la recherche' : 'Reset search'),
                    ),
                  ],
                ),
              ),
            )
          else
            ...categories.where((c) => grouped.containsKey(c.id)).map((cat) {
              final items = grouped[cat.id]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header de la catégorie avec icône réelle et description claire
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.25)),
                            ),
                            child: Icon(cat.icon, size: 18, color: AppTheme.primaryColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat.title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  cat.description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Cards des questions
                    ...items.map((faq) {
                      final hasVoted = _feedbackGiven.containsKey(faq.question);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        color: cardBg,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: borderColor),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            title: Text(
                              faq.question,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                            ),
                            iconColor: AppTheme.primaryColor,
                            collapsedIconColor: isDark ? Colors.grey[400] : Colors.grey[600],
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.only(top: 8, bottom: 12),
                                child: Text(
                                  faq.answer,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    height: 1.6,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                  ),
                                ),
                              ),
                              Divider(height: 1, color: borderColor),
                              const SizedBox(height: 10),
                              // Widget interactif "Cette réponse vous a-t-elle aidé ?"
                              Row(
                                children: [
                                  Text(
                                    hasVoted
                                        ? (isFr ? 'Merci pour votre retour ! 😊' : 'Thank you for your feedback! 😊')
                                        : (isFr ? 'Cette réponse vous a-t-elle aidé ?' : 'Was this answer helpful?'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: hasVoted ? FontWeight.bold : FontWeight.normal,
                                      color: hasVoted
                                          ? (isDark ? Colors.greenAccent : Colors.green[700])
                                          : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (!hasVoted) ...[
                                    InkWell(
                                      onTap: () => setState(() => _feedbackGiven[faq.question] = true),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.thumb_up_alt_rounded, size: 14, color: AppTheme.primaryColor),
                                            SizedBox(width: 4),
                                            Text('Oui', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () => setState(() => _feedbackGiven[faq.question] = false),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.thumb_down_alt_rounded, size: 14, color: Colors.grey[500]),
                                            const SizedBox(width: 4),
                                            Text('Non', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),

          const SizedBox(height: 10),

          // ── 5. Bloc de pied de page avec contact et liens légaux
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.help_center_rounded, color: AppTheme.primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      isFr ? 'Vous avez une question spécifique ?' : 'Have a specific question?',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isFr
                      ? 'Notre équipe d\'assistance répond du lundi au vendredi, de 9 h à 17 h (EST). Réponse rapide garantie.'
                      : 'Our technical team responds Monday to Friday, 9am to 5pm (EST). Fast response guaranteed.',
                  style: TextStyle(fontSize: 12, height: 1.4, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.headset_mic_rounded, size: 16, color: AppTheme.primaryColor),
                      label: Text(isFr ? 'Contacter le Support' : 'Contact Support'),
                      onPressed: () => _showSupportModal(context, isFr),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.lock_outline_rounded, size: 16),
                      label: Text(isFr ? 'Confidentialité' : 'Privacy'),
                      onPressed: () => _showPrivacyModal(context, isFr),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.description_outlined, size: 16),
                      label: Text(isFr ? 'Conditions' : 'Terms'),
                      onPressed: () => _showTermsModal(context, isFr),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Center(
            child: Text(
              isFr
                  ? '© ShieldNet Protection Télécom • Conforme CRTC / FCC & RGPD'
                  : '© ShieldNet Telecom Protection • Compliant with CRTC / FCC & GDPR',
              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[600] : Colors.grey[500]),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String id,
    required String label,
    required int count,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategoryId = id;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700]),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? Colors.grey[200] : Colors.grey[800]),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : (isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.06)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
