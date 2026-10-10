import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/sms_phishing_detector.dart';
import '../../../../core/services/demo_mode_service.dart';
import '../../../../core/services/observability_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../controllers/sms_inspector_controller.dart';

class SmsInspectorPage extends ConsumerStatefulWidget {
  final String? initialText;

  const SmsInspectorPage({super.key, this.initialText});

  @override
  ConsumerState<SmsInspectorPage> createState() => _SmsInspectorPageState();
}

class _SmsInspectorPageState extends ConsumerState<SmsInspectorPage> {
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText ?? '');
    if (widget.initialText != null && widget.initialText!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final lang = Localizations.localeOf(context).languageCode;
        ref.read(smsInspectorProvider.notifier).analyze(widget.initialText!, languageCode: lang);
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    HapticFeedback.selectionClick();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      _textController.text = text;
      if (!mounted) return;
      final lang = Localizations.localeOf(context).languageCode;
      ref.read(smsInspectorProvider.notifier).analyze(text, languageCode: lang);
    } else {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.smsInspectorClipboardEmpty ?? 'Le presse-papier est vide.'),
            backgroundColor: AppTheme.accentOrange,
          ),
        );
      }
    }
  }

  void _runAnalysis() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.mediumImpact();
    ObservabilityService.instance.recordFeatureUsage('sms_inspection');
    final lang = Localizations.localeOf(context).languageCode;
    ref.read(smsInspectorProvider.notifier).analyze(text, languageCode: lang);
  }

  void _clearAll() {
    HapticFeedback.selectionClick();
    _textController.clear();
    ref.read(smsInspectorProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final inspectorState = ref.watch(smsInspectorProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEn = (l10n?.localeName == 'en') || (Localizations.localeOf(context).languageCode == 'en');
    final cardBg = AppTheme.cardBg(isDark);
    final borderColor = AppTheme.borderColor(isDark);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.mark_email_read_rounded, color: AppTheme.accentCyan),
            const SizedBox(width: 8),
            Text(l10n?.smsInspectorTitle ?? 'Inspecteur de SMS & Liens', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          if (_textController.text.isNotEmpty || inspectorState.result != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: l10n?.smsInspectorReset ?? 'Réinitialiser',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Carte d'introduction & confidentialité
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentCyan.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.security_rounded, color: AppTheme.accentCyan, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n?.smsInspectorOfflineTitle ?? 'Analyse 100% Hors-Ligne & Confidentielle',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n?.smsInspectorOfflineDesc ?? 'Le texte de vos SMS n\'est jamais transmis à un serveur distant.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Échantillons de démonstration (Scénarios réels)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEn ? 'EXAMPLE FRAUDULENT SMS TEMPLATES' : 'EXEMPLES DE SMS FRAUDULEUX RÉELS',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.0),
              ),
              const Icon(Icons.touch_app_rounded, size: 14, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: DemoModeService.demoSmsSamples.map((sample) {
                final isDangerous = sample['risk'] == 'DANGEROUS';
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: Icon(
                      isDangerous ? Icons.warning_rounded : Icons.verified_user_rounded,
                      size: 14,
                      color: isDangerous ? AppTheme.accentRed : AppTheme.accentGreen,
                    ),
                    label: Text(
                      sample['title'] as String,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: cardBg,
                    side: BorderSide(color: borderColor),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _textController.text = sample['text'] as String;
                      final lang = Localizations.localeOf(context).languageCode;
                      ref.read(smsInspectorProvider.notifier).analyze(sample['text'] as String, languageCode: lang);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Zone de saisie
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _textController,
                  maxLines: 5,
                  minLines: 3,
                  decoration: InputDecoration(
                    hintText: l10n?.smsInspectorInputHint ?? 'Collez ici le texte du SMS suspect ou le message reçu...',
                    contentPadding: const EdgeInsets.all(16),
                    border: InputBorder.none,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.content_paste_rounded, size: 16),
                        label: Text(l10n?.smsInspectorBtnPaste ?? 'Coller le SMS', style: const TextStyle(fontSize: 12)),
                        onPressed: _pasteFromClipboard,
                      ),
                      ElevatedButton.icon(
                        icon: inspectorState.isAnalyzing
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.shield_outlined, size: 16),
                        label: Text(l10n?.smsInspectorBtnInspect ?? 'Inspecter', style: const TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentCyan,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: inspectorState.isAnalyzing ? null : _runAnalysis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Résultats de l'analyse
          if (inspectorState.result != null) ...[
            _buildResultCard(inspectorState.result!, cardBg, borderColor, l10n),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard(PhishingAnalysisResult res, Color cardBg, Color borderColor, AppLocalizations? l10n) {
    Color verdictColor;
    IconData verdictIcon;
    String verdictTitle = res.verdictTitle;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEn = (l10n?.localeName == 'en') || (Localizations.localeOf(context).languageCode == 'en');
    final scoreLabel = l10n?.smsScoreLabel ?? (isEn ? 'Risk score' : 'Score de risque');

    switch (res.level) {
      case PhishingRiskLevel.dangerous:
        verdictColor = AppTheme.accentRed;
        verdictIcon = Icons.dangerous_rounded;
        verdictTitle = l10n?.smsThreatDetected ?? res.verdictTitle;
        break;
      case PhishingRiskLevel.suspicious:
        verdictColor = AppTheme.accentOrange;
        verdictIcon = Icons.warning_amber_rounded;
        verdictTitle = l10n?.smsSuspicious ?? res.verdictTitle;
        break;
      case PhishingRiskLevel.safe:
        verdictColor = AppTheme.accentGreen;
        verdictIcon = Icons.check_circle_outline_rounded;
        verdictTitle = l10n?.smsSafe ?? res.verdictTitle;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: verdictColor.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: verdictColor.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête du diagnostic
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: verdictColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(verdictIcon, color: verdictColor, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      verdictTitle,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: verdictColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$scoreLabel : ${res.riskScore}/100',
                      style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Jauge visuelle explicite du score de risque
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: res.riskScore / 100.0,
              minHeight: 8,
              backgroundColor: isDark ? Colors.white10 : Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(verdictColor),
            ),
          ),
          const SizedBox(height: 14),
          Text(res.verdictDescription, style: const TextStyle(fontSize: 13, height: 1.4)),

          // Liens extraits et analyse de réputation approfondie
          if (res.extractedUrls.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEn ? 'DETECTED LINKS & DOMAIN REPUTATION' : 'LIENS DÉTECTÉS & RÉPUTATION DE DOMAINE',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.0),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${res.extractedUrls.length} ${isEn ? "link(s)" : "lien(s)"}',
                    style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...res.extractedUrls.map((u) {
              final uri = Uri.tryParse(u);
              final host = uri?.host.toLowerCase() ?? u;
              final isHttp = u.startsWith('http://');
              final isShortener = ['bit.ly', 'tinyurl.com', 'is.gd', 't.co', 'cutt.ly', 'rb.gy'].any((s) => host.contains(s));
              final isSuspiciousTld = ['.top', '.xyz', '.ru', '.cn', '.cc', '.live', '.work', '.click'].any((tld) => host.endsWith(tld));

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.link_off_rounded, size: 18, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            u,
                            style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.red, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (isHttp)
                          _buildReputationTag('Protocole HTTP non chiffré', Colors.red),
                        if (isShortener)
                          _buildReputationTag('Raccourcisseur masquant la destination', Colors.orange),
                        if (isSuspiciousTld)
                          _buildReputationTag('Extension de domaine suspecte (.top/.xyz)', Colors.red),
                        _buildReputationTag('Hôte: $host', Colors.grey),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],

          // Signaux d'alerte détectés
          if (res.detectedRedFlags.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              l10n?.smsIndicatorsLabel ?? (isEn ? 'SUSPICION INDICATORS' : 'INDICATEURS DE SUSPICION'),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.0),
            ),
            const SizedBox(height: 6),
            ...res.detectedRedFlags.map((flag) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.arrow_right_rounded, size: 18, color: Colors.orange),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(flag, style: const TextStyle(fontSize: 12, height: 1.3)),
                  ),
                ],
              ),
            )),
          ],

          // Recommandations
          if (res.recommendations.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              l10n?.smsAdviceLabel ?? (isEn ? 'SECURITY ADVICE' : 'CONSEILS DE SÉCURITÉ'),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.0),
            ),
            const SizedBox(height: 6),
            ...res.recommendations.map((rec) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_rounded, size: 16, color: AppTheme.accentGreen),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(rec, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildReputationTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.bold),
      ),
    );
  }
}
