// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'ShieldNet Anti-Spam';

  @override
  String get tabProtection => 'Protection';

  @override
  String get tabActivity => 'Activité';

  @override
  String get tabHistory => 'Activité';

  @override
  String get tabBlacklist => 'Liste Noire';

  @override
  String get tabReport => 'Signaler';

  @override
  String get tabSettings => 'Paramètres';

  @override
  String get shieldRealtime => 'Bouclier en temps réel';

  @override
  String get shieldSuspended => 'Filtrage suspendu';

  @override
  String get shieldProtected => 'Vous êtes protégé';

  @override
  String get shieldInactive => 'Protection inactive';

  @override
  String get shieldActiveDesc =>
      'ShieldNet filtre automatiquement les appels malveillants.';

  @override
  String get shieldInactiveDesc =>
      'Activez le filtrage pour bloquer les appels indésirables.';

  @override
  String get btnActivateProtection => 'Activer la protection';

  @override
  String get protectionActiveSuccess =>
      'Protection ShieldNet activée avec succès !';

  @override
  String get protectionPermissionRequired =>
      'Veuillez accorder les autorisations pour activer la protection.';

  @override
  String get shieldStrictBadge => 'Bouclier Strict (Contacts Seuls)';

  @override
  String get shieldStrictTitle => 'Protection Maximale';

  @override
  String get shieldStrictDesc =>
      'Seuls vos contacts enregistrés sont autorisés à sonner.';

  @override
  String get settingContactsOnly => 'Mode Contacts Uniquement';

  @override
  String get settingContactsOnlyDesc =>
      'Ne laisser sonner que vos contacts enregistrés';

  @override
  String get searchSuspectNumber => 'Vérifier un numéro suspect';

  @override
  String get searchSuspectDesc =>
      'Rechercher instantanément dans la base anti-spam';

  @override
  String get statSpamIntercepted => 'Spams interceptés';

  @override
  String get statNumbersBlocked => 'Numéros bloqués';

  @override
  String get recentBlockedSpams => 'Derniers Spams Bloqués';

  @override
  String get verifyCallAction => 'Vérifier un appel';

  @override
  String get calmLineTitle => 'Ligne calme et sécurisée';

  @override
  String get calmLineDesc =>
      'Aucune menace récente détectée sur votre appareil.';

  @override
  String get badgeBlocked => 'Bloqué';

  @override
  String get maskedNumberDefault => 'Numéro masqué';

  @override
  String get dialogCheckNumber => 'Vérifier un numéro';

  @override
  String get dialogCheckPrompt =>
      'Saisissez un numéro pour vérifier s\'il est signalé comme spam :';

  @override
  String get btnCancel => 'Annuler';

  @override
  String get btnVerify => 'Vérifier';

  @override
  String get btnUnderstood => 'Compris';

  @override
  String get dialogVerified => 'Numéro Vérifié';

  @override
  String get dialogSpamDetected => 'Attention : Spam Détecté';

  @override
  String get dialogSafeNumber => 'Numéro Sûr';

  @override
  String get dialogVerifiedDesc =>
      'Ce numéro est vérifié et certifié par l\'administrateur.';

  @override
  String get dialogSpamDesc => 'Ce numéro a été identifié comme indésirable.';

  @override
  String get dialogSafeDesc => 'Aucun signalement malveillant pour ce numéro.';

  @override
  String get activityTitle => 'Activité Téléphonique';

  @override
  String get tabRecentCalls => 'Appels Récents';

  @override
  String get tabBlockedNumbers => 'Numéros Bloqués';

  @override
  String get noRecentCalls => 'Aucun appel récent';

  @override
  String get noRecentCallsDesc =>
      'Les appels récents s\'afficheront ici avec leur état de sécurité.';

  @override
  String get noBlockedNumbers => 'Aucun numéro bloqué';

  @override
  String get noBlockedNumbersDesc =>
      'Tous les numéros signalés ou bloqués par le filtre automatique apparaîtront ici.';

  @override
  String get noResultsFound => 'Aucun résultat trouvé';

  @override
  String get tryAnotherSearch => 'Essayez avec un autre terme de recherche.';

  @override
  String get searchBlockedPlaceholder => 'Rechercher un numéro bloqué...';

  @override
  String get blockAndReport => 'Bloquer & Signaler';

  @override
  String get reportReason => 'Motif du signalement :';

  @override
  String get categoryScam => 'Arnaque';

  @override
  String get categoryTelemarketing => 'Démarchage';

  @override
  String get categoryPhishing => 'Phishing';

  @override
  String get categoryRobocall => 'Automate / Silence';

  @override
  String get btnBlockThisNumber => 'Bloquer ce numéro';

  @override
  String get incomingCall => 'Appel entrant';

  @override
  String get spamBlocked => 'Spam bloqué';

  @override
  String get riskWord => 'risque';

  @override
  String get timeJustNow => 'À l\'instant';

  @override
  String get timeTodayAt => 'Aujourd\'hui à';

  @override
  String get timeYesterdayAt => 'Hier à';

  @override
  String get unknownCaller => 'Inconnu';

  @override
  String get reportSuccessMessage => 'Numéro bloqué et signalé avec succès.';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get sectionSecurity => 'SÉCURITÉ';

  @override
  String get sectionPreferences => 'PRÉFÉRENCES';

  @override
  String get sectionAdmin => 'ADMINISTRATION';

  @override
  String get settingCallFiltering => 'Filtrage d\'appels';

  @override
  String get settingSmsFiltering => 'Filtrage des SMS';

  @override
  String get settingBgSync => 'Sync en arrière-plan';

  @override
  String get settingUpdateDb => 'Mettre à jour la base';

  @override
  String get btnSync => 'Synchroniser';

  @override
  String get syncSuccess => 'Synchronisation réussie';

  @override
  String get syncSuccessDetail => 'Protection à jour : numéros synchronisés.';

  @override
  String get settingTheme => 'Thème';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get settingLanguage => 'Langue';

  @override
  String get langFrench => 'Français';

  @override
  String get langEnglish => 'English';

  @override
  String get adminConsoleTitle => 'Console d\'Administration';

  @override
  String get userAccountTitle => 'Compte Utilisateur';

  @override
  String get userAccountSubtitle => 'Se connecter ou s\'inscrire';

  @override
  String get btnLogout => 'Déconnexion';

  @override
  String get logoutSuccess => 'Déconnexion réussie.';

  @override
  String get protectionActive => '100% PROTÉGÉ';

  @override
  String get protectionPartial => 'PROTECTION PARTIELLE';

  @override
  String get protectionActiveDescOld =>
      'ShieldNet bloque les appels indésirables en temps réel avant sonnerie.';

  @override
  String get protectionPartialDesc =>
      'Activez le filtrage natif Android pour activer la protection complète.';

  @override
  String get btnEnableNative => 'Activer le Filtrage Natif';

  @override
  String get statLocalDb => 'Base Locale';

  @override
  String get statFiltered => 'Numéros filtrés';

  @override
  String get statProtectedZone => 'Zone Protégée';

  @override
  String get statZoneDesc => '+1 (Canada / É-U)';

  @override
  String get callLogTitle => 'Historique des Appels';

  @override
  String get callLogReportPrompt => 'Signaler ce numéro ?';

  @override
  String get callLogReportDesc =>
      'Voulez-vous signaler ce numéro comme étant du spam ? Ce signalement sera partagé avec la communauté.';

  @override
  String get btnReport => 'Signaler';

  @override
  String get reportSuccess => 'Signalement réussi !';

  @override
  String get reportLocal => 'Enregistré localement.';

  @override
  String get emergencyWhitelistTitle => 'Numéros d\'Urgence & Immunité';

  @override
  String get addEmergencyContact => 'Ajouter un Contact';

  @override
  String get addWhitelistTitle => 'Ajouter à la Liste Blanche';

  @override
  String get addWhitelistDesc =>
      'Ce numéro bénéficiera d\'une immunité totale. Il ne sera jamais bloqué ni filtré par ShieldNet.';

  @override
  String get labelField => 'Nom ou Organisation';

  @override
  String get labelHint => 'Ex: Hôpital de Gatineau, Dr. Tremblay, École...';

  @override
  String get labelValidator => 'Veuillez renseigner un libellé';

  @override
  String get phoneField => 'Numéro de téléphone';

  @override
  String get phoneHint => 'Ex: +1 819 555 0199 ou 8195550199';

  @override
  String get phoneValidatorEmpty => 'Veuillez saisir un numéro';

  @override
  String get phoneValidatorShort => 'Numéro trop court';

  @override
  String get btnSaveImmunity => 'Enregistrer avec Immunité';

  @override
  String get addSuccess => 'Contact d\'urgence protégé avec succès.';

  @override
  String get addError => 'Erreur lors de l\'enregistrement.';

  @override
  String get confirmRemoveTitle => 'Retirer de la Liste Blanche ?';

  @override
  String get confirmRemoveDesc =>
      'Voulez-vous retirer ce contact de la liste blanche d\'urgence ? Il sera à nouveau soumis aux filtres standards.';

  @override
  String get btnRemove => 'Retirer';

  @override
  String get removeSuccess => 'Contact retiré de la liste blanche.';

  @override
  String get zeroFalsePositiveTitle => 'Garantie Zéro Faux-Positif';

  @override
  String get zeroFalsePositiveDesc =>
      'Ces numéros prioritaires ne sont jamais bloqués ni filtrés, même si le mode Bouclier Strict (Contacts uniquement) ou Nocturne est actif.';

  @override
  String get customEmergencyContactsHeader =>
      'CONTACTS PRIORITAIRES UTILISATEUR';

  @override
  String get emptyCustomContactsTitle => 'Aucun contact prioritaire ajouté';

  @override
  String get emptyCustomContactsDesc =>
      'Ajoutez votre médecin, l\'hôpital ou une clinique pour garantir que leurs appels passent toujours.';

  @override
  String get nationalEmergencyServicesHeader =>
      'SERVICES D\'URGENCE NATIONAUX (CANADA / ÉTATS-UNIS)';

  @override
  String get inviolableBadge => 'Inviolable';

  @override
  String get officialShortcut => 'Raccourci officiel';

  @override
  String get systemProtectionTooltip => 'Protection système non supprimable';

  @override
  String get welcomeTitle => 'Bienvenue sur ShieldNet';

  @override
  String get welcomeSubtitle => 'Choisissez votre langue d\'utilisation :';

  @override
  String get btnSelectLanguage => 'Confirmer la langue';

  @override
  String get selectLanguagePrompt =>
      'Vous pourrez modifier la langue à tout moment dans les paramètres.';

  @override
  String get languageFr => 'Français (Canada)';

  @override
  String get languageEn => 'English (US / Canada)';

  @override
  String get onboardingSkip => 'Passer';

  @override
  String get onboardingContinue => 'Continuer';

  @override
  String get onboardingActivate => 'Activer la protection';

  @override
  String get onboardingSlide1Title => 'Protection Anti-Spam';

  @override
  String get onboardingSlide1Sub => 'Tranquillité absolue au quotidien';

  @override
  String get onboardingSlide1Text =>
      'ShieldNet filtre les appels malveillants et le démarchage agressif en temps réel sans jamais perturber votre ligne.';

  @override
  String get onboardingSlide1Feat1 => 'Blocage automatique des spams connus';

  @override
  String get onboardingSlide1Feat2 => 'Filtrage en arrière-plan sans sonnerie';

  @override
  String get onboardingSlide1Feat3 =>
      'Vérification instantanée des numéros suspects';

  @override
  String get onboardingSlide2Title => 'Confidentialité Totale';

  @override
  String get onboardingSlide2Sub =>
      'Vos données ne quittent jamais votre appareil';

  @override
  String get onboardingSlide2Text =>
      'Vos contacts et votre carnet d\'adresses restent strictement sur votre appareil. Seuls les numéros suspects sont vérifiés sans jamais exposer votre vie privée.';

  @override
  String get onboardingSlide2Feat1 => 'Vérification 100% locale et sécurisée';

  @override
  String get onboardingSlide2Feat2 => 'Zéro partage de vos contacts personnels';

  @override
  String get onboardingSlide2Feat3 => 'Respect absolu de votre vie privée';

  @override
  String get onboardingSlide3Title => 'Prêt en 1 Geste';

  @override
  String get onboardingSlide3Sub => 'Activez le bouclier intelligent';

  @override
  String get onboardingSlide3Text =>
      'Accordez les autorisations nécessaires pour permettre à ShieldNet d\'intercepter les spams avant qu\'ils ne sonnent.';

  @override
  String get onboardingSlide3Feat1 => 'Rôle de filtrage d\'appels natif';

  @override
  String get onboardingSlide3Feat2 => 'Détection préventive des SMS frauduleux';

  @override
  String get onboardingSlide3Feat3 =>
      'Protection active 24h/24 en toute discrétion';

  @override
  String get seniorModeActiveTitle => 'Mode Simplifié Actif';

  @override
  String get seniorModeActiveDesc =>
      'Textes et boutons agrandis. Votre téléphone est protégé contre toute fraude.';

  @override
  String get actionCheckNumber => 'Vérifier Numéro';

  @override
  String get actionCheckNumberSub => 'Annuaire anti-spam';

  @override
  String get actionSmsInspector => 'Inspecteur SMS';

  @override
  String get actionSmsInspectorSub => 'Détection phishing';

  @override
  String get nightShieldActiveBadge => 'Bouclier Nocturne Actif';

  @override
  String get copiedNumberDetected => 'Numéro copié détecté';

  @override
  String get serenityOptimal => 'Protection Optimale';

  @override
  String get serenityHigh => 'Protection Élevée';

  @override
  String get serenityPartial => 'Protection Partielle';

  @override
  String get serenityVulnerable => 'Appareil Vulnérable';

  @override
  String get serenityAllBarriers =>
      'Toutes les barrières de protection sont activées.';

  @override
  String serenityActionsNeeded(Object count) {
    return '$count action(s) recommandée(s) pour 100% de protection.';
  }

  @override
  String get serenityTipPrefix => 'Conseil :';

  @override
  String get serenityImproveScore => 'Améliorer mon score';

  @override
  String get recNativeFilterTitle => 'Activez le filtrage d\'appels natif';

  @override
  String get recNativeFilterDesc =>
      'Bloque automatiquement les numéros malveillants avant que le téléphone ne sonne.';

  @override
  String get recUpdateDbTitle => 'Mettez à jour la base anti-spam';

  @override
  String get recUpdateDbDesc =>
      'Téléchargez les derniers signalements pour rester protégé même sans réseau.';

  @override
  String get recAutoBlockTitle => 'Activez le blocage automatique';

  @override
  String get recAutoBlockDesc =>
      'Rejette directement les arnaques avérées sans vous déranger.';

  @override
  String get recBiometricTitle => 'Sécurisez l\'accès par biométrie';

  @override
  String get recBiometricDesc =>
      'Protégez vos listes blanches et données personnelles par empreinte ou visage.';

  @override
  String get recContactsOnlyTitle => 'Activez le mode Contacts Uniquement';

  @override
  String get recContactsOnlyDesc =>
      'Pour une protection complète, seuls vos contacts enregistrés peuvent faire sonner l\'appareil.';

  @override
  String get citizenImpactTitle => 'Signalements communautaires';

  @override
  String get citizenImpactSub => 'Partage de signalements';

  @override
  String citizenProtectedCount(Object count) {
    return '~$count concitoyens protégés';
  }

  @override
  String get citizenReportToProtect =>
      'Signalez un spam pour protéger les autres utilisateurs.';

  @override
  String citizenThanksReports(Object count) {
    return 'Grâce à vos $count signalement(s) validé(s).';
  }

  @override
  String get rankInitial => 'Niveau 1 : Signalement initial';

  @override
  String get rankSentinel => 'Sentinelle Vigilante';

  @override
  String get rankGuardian => 'Protecteur Citoyen';

  @override
  String get rankPillar => 'Pilier de la Communauté';

  @override
  String get regionalRadarTitle => 'Radar Régional des Arnaques';

  @override
  String get regionalRadarDesc =>
      'Analyse en temps réel des vagues d\'usurpation d\'identité (Spoofing) ciblées par indicatif régional (Canada / États-Unis).';

  @override
  String get regionalAlertPrefix => 'Alerte Indicatif';

  @override
  String regionalWaveDesc(Object region) {
    return 'Vague active d\'appels frauduleux ciblant la région : $region.';
  }

  @override
  String get regionalReportsCount => 'signalements • Type :';

  @override
  String get reportPageTitle => 'Signaler un Numéro';

  @override
  String get reportHelpCommunity => 'Aidez la communauté';

  @override
  String get reportHelpCommunityDesc =>
      'Signalez un numéro suspect pour le bloquer et avertir les autres utilisateurs de ShieldNet.';

  @override
  String get reportPhoneLabel => 'Numéro de téléphone suspect';

  @override
  String get reportCategoryLabel => 'Nature de la nuisance';

  @override
  String get reportCatFraud => 'Fraude / Arnaque';

  @override
  String get reportCatTelemarketing => 'Démarchage Commercial';

  @override
  String get reportCatFinancialScam => 'Arnaque Financière';

  @override
  String get reportCatPhishing => 'Hameçonnage / Phishing';

  @override
  String get reportCatRobocall => 'Appel Automatisé / Robocall';

  @override
  String get reportCommentLabel => 'Commentaire (Optionnel)';

  @override
  String get reportCommentHint => 'Précisez le contexte de l\'appel...';

  @override
  String get reportSubmitButton => 'Transmettre le Signalement';

  @override
  String get reportInvalidPhone =>
      'Veuillez saisir un numéro de téléphone valide (au moins 7 chiffres).';

  @override
  String get reportSuccessToast =>
      'Merci ! Votre signalement a été enregistré pour protéger la communauté.';

  @override
  String get smsInspectorTitle => 'Inspecteur de SMS & Liens';

  @override
  String get smsInspectorOfflineTitle =>
      'Analyse 100% Hors-Ligne & Confidentielle';

  @override
  String get smsInspectorOfflineDesc =>
      'Le texte de vos SMS n\'est jamais transmis à un serveur distant.';

  @override
  String get smsInspectorInputHint =>
      'Collez ici le texte du SMS suspect ou le message reçu...';

  @override
  String get smsInspectorBtnPaste => 'Coller le SMS';

  @override
  String get smsInspectorBtnInspect => 'Inspecter';

  @override
  String get smsInspectorClipboardEmpty => 'Le presse-papier est vide.';

  @override
  String get smsInspectorReset => 'Réinitialiser';

  @override
  String get smsRiskAnalysisTitle => 'Analyse du Risque :';

  @override
  String get smsThreatDetected => 'Menace Détectée';

  @override
  String get smsSuspicious => 'Message Suspect';

  @override
  String get smsSafe => 'Message Semblant Sain';

  @override
  String get smsScoreLabel => 'Score de Risque';

  @override
  String get smsIndicatorsLabel => 'Indicateurs détectés';

  @override
  String get smsAdviceLabel => 'Conseil de Sécurité';

  @override
  String get settingNightShield => 'Mode Bouclier Nocturne';

  @override
  String get settingNightShieldDesc =>
      'Filtrage silencieux durant vos heures de sommeil';

  @override
  String get settingSmsInspector => 'Inspecteur de SMS & Liens';

  @override
  String get settingSmsInspectorDesc =>
      'Analyser un message suspect ou un lien de livraison';

  @override
  String get settingEmergencyWhitelist => 'Numéros d\'Urgence & Liste Blanche';

  @override
  String get settingEmergencyWhitelistDesc =>
      '911, 988 et contacts prioritaires garantis';

  @override
  String get settingSeniorMode => 'Mode Interface Simplifiée (Aînés)';

  @override
  String get settingSeniorModeDesc =>
      'Agrandit les textes, renforce les contrastes et simplifie l\'accueil';

  @override
  String get sectionOfflineResilience => 'RÉSILIENCE & HORS-LIGNE';

  @override
  String get settingOfflineQueue => 'File d\'attente hors-ligne';

  @override
  String get settingOfflineQueueAllSynced =>
      'Tous les signalements sont synchronisés';

  @override
  String settingOfflineQueuePending(Object count) {
    return '$count signalement(s) en attente de synchronisation';
  }

  @override
  String get sectionModeration => 'GESTION & MODÉRATION';

  @override
  String get consoleModerationTitle => 'Console de Gestion & Modération';

  @override
  String get appVersionFooter => 'ShieldNet v1.0.0 • Sécurité Télécom';

  @override
  String auditCompletedSpam(Object count) {
    return 'Audit terminé : $count numéro(s) suspect(s) identifié(s) dans votre journal.';
  }

  @override
  String auditCompletedClean(Object count) {
    return 'Audit terminé : Vos $count appels récents sont sains.';
  }

  @override
  String get auditNetworkError => 'Impossible d\'effectuer l\'audit réseau.';

  @override
  String get auditNoVerifiableNumbers =>
      'Aucun numéro vérifiable dans le journal récent.';

  @override
  String get disputeModalTitle => 'Contestation de Faux-Positif';

  @override
  String get disputeCallNature => 'Nature de l\'appel légitime :';

  @override
  String get disputeReasonService => 'Service / Entreprise';

  @override
  String get disputeReasonPersonal => 'Personnel / Proche';

  @override
  String get disputeReasonDelivery => 'Livraison / Colis';

  @override
  String get disputeReasonMedical => 'Santé / Médical';

  @override
  String get disputeReasonMistake => 'Erreur de signalement';

  @override
  String get disputeCommentHint =>
      'Précisions utiles (ex: cabinet de mon médecin traitant)';

  @override
  String get disputeProtectedNumber => 'Numéro protégé';

  @override
  String disputeRiskScore(Object count, Object score) {
    return 'Score de risque : $score% ($count signalement(s))';
  }

  @override
  String get disputeFilteredNotice =>
      'Ce numéro est actuellement filtré par ShieldNet. S\'il s\'agit d\'un médecin, d\'un livreur ou d\'un proche légitime, vous pouvez contester ce blocage pour accélérer sa réhabilitation.';

  @override
  String get disputeBtnContest => 'Contester (Faux positif)';

  @override
  String get serenitySecurityLevel => 'Niveau de sécurité';

  @override
  String get serenityRecommendation => 'Recommandation';

  @override
  String get deviceIntegrityRooted => 'Sécurité Système : Appareil Rooté';

  @override
  String get deviceIntegrityDesc =>
      'Un accès super-utilisateur (su / Magisk) est présent. Les protections cryptographiques locales peuvent être vulnérables.';

  @override
  String get disputeSuccessToast =>
      'Avis légitime transmis ! Le consensus communautaire évalue la réhabilitation.';

  @override
  String get disputeErrorToast =>
      'Impossible d\'enregistrer votre contestation.';

  @override
  String get disputeSubmitBtn => 'Transmettre la contestation';

  @override
  String get auditHeaderTitle => 'Audit de sécurité du journal';

  @override
  String get auditHeaderDesc => 'Vérifie vos 50 derniers appels via le Cloud';

  @override
  String get auditHeaderBtn => 'Lancer';

  @override
  String get adminFullAdmin => 'Administration Totale';

  @override
  String get adminManagerSpace => 'Espace Gestionnaire & Modération';

  @override
  String get adminTabOverview => 'Vue d\'ensemble';

  @override
  String get adminTabBlacklist => 'Liste Noire';

  @override
  String get adminTabReports => 'Signalements';

  @override
  String get adminTabUsers => 'Utilisateurs';

  @override
  String get adminTabAudit => 'Audit & Traces';

  @override
  String get adminAddNumber => 'Ajouter un Numéro';

  @override
  String get adminRefreshAll => 'Tout actualiser';

  @override
  String get sectionJurisdiction => 'RÉGION & CONFIDENTIALITÉ';

  @override
  String get regionSelectionTitle => 'Votre Région';

  @override
  String get regionSelectionSubtitle =>
      'Protection adaptée à vos indicatifs et territoire';

  @override
  String get selectCountryPrompt => '1. SÉLECTIONNEZ VOTRE PAYS';

  @override
  String get selectProvincePrompt =>
      '2. SÉLECTIONNEZ VOTRE PROVINCE / TERRITOIRE';

  @override
  String get selectStatePrompt => '2. SÉLECTIONNEZ VOTRE ÉTAT (STATE)';

  @override
  String get applyRegionBtn => 'Appliquer cette région';

  @override
  String get onboardingRegionTitle => 'Protection Régionale';

  @override
  String get onboardingRegionDesc =>
      'ShieldNet adapte automatiquement son niveau de protection à votre territoire pour bloquer le spam local tout en protégeant vos urgences (911, 811, 988) et votre vie privée.';

  @override
  String get helpFaqTitle => 'Centre d\'Aide & FAQ';

  @override
  String get helpFaqSubtitle =>
      'Questions fréquentes, confidentialité et documentation';

  @override
  String get openWebHelpBtn => 'Consulter le Centre d\'Assistance Web';

  @override
  String get webHelpNotice =>
      'Accédez aux guides détaillés, politiques de confidentialité et contact support sur notre portail web.';

  @override
  String get searchFaqPlaceholder => 'Rechercher une question...';

  @override
  String get faqCategoryFiltering => 'Filtrage & Efficacité';

  @override
  String get faqCategoryPrivacy => 'Confidentialité & Données';

  @override
  String get faqCategoryEmergency => 'Numéros d\'Urgence & Faux Positifs';

  @override
  String get faqCategoryPermissions => 'Permissions Android';
}
