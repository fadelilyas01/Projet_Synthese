import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/emergency_whitelist_service.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../l10n/app_localizations.dart';

class EmergencyWhitelistPage extends ConsumerStatefulWidget {
  const EmergencyWhitelistPage({super.key});

  @override
  ConsumerState<EmergencyWhitelistPage> createState() => _EmergencyWhitelistPageState();
}

class _EmergencyWhitelistPageState extends ConsumerState<EmergencyWhitelistPage> {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _labelController = TextEditingController();

  @override
  void dispose() {
    _numberController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  void _showAddContactDialog() {
    _numberController.clear();
    _labelController.clear();
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 24.0),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGreen.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_moderator_rounded, color: AppTheme.accentGreen, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n?.addWhitelistTitle ?? 'Ajouter à la Liste Blanche',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n?.addWhitelistDesc ??
                          'Ce numéro bénéficiera d\'une immunité totale. Il ne sera jamais bloqué ni filtré par ShieldNet.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _labelController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: l10n?.labelField ?? 'Nom ou Organisation',
                        hintText: l10n?.labelHint ?? 'Ex: Hôpital, Dr. Tremblay...',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return l10n?.labelValidator ?? 'Veuillez renseigner un libellé';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _numberController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: l10n?.phoneField ?? 'Numéro de téléphone',
                        hintText: l10n?.phoneHint ?? 'Ex: +1 819 555 0199',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return l10n?.phoneValidatorEmpty ?? 'Veuillez saisir un numéro';
                        }
                        final digits = val.replaceAll(RegExp(r'\D'), '');
                        if (digits.length < 3) {
                          return l10n?.phoneValidatorShort ?? 'Numéro trop court';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () async {
                        if (_formKey.currentState?.validate() ?? false) {
                          HapticFeedback.mediumImpact();
                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(ctx);
                          final success = await ref
                              .read(emergencyWhitelistProvider.notifier)
                              .addContact(
                                rawNumber: _numberController.text.trim(),
                                label: _labelController.text.trim(),
                              );
                          navigator.pop();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? (l10n?.addSuccess ?? 'Contact d\'urgence protégé avec succès.')
                                    : (l10n?.addError ?? 'Erreur lors de l\'enregistrement.'),
                              ),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              backgroundColor: success ? AppTheme.accentGreen : AppTheme.accentRed,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.shield_rounded),
                      label: Text(
                        l10n?.btnSaveImmunity ?? 'Enregistrer avec Immunité',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(EmergencyContact contact) {
    final l10n = AppLocalizations.of(context);
    final isEn = (l10n?.localeName == 'en') || (Localizations.localeOf(context).languageCode == 'en');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n?.confirmRemoveTitle ?? (isEn ? 'Remove from Whitelist?' : 'Retirer de la Liste Blanche ?')),
        content: Text(
          l10n?.confirmRemoveDesc ??
              (isEn
                  ? 'Do you want to remove this contact from the emergency whitelist? It will be subject to normal spam filtering again.'
                  : 'Voulez-vous retirer ce contact de la liste blanche d\'urgence ? Il sera à nouveau soumis aux filtres standards.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n?.btnCancel ?? (isEn ? 'Cancel' : 'Annuler')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ref
                  .read(emergencyWhitelistProvider.notifier)
                  .removeContact(contact.phoneHash);
              if (mounted && ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n?.removeSuccess ??
                        (isEn ? 'Contact removed from whitelist.' : 'Contact retiré de la liste blanche.')),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: AppTheme.accentOrange,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(l10n?.btnRemove ?? (isEn ? 'Remove' : 'Retirer')),
          ),
        ],
      ),
    );
  }

  String _getSystemContactLabel(EmergencyContact item, bool isEn) {
    if (!isEn) return item.label;
    switch (item.rawNumber.trim()) {
      case '911':
        return 'Emergency Services (Police, Fire, Ambulance)';
      case '988':
        return 'Suicide Crisis & Mental Health Helpline';
      case '211':
        return 'Community & Social Services';
      case '311':
        return 'Non-Emergency Municipal Services';
      case '511':
        return 'Traffic & Road Conditions Info';
      case '811':
        return 'Health & Social Info Line';
      default:
        return item.label;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final state = ref.watch(emergencyWhitelistProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final isEn = (l10n?.localeName == 'en') || (Localizations.localeOf(context).languageCode == 'en');

    final systemContacts = state.contacts.where((c) => c.isSystemCritical).toList();
    final customContacts = state.contacts.where((c) => !c.isSystemCritical).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n?.emergencyWhitelistTitle ?? (isEn ? 'Emergency Numbers & Immunity' : 'Numéros d\'Urgence & Immunité'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          overflow: TextOverflow.ellipsis,
        ),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddContactDialog,
        backgroundColor: AppTheme.accentGreen,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          l10n?.addEmergencyContact ?? (isEn ? 'Add a Contact' : 'Ajouter un Contact'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
              children: [
                // Note d'information sur la politique d'exclusion stricte
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withValues(alpha: isDark ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.accentGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.health_and_safety_rounded, color: AppTheme.accentGreen, size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n?.zeroFalsePositiveTitle ?? (isEn ? 'Zero False-Positive Guarantee' : 'Garantie Zéro Faux-Positif'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppTheme.accentGreen,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n?.zeroFalsePositiveDesc ??
                                  (isEn
                                      ? 'These priority numbers are never blocked or filtered, even if Strict Shield mode (Contacts Only) or Do Not Disturb is active.'
                                      : 'Ces numéros prioritaires ne sont jamais bloqués ni filtrés, même si le mode Bouclier Strict (Contacts uniquement) ou Nocturne est actif.'),
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Section des numéros personnels ajoutés par l'utilisateur
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        l10n?.customEmergencyContactsHeader ?? (isEn ? 'USER PRIORITY CONTACTS' : 'CONTACTS PRIORITAIRES UTILISATEUR'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${customContacts.length}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentGreen),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (customContacts.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                    ),
                    child: EmptyStateWidget(
                      icon: Icons.contact_emergency_rounded,
                      iconColor: AppTheme.accentGreen,
                      title: l10n?.emptyCustomContactsTitle ?? (isEn ? 'No priority contacts added' : 'Aucun contact prioritaire ajouté'),
                      message: l10n?.emptyCustomContactsDesc ??
                          (isEn
                              ? 'Add your doctor, hospital, or clinic to ensure their calls always ring through.'
                              : 'Ajoutez votre médecin, l\'hôpital ou une clinique pour garantir que leurs appels passent toujours.'),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: customContacts.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, indent: 56),
                      itemBuilder: (ctx, index) {
                        final contact = customContacts[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.accentGreen.withValues(alpha: 0.15),
                            child: const Icon(Icons.person_pin_rounded, color: AppTheme.accentGreen, size: 20),
                          ),
                          title: Text(
                            contact.label,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            contact.rawNumber,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.accentRed, size: 20),
                            onPressed: () => _confirmDelete(contact),
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 24),

                // Services publics d'urgence préconfigurés (non modifiables)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        l10n?.nationalEmergencyServicesHeader ?? (isEn ? 'NATIONAL EMERGENCY SERVICES (CANADA / US)' : 'SERVICES D\'URGENCE NATIONAUX (CANADA/QC)'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l10n?.inviolableBadge ?? (isEn ? 'Inviolable' : 'Inviolable'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryLightColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: systemContacts.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 56),
                    itemBuilder: (ctx, index) {
                      final item = systemContacts[index];
                      final shortcutLabel = l10n?.officialShortcut ?? (isEn ? 'Official emergency shortcode' : 'Raccourci officiel');
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.accentRed.withValues(alpha: 0.12),
                          child: Text(
                            item.rawNumber,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.accentRed),
                          ),
                        ),
                        title: Text(
                          _getSystemContactLabel(item, isEn),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '$shortcutLabel (${item.rawNumber})',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Tooltip(
                          message: l10n?.systemProtectionTooltip ?? (isEn ? 'System-protected service cannot be removed' : 'Protection système non supprimable'),
                          child: const Icon(Icons.lock_outline_rounded, size: 16, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
