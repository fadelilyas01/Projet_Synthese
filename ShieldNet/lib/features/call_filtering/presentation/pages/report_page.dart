import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/citizen_impact_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../controllers/blacklist_controller.dart';

class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key});

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  final _phoneController = TextEditingController();
  final _commentController = TextEditingController();
  String _selectedCategory = 'fraud';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    final l10n = AppLocalizations.of(context);
    final rawPhone = _phoneController.text.trim();
    final digitsOnly = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 7) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.reportInvalidPhone ?? 'Veuillez saisir un numéro de téléphone valide (au moins 7 chiffres).'),
          backgroundColor: AppTheme.accentOrange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final result = await ref.read(blacklistProvider.notifier).reportSpam(
      rawPhoneNumber: rawPhone,
      category: _selectedCategory,
      comment: _commentController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);

      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message),
              backgroundColor: AppTheme.accentRed,
            ),
          );
        },
        (_) async {
          _phoneController.clear();
          _commentController.clear();
          await CitizenImpactService.incrementReportsCount();
          // Rafraîchir la liste noire locale
          ref.read(blacklistControllerProvider.notifier).loadBlacklist();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n?.reportSuccessToast ?? 'Merci ! Votre signalement a été enregistré pour protéger la communauté.'),
                backgroundColor: AppTheme.accentGreen,
              ),
            );
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.reportPageTitle ?? 'Signaler un Numéro', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n?.reportHelpCommunity ?? 'Aidez la communauté',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              l10n?.reportHelpCommunityDesc ?? 'Signalez un numéro suspect pour le bloquer et avertir les autres utilisateurs de ShieldNet.',
              style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: l10n?.reportPhoneLabel ?? 'Numéro de téléphone suspect',
                hintText: '+1 819 123 4567',
                prefixIcon: const Icon(Icons.phone_rounded),
              ),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                labelText: l10n?.reportCategoryLabel ?? 'Nature de la nuisance',
                prefixIcon: const Icon(Icons.category_rounded),
              ),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: [
                DropdownMenuItem(value: 'fraud', child: Text(l10n?.reportCatFraud ?? 'Fraude / Arnaque')),
                DropdownMenuItem(value: 'telemarketing', child: Text(l10n?.reportCatTelemarketing ?? 'Démarchage Commercial')),
                DropdownMenuItem(value: 'financial_scam', child: Text(l10n?.reportCatFinancialScam ?? 'Arnaque Financière')),
                DropdownMenuItem(value: 'phishing', child: Text(l10n?.reportCatPhishing ?? 'Faux SMS / Hameçonnage')),
                DropdownMenuItem(value: 'robocall', child: Text(l10n?.reportCatRobocall ?? 'Appel automatisé (robot)')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n?.reportCommentLabel ?? 'Commentaire (Optionnel)',
                hintText: l10n?.reportCommentHint ?? 'Précisez le contexte de l\'appel...',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 40.0),
                  child: Icon(Icons.chat_bubble_outline_rounded),
                ),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitReport,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 20),
              ),
              label: Text(l10n?.reportSubmitButton ?? 'Transmettre le Signalement', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    (l10n?.localeName == 'en')
                        ? '100% private: your personal identity is never disclosed.'
                        : '100% confidentiel : votre identité n\'est jamais communiquée.',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    textAlign: TextAlign.center,
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
