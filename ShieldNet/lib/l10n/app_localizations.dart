import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'ShieldNet Anti-Spam'**
  String get appTitle;

  /// No description provided for @tabProtection.
  ///
  /// In fr, this message translates to:
  /// **'Protection'**
  String get tabProtection;

  /// No description provided for @tabActivity.
  ///
  /// In fr, this message translates to:
  /// **'Activité'**
  String get tabActivity;

  /// No description provided for @tabHistory.
  ///
  /// In fr, this message translates to:
  /// **'Activité'**
  String get tabHistory;

  /// No description provided for @tabBlacklist.
  ///
  /// In fr, this message translates to:
  /// **'Liste Noire'**
  String get tabBlacklist;

  /// No description provided for @tabReport.
  ///
  /// In fr, this message translates to:
  /// **'Signaler'**
  String get tabReport;

  /// No description provided for @tabSettings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get tabSettings;

  /// No description provided for @shieldRealtime.
  ///
  /// In fr, this message translates to:
  /// **'Bouclier en temps réel'**
  String get shieldRealtime;

  /// No description provided for @shieldSuspended.
  ///
  /// In fr, this message translates to:
  /// **'Filtrage suspendu'**
  String get shieldSuspended;

  /// No description provided for @shieldProtected.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes protégé'**
  String get shieldProtected;

  /// No description provided for @shieldInactive.
  ///
  /// In fr, this message translates to:
  /// **'Protection inactive'**
  String get shieldInactive;

  /// No description provided for @shieldActiveDesc.
  ///
  /// In fr, this message translates to:
  /// **'ShieldNet filtre automatiquement les appels malveillants.'**
  String get shieldActiveDesc;

  /// No description provided for @shieldInactiveDesc.
  ///
  /// In fr, this message translates to:
  /// **'Activez le filtrage pour bloquer les appels indésirables.'**
  String get shieldInactiveDesc;

  /// No description provided for @btnActivateProtection.
  ///
  /// In fr, this message translates to:
  /// **'Activer la protection'**
  String get btnActivateProtection;

  /// No description provided for @protectionActiveSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Protection ShieldNet activée avec succès !'**
  String get protectionActiveSuccess;

  /// No description provided for @protectionPermissionRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez accorder les autorisations pour activer la protection.'**
  String get protectionPermissionRequired;

  /// No description provided for @shieldStrictBadge.
  ///
  /// In fr, this message translates to:
  /// **'Bouclier Strict (Contacts Seuls)'**
  String get shieldStrictBadge;

  /// No description provided for @shieldStrictTitle.
  ///
  /// In fr, this message translates to:
  /// **'Protection Maximale'**
  String get shieldStrictTitle;

  /// No description provided for @shieldStrictDesc.
  ///
  /// In fr, this message translates to:
  /// **'Seuls vos contacts enregistrés sont autorisés à sonner.'**
  String get shieldStrictDesc;

  /// No description provided for @settingContactsOnly.
  ///
  /// In fr, this message translates to:
  /// **'Mode Contacts Uniquement'**
  String get settingContactsOnly;

  /// No description provided for @settingContactsOnlyDesc.
  ///
  /// In fr, this message translates to:
  /// **'Ne laisser sonner que vos contacts enregistrés'**
  String get settingContactsOnlyDesc;

  /// No description provided for @searchSuspectNumber.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier un numéro suspect'**
  String get searchSuspectNumber;

  /// No description provided for @searchSuspectDesc.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher instantanément dans la base anti-spam'**
  String get searchSuspectDesc;

  /// No description provided for @statSpamIntercepted.
  ///
  /// In fr, this message translates to:
  /// **'Spams interceptés'**
  String get statSpamIntercepted;

  /// No description provided for @statNumbersBlocked.
  ///
  /// In fr, this message translates to:
  /// **'Numéros bloqués'**
  String get statNumbersBlocked;

  /// No description provided for @recentBlockedSpams.
  ///
  /// In fr, this message translates to:
  /// **'Derniers Spams Bloqués'**
  String get recentBlockedSpams;

  /// No description provided for @verifyCallAction.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier un appel'**
  String get verifyCallAction;

  /// No description provided for @calmLineTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ligne calme et sécurisée'**
  String get calmLineTitle;

  /// No description provided for @calmLineDesc.
  ///
  /// In fr, this message translates to:
  /// **'Aucune menace récente détectée sur votre appareil.'**
  String get calmLineDesc;

  /// No description provided for @badgeBlocked.
  ///
  /// In fr, this message translates to:
  /// **'Bloqué'**
  String get badgeBlocked;

  /// No description provided for @maskedNumberDefault.
  ///
  /// In fr, this message translates to:
  /// **'Numéro masqué'**
  String get maskedNumberDefault;

  /// No description provided for @dialogCheckNumber.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier un numéro'**
  String get dialogCheckNumber;

  /// No description provided for @dialogCheckPrompt.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un numéro pour vérifier s\'il est signalé comme spam :'**
  String get dialogCheckPrompt;

  /// No description provided for @btnCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get btnCancel;

  /// No description provided for @btnVerify.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier'**
  String get btnVerify;

  /// No description provided for @btnUnderstood.
  ///
  /// In fr, this message translates to:
  /// **'Compris'**
  String get btnUnderstood;

  /// No description provided for @dialogVerified.
  ///
  /// In fr, this message translates to:
  /// **'Numéro Vérifié'**
  String get dialogVerified;

  /// No description provided for @dialogSpamDetected.
  ///
  /// In fr, this message translates to:
  /// **'Attention : Spam Détecté'**
  String get dialogSpamDetected;

  /// No description provided for @dialogSafeNumber.
  ///
  /// In fr, this message translates to:
  /// **'Numéro Sûr'**
  String get dialogSafeNumber;

  /// No description provided for @dialogVerifiedDesc.
  ///
  /// In fr, this message translates to:
  /// **'Ce numéro est vérifié et certifié par l\'administrateur.'**
  String get dialogVerifiedDesc;

  /// No description provided for @dialogSpamDesc.
  ///
  /// In fr, this message translates to:
  /// **'Ce numéro a été identifié comme indésirable.'**
  String get dialogSpamDesc;

  /// No description provided for @dialogSafeDesc.
  ///
  /// In fr, this message translates to:
  /// **'Aucun signalement malveillant pour ce numéro.'**
  String get dialogSafeDesc;

  /// No description provided for @activityTitle.
  ///
  /// In fr, this message translates to:
  /// **'Activité Téléphonique'**
  String get activityTitle;

  /// No description provided for @tabRecentCalls.
  ///
  /// In fr, this message translates to:
  /// **'Appels Récents'**
  String get tabRecentCalls;

  /// No description provided for @tabBlockedNumbers.
  ///
  /// In fr, this message translates to:
  /// **'Numéros Bloqués'**
  String get tabBlockedNumbers;

  /// No description provided for @noRecentCalls.
  ///
  /// In fr, this message translates to:
  /// **'Aucun appel récent'**
  String get noRecentCalls;

  /// No description provided for @noRecentCallsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Les appels récents s\'afficheront ici avec leur état de sécurité.'**
  String get noRecentCallsDesc;

  /// No description provided for @noBlockedNumbers.
  ///
  /// In fr, this message translates to:
  /// **'Aucun numéro bloqué'**
  String get noBlockedNumbers;

  /// No description provided for @noBlockedNumbersDesc.
  ///
  /// In fr, this message translates to:
  /// **'Tous les numéros signalés ou bloqués par le filtre automatique apparaîtront ici.'**
  String get noBlockedNumbersDesc;

  /// No description provided for @noResultsFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat trouvé'**
  String get noResultsFound;

  /// No description provided for @tryAnotherSearch.
  ///
  /// In fr, this message translates to:
  /// **'Essayez avec un autre terme de recherche.'**
  String get tryAnotherSearch;

  /// No description provided for @searchBlockedPlaceholder.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un numéro bloqué...'**
  String get searchBlockedPlaceholder;

  /// No description provided for @blockAndReport.
  ///
  /// In fr, this message translates to:
  /// **'Bloquer & Signaler'**
  String get blockAndReport;

  /// No description provided for @reportReason.
  ///
  /// In fr, this message translates to:
  /// **'Motif du signalement :'**
  String get reportReason;

  /// No description provided for @categoryScam.
  ///
  /// In fr, this message translates to:
  /// **'Arnaque'**
  String get categoryScam;

  /// No description provided for @categoryTelemarketing.
  ///
  /// In fr, this message translates to:
  /// **'Démarchage'**
  String get categoryTelemarketing;

  /// No description provided for @categoryPhishing.
  ///
  /// In fr, this message translates to:
  /// **'Phishing'**
  String get categoryPhishing;

  /// No description provided for @categoryRobocall.
  ///
  /// In fr, this message translates to:
  /// **'Automate / Silence'**
  String get categoryRobocall;

  /// No description provided for @btnBlockThisNumber.
  ///
  /// In fr, this message translates to:
  /// **'Bloquer ce numéro'**
  String get btnBlockThisNumber;

  /// No description provided for @incomingCall.
  ///
  /// In fr, this message translates to:
  /// **'Appel entrant'**
  String get incomingCall;

  /// No description provided for @spamBlocked.
  ///
  /// In fr, this message translates to:
  /// **'Spam bloqué'**
  String get spamBlocked;

  /// No description provided for @riskWord.
  ///
  /// In fr, this message translates to:
  /// **'risque'**
  String get riskWord;

  /// No description provided for @timeJustNow.
  ///
  /// In fr, this message translates to:
  /// **'À l\'instant'**
  String get timeJustNow;

  /// No description provided for @timeTodayAt.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui à'**
  String get timeTodayAt;

  /// No description provided for @timeYesterdayAt.
  ///
  /// In fr, this message translates to:
  /// **'Hier à'**
  String get timeYesterdayAt;

  /// No description provided for @unknownCaller.
  ///
  /// In fr, this message translates to:
  /// **'Inconnu'**
  String get unknownCaller;

  /// No description provided for @reportSuccessMessage.
  ///
  /// In fr, this message translates to:
  /// **'Numéro bloqué et signalé avec succès.'**
  String get reportSuccessMessage;

  /// No description provided for @settingsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get settingsTitle;

  /// No description provided for @sectionSecurity.
  ///
  /// In fr, this message translates to:
  /// **'SÉCURITÉ'**
  String get sectionSecurity;

  /// No description provided for @sectionPreferences.
  ///
  /// In fr, this message translates to:
  /// **'PRÉFÉRENCES'**
  String get sectionPreferences;

  /// No description provided for @sectionAdmin.
  ///
  /// In fr, this message translates to:
  /// **'ADMINISTRATION'**
  String get sectionAdmin;

  /// No description provided for @settingCallFiltering.
  ///
  /// In fr, this message translates to:
  /// **'Filtrage d\'appels'**
  String get settingCallFiltering;

  /// No description provided for @settingSmsFiltering.
  ///
  /// In fr, this message translates to:
  /// **'Filtrage des SMS'**
  String get settingSmsFiltering;

  /// No description provided for @settingBgSync.
  ///
  /// In fr, this message translates to:
  /// **'Sync en arrière-plan'**
  String get settingBgSync;

  /// No description provided for @settingUpdateDb.
  ///
  /// In fr, this message translates to:
  /// **'Mettre à jour la base'**
  String get settingUpdateDb;

  /// No description provided for @btnSync.
  ///
  /// In fr, this message translates to:
  /// **'Synchroniser'**
  String get btnSync;

  /// No description provided for @syncSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisation réussie'**
  String get syncSuccess;

  /// No description provided for @syncSuccessDetail.
  ///
  /// In fr, this message translates to:
  /// **'Protection à jour : numéros synchronisés.'**
  String get syncSuccessDetail;

  /// No description provided for @settingTheme.
  ///
  /// In fr, this message translates to:
  /// **'Thème'**
  String get settingTheme;

  /// No description provided for @themeSystem.
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In fr, this message translates to:
  /// **'Clair'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In fr, this message translates to:
  /// **'Sombre'**
  String get themeDark;

  /// No description provided for @settingLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get settingLanguage;

  /// No description provided for @langFrench.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get langFrench;

  /// No description provided for @langEnglish.
  ///
  /// In fr, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @adminConsoleTitle.
  ///
  /// In fr, this message translates to:
  /// **'Console d\'Administration'**
  String get adminConsoleTitle;

  /// No description provided for @userAccountTitle.
  ///
  /// In fr, this message translates to:
  /// **'Compte Utilisateur'**
  String get userAccountTitle;

  /// No description provided for @userAccountSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter ou s\'inscrire'**
  String get userAccountSubtitle;

  /// No description provided for @btnLogout.
  ///
  /// In fr, this message translates to:
  /// **'Déconnexion'**
  String get btnLogout;

  /// No description provided for @logoutSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Déconnexion réussie.'**
  String get logoutSuccess;

  /// No description provided for @protectionActive.
  ///
  /// In fr, this message translates to:
  /// **'100% PROTÉGÉ'**
  String get protectionActive;

  /// No description provided for @protectionPartial.
  ///
  /// In fr, this message translates to:
  /// **'PROTECTION PARTIELLE'**
  String get protectionPartial;

  /// No description provided for @protectionActiveDescOld.
  ///
  /// In fr, this message translates to:
  /// **'ShieldNet bloque les appels indésirables en temps réel avant sonnerie.'**
  String get protectionActiveDescOld;

  /// No description provided for @protectionPartialDesc.
  ///
  /// In fr, this message translates to:
  /// **'Activez le filtrage natif Android pour activer la protection complète.'**
  String get protectionPartialDesc;

  /// No description provided for @btnEnableNative.
  ///
  /// In fr, this message translates to:
  /// **'Activer le Filtrage Natif'**
  String get btnEnableNative;

  /// No description provided for @statLocalDb.
  ///
  /// In fr, this message translates to:
  /// **'Base Locale'**
  String get statLocalDb;

  /// No description provided for @statFiltered.
  ///
  /// In fr, this message translates to:
  /// **'Numéros filtrés'**
  String get statFiltered;

  /// No description provided for @statProtectedZone.
  ///
  /// In fr, this message translates to:
  /// **'Zone Protégée'**
  String get statProtectedZone;

  /// No description provided for @statZoneDesc.
  ///
  /// In fr, this message translates to:
  /// **'+1 (Canada / É-U)'**
  String get statZoneDesc;

  /// No description provided for @callLogTitle.
  ///
  /// In fr, this message translates to:
  /// **'Historique des Appels'**
  String get callLogTitle;

  /// No description provided for @callLogReportPrompt.
  ///
  /// In fr, this message translates to:
  /// **'Signaler ce numéro ?'**
  String get callLogReportPrompt;

  /// No description provided for @callLogReportDesc.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous signaler ce numéro comme étant du spam ? Ce signalement sera partagé avec la communauté.'**
  String get callLogReportDesc;

  /// No description provided for @btnReport.
  ///
  /// In fr, this message translates to:
  /// **'Signaler'**
  String get btnReport;

  /// No description provided for @reportSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Signalement réussi !'**
  String get reportSuccess;

  /// No description provided for @reportLocal.
  ///
  /// In fr, this message translates to:
  /// **'Enregistré localement.'**
  String get reportLocal;

  /// No description provided for @emergencyWhitelistTitle.
  ///
  /// In fr, this message translates to:
  /// **'Numéros d\'Urgence & Immunité'**
  String get emergencyWhitelistTitle;

  /// No description provided for @addEmergencyContact.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un Contact'**
  String get addEmergencyContact;

  /// No description provided for @addWhitelistTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter à la Liste Blanche'**
  String get addWhitelistTitle;

  /// No description provided for @addWhitelistDesc.
  ///
  /// In fr, this message translates to:
  /// **'Ce numéro bénéficiera d\'une immunité totale. Il ne sera jamais bloqué ni filtré par ShieldNet.'**
  String get addWhitelistDesc;

  /// No description provided for @labelField.
  ///
  /// In fr, this message translates to:
  /// **'Nom ou Organisation'**
  String get labelField;

  /// No description provided for @labelHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Hôpital de Gatineau, Dr. Tremblay, École...'**
  String get labelHint;

  /// No description provided for @labelValidator.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez renseigner un libellé'**
  String get labelValidator;

  /// No description provided for @phoneField.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de téléphone'**
  String get phoneField;

  /// No description provided for @phoneHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: +1 819 555 0199 ou 8195550199'**
  String get phoneHint;

  /// No description provided for @phoneValidatorEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez saisir un numéro'**
  String get phoneValidatorEmpty;

  /// No description provided for @phoneValidatorShort.
  ///
  /// In fr, this message translates to:
  /// **'Numéro trop court'**
  String get phoneValidatorShort;

  /// No description provided for @btnSaveImmunity.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer avec Immunité'**
  String get btnSaveImmunity;

  /// No description provided for @addSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Contact d\'urgence protégé avec succès.'**
  String get addSuccess;

  /// No description provided for @addError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'enregistrement.'**
  String get addError;

  /// No description provided for @confirmRemoveTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retirer de la Liste Blanche ?'**
  String get confirmRemoveTitle;

  /// No description provided for @confirmRemoveDesc.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous retirer ce contact de la liste blanche d\'urgence ? Il sera à nouveau soumis aux filtres standards.'**
  String get confirmRemoveDesc;

  /// No description provided for @btnRemove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get btnRemove;

  /// No description provided for @removeSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Contact retiré de la liste blanche.'**
  String get removeSuccess;

  /// No description provided for @zeroFalsePositiveTitle.
  ///
  /// In fr, this message translates to:
  /// **'Garantie Zéro Faux-Positif'**
  String get zeroFalsePositiveTitle;

  /// No description provided for @zeroFalsePositiveDesc.
  ///
  /// In fr, this message translates to:
  /// **'Ces numéros prioritaires ne sont jamais bloqués ni filtrés, même si le mode Bouclier Strict (Contacts uniquement) ou Nocturne est actif.'**
  String get zeroFalsePositiveDesc;

  /// No description provided for @customEmergencyContactsHeader.
  ///
  /// In fr, this message translates to:
  /// **'CONTACTS PRIORITAIRES UTILISATEUR'**
  String get customEmergencyContactsHeader;

  /// No description provided for @emptyCustomContactsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contact prioritaire ajouté'**
  String get emptyCustomContactsTitle;

  /// No description provided for @emptyCustomContactsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez votre médecin, l\'hôpital ou une clinique pour garantir que leurs appels passent toujours.'**
  String get emptyCustomContactsDesc;

  /// No description provided for @nationalEmergencyServicesHeader.
  ///
  /// In fr, this message translates to:
  /// **'SERVICES D\'URGENCE NATIONAUX (CANADA / ÉTATS-UNIS)'**
  String get nationalEmergencyServicesHeader;

  /// No description provided for @inviolableBadge.
  ///
  /// In fr, this message translates to:
  /// **'Inviolable'**
  String get inviolableBadge;

  /// No description provided for @officialShortcut.
  ///
  /// In fr, this message translates to:
  /// **'Raccourci officiel'**
  String get officialShortcut;

  /// No description provided for @systemProtectionTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Protection système non supprimable'**
  String get systemProtectionTooltip;

  /// No description provided for @welcomeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue sur ShieldNet'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez votre langue d\'utilisation :'**
  String get welcomeSubtitle;

  /// No description provided for @btnSelectLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la langue'**
  String get btnSelectLanguage;

  /// No description provided for @selectLanguagePrompt.
  ///
  /// In fr, this message translates to:
  /// **'Vous pourrez modifier la langue à tout moment dans les paramètres.'**
  String get selectLanguagePrompt;

  /// No description provided for @languageFr.
  ///
  /// In fr, this message translates to:
  /// **'Français (Canada)'**
  String get languageFr;

  /// No description provided for @languageEn.
  ///
  /// In fr, this message translates to:
  /// **'English (US / Canada)'**
  String get languageEn;

  /// No description provided for @onboardingSkip.
  ///
  /// In fr, this message translates to:
  /// **'Passer'**
  String get onboardingSkip;

  /// No description provided for @onboardingContinue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get onboardingContinue;

  /// No description provided for @onboardingActivate.
  ///
  /// In fr, this message translates to:
  /// **'Activer la protection'**
  String get onboardingActivate;

  /// No description provided for @onboardingSlide1Title.
  ///
  /// In fr, this message translates to:
  /// **'Protection Anti-Spam'**
  String get onboardingSlide1Title;

  /// No description provided for @onboardingSlide1Sub.
  ///
  /// In fr, this message translates to:
  /// **'Tranquillité absolue au quotidien'**
  String get onboardingSlide1Sub;

  /// No description provided for @onboardingSlide1Text.
  ///
  /// In fr, this message translates to:
  /// **'ShieldNet filtre les appels malveillants et le démarchage agressif en temps réel sans jamais perturber votre ligne.'**
  String get onboardingSlide1Text;

  /// No description provided for @onboardingSlide1Feat1.
  ///
  /// In fr, this message translates to:
  /// **'Blocage automatique des spams connus'**
  String get onboardingSlide1Feat1;

  /// No description provided for @onboardingSlide1Feat2.
  ///
  /// In fr, this message translates to:
  /// **'Filtrage en arrière-plan sans sonnerie'**
  String get onboardingSlide1Feat2;

  /// No description provided for @onboardingSlide1Feat3.
  ///
  /// In fr, this message translates to:
  /// **'Vérification instantanée des numéros suspects'**
  String get onboardingSlide1Feat3;

  /// No description provided for @onboardingSlide2Title.
  ///
  /// In fr, this message translates to:
  /// **'Confidentialité Totale'**
  String get onboardingSlide2Title;

  /// No description provided for @onboardingSlide2Sub.
  ///
  /// In fr, this message translates to:
  /// **'Vos données ne quittent jamais votre appareil'**
  String get onboardingSlide2Sub;

  /// No description provided for @onboardingSlide2Text.
  ///
  /// In fr, this message translates to:
  /// **'Vos contacts et votre carnet d\'adresses restent strictement sur votre appareil. Seuls les numéros suspects sont vérifiés sans jamais exposer votre vie privée.'**
  String get onboardingSlide2Text;

  /// No description provided for @onboardingSlide2Feat1.
  ///
  /// In fr, this message translates to:
  /// **'Vérification 100% locale et sécurisée'**
  String get onboardingSlide2Feat1;

  /// No description provided for @onboardingSlide2Feat2.
  ///
  /// In fr, this message translates to:
  /// **'Zéro partage de vos contacts personnels'**
  String get onboardingSlide2Feat2;

  /// No description provided for @onboardingSlide2Feat3.
  ///
  /// In fr, this message translates to:
  /// **'Respect absolu de votre vie privée'**
  String get onboardingSlide2Feat3;

  /// No description provided for @onboardingSlide3Title.
  ///
  /// In fr, this message translates to:
  /// **'Prêt en 1 Geste'**
  String get onboardingSlide3Title;

  /// No description provided for @onboardingSlide3Sub.
  ///
  /// In fr, this message translates to:
  /// **'Activez le bouclier intelligent'**
  String get onboardingSlide3Sub;

  /// No description provided for @onboardingSlide3Text.
  ///
  /// In fr, this message translates to:
  /// **'Accordez les autorisations nécessaires pour permettre à ShieldNet d\'intercepter les spams avant qu\'ils ne sonnent.'**
  String get onboardingSlide3Text;

  /// No description provided for @onboardingSlide3Feat1.
  ///
  /// In fr, this message translates to:
  /// **'Rôle de filtrage d\'appels natif'**
  String get onboardingSlide3Feat1;

  /// No description provided for @onboardingSlide3Feat2.
  ///
  /// In fr, this message translates to:
  /// **'Détection préventive des SMS frauduleux'**
  String get onboardingSlide3Feat2;

  /// No description provided for @onboardingSlide3Feat3.
  ///
  /// In fr, this message translates to:
  /// **'Protection active 24h/24 en toute discrétion'**
  String get onboardingSlide3Feat3;

  /// No description provided for @seniorModeActiveTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mode Simplifié Actif'**
  String get seniorModeActiveTitle;

  /// No description provided for @seniorModeActiveDesc.
  ///
  /// In fr, this message translates to:
  /// **'Textes et boutons agrandis. Votre téléphone est protégé contre toute fraude.'**
  String get seniorModeActiveDesc;

  /// No description provided for @actionCheckNumber.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier Numéro'**
  String get actionCheckNumber;

  /// No description provided for @actionCheckNumberSub.
  ///
  /// In fr, this message translates to:
  /// **'Annuaire anti-spam'**
  String get actionCheckNumberSub;

  /// No description provided for @actionSmsInspector.
  ///
  /// In fr, this message translates to:
  /// **'Inspecteur SMS'**
  String get actionSmsInspector;

  /// No description provided for @actionSmsInspectorSub.
  ///
  /// In fr, this message translates to:
  /// **'Détection phishing'**
  String get actionSmsInspectorSub;

  /// No description provided for @nightShieldActiveBadge.
  ///
  /// In fr, this message translates to:
  /// **'Bouclier Nocturne Actif'**
  String get nightShieldActiveBadge;

  /// No description provided for @copiedNumberDetected.
  ///
  /// In fr, this message translates to:
  /// **'Numéro copié détecté'**
  String get copiedNumberDetected;

  /// No description provided for @serenityOptimal.
  ///
  /// In fr, this message translates to:
  /// **'Protection Optimale'**
  String get serenityOptimal;

  /// No description provided for @serenityHigh.
  ///
  /// In fr, this message translates to:
  /// **'Protection Élevée'**
  String get serenityHigh;

  /// No description provided for @serenityPartial.
  ///
  /// In fr, this message translates to:
  /// **'Protection Partielle'**
  String get serenityPartial;

  /// No description provided for @serenityVulnerable.
  ///
  /// In fr, this message translates to:
  /// **'Appareil Vulnérable'**
  String get serenityVulnerable;

  /// No description provided for @serenityAllBarriers.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les barrières de protection sont activées.'**
  String get serenityAllBarriers;

  /// No description provided for @serenityActionsNeeded.
  ///
  /// In fr, this message translates to:
  /// **'{count} action(s) recommandée(s) pour 100% de protection.'**
  String serenityActionsNeeded(Object count);

  /// No description provided for @serenityTipPrefix.
  ///
  /// In fr, this message translates to:
  /// **'Conseil :'**
  String get serenityTipPrefix;

  /// No description provided for @serenityImproveScore.
  ///
  /// In fr, this message translates to:
  /// **'Améliorer mon score'**
  String get serenityImproveScore;

  /// No description provided for @recNativeFilterTitle.
  ///
  /// In fr, this message translates to:
  /// **'Activez le filtrage d\'appels natif'**
  String get recNativeFilterTitle;

  /// No description provided for @recNativeFilterDesc.
  ///
  /// In fr, this message translates to:
  /// **'Bloque automatiquement les numéros malveillants avant que le téléphone ne sonne.'**
  String get recNativeFilterDesc;

  /// No description provided for @recUpdateDbTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mettez à jour la base anti-spam'**
  String get recUpdateDbTitle;

  /// No description provided for @recUpdateDbDesc.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargez les derniers signalements pour rester protégé même sans réseau.'**
  String get recUpdateDbDesc;

  /// No description provided for @recAutoBlockTitle.
  ///
  /// In fr, this message translates to:
  /// **'Activez le blocage automatique'**
  String get recAutoBlockTitle;

  /// No description provided for @recAutoBlockDesc.
  ///
  /// In fr, this message translates to:
  /// **'Rejette directement les arnaques avérées sans vous déranger.'**
  String get recAutoBlockDesc;

  /// No description provided for @recBiometricTitle.
  ///
  /// In fr, this message translates to:
  /// **'Sécurisez l\'accès par biométrie'**
  String get recBiometricTitle;

  /// No description provided for @recBiometricDesc.
  ///
  /// In fr, this message translates to:
  /// **'Protégez vos listes blanches et données personnelles par empreinte ou visage.'**
  String get recBiometricDesc;

  /// No description provided for @recContactsOnlyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Activez le mode Contacts Uniquement'**
  String get recContactsOnlyTitle;

  /// No description provided for @recContactsOnlyDesc.
  ///
  /// In fr, this message translates to:
  /// **'Pour une protection complète, seuls vos contacts enregistrés peuvent faire sonner l\'appareil.'**
  String get recContactsOnlyDesc;

  /// No description provided for @citizenImpactTitle.
  ///
  /// In fr, this message translates to:
  /// **'Signalements communautaires'**
  String get citizenImpactTitle;

  /// No description provided for @citizenImpactSub.
  ///
  /// In fr, this message translates to:
  /// **'Partage de signalements'**
  String get citizenImpactSub;

  /// No description provided for @citizenProtectedCount.
  ///
  /// In fr, this message translates to:
  /// **'~{count} concitoyens protégés'**
  String citizenProtectedCount(Object count);

  /// No description provided for @citizenReportToProtect.
  ///
  /// In fr, this message translates to:
  /// **'Signalez un spam pour protéger les autres utilisateurs.'**
  String get citizenReportToProtect;

  /// No description provided for @citizenThanksReports.
  ///
  /// In fr, this message translates to:
  /// **'Grâce à vos {count} signalement(s) validé(s).'**
  String citizenThanksReports(Object count);

  /// No description provided for @rankInitial.
  ///
  /// In fr, this message translates to:
  /// **'Niveau 1 : Signalement initial'**
  String get rankInitial;

  /// No description provided for @rankSentinel.
  ///
  /// In fr, this message translates to:
  /// **'Sentinelle Vigilante'**
  String get rankSentinel;

  /// No description provided for @rankGuardian.
  ///
  /// In fr, this message translates to:
  /// **'Protecteur Citoyen'**
  String get rankGuardian;

  /// No description provided for @rankPillar.
  ///
  /// In fr, this message translates to:
  /// **'Pilier de la Communauté'**
  String get rankPillar;

  /// No description provided for @regionalRadarTitle.
  ///
  /// In fr, this message translates to:
  /// **'Radar Régional des Arnaques'**
  String get regionalRadarTitle;

  /// No description provided for @regionalRadarDesc.
  ///
  /// In fr, this message translates to:
  /// **'Analyse en temps réel des vagues d\'usurpation d\'identité (Spoofing) ciblées par indicatif régional (Canada / États-Unis).'**
  String get regionalRadarDesc;

  /// No description provided for @regionalAlertPrefix.
  ///
  /// In fr, this message translates to:
  /// **'Alerte Indicatif'**
  String get regionalAlertPrefix;

  /// No description provided for @regionalWaveDesc.
  ///
  /// In fr, this message translates to:
  /// **'Vague active d\'appels frauduleux ciblant la région : {region}.'**
  String regionalWaveDesc(Object region);

  /// No description provided for @regionalReportsCount.
  ///
  /// In fr, this message translates to:
  /// **'signalements • Type :'**
  String get regionalReportsCount;

  /// No description provided for @reportPageTitle.
  ///
  /// In fr, this message translates to:
  /// **'Signaler un Numéro'**
  String get reportPageTitle;

  /// No description provided for @reportHelpCommunity.
  ///
  /// In fr, this message translates to:
  /// **'Aidez la communauté'**
  String get reportHelpCommunity;

  /// No description provided for @reportHelpCommunityDesc.
  ///
  /// In fr, this message translates to:
  /// **'Signalez un numéro suspect pour le bloquer et avertir les autres utilisateurs de ShieldNet.'**
  String get reportHelpCommunityDesc;

  /// No description provided for @reportPhoneLabel.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de téléphone suspect'**
  String get reportPhoneLabel;

  /// No description provided for @reportCategoryLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nature de la nuisance'**
  String get reportCategoryLabel;

  /// No description provided for @reportCatFraud.
  ///
  /// In fr, this message translates to:
  /// **'Fraude / Arnaque'**
  String get reportCatFraud;

  /// No description provided for @reportCatTelemarketing.
  ///
  /// In fr, this message translates to:
  /// **'Démarchage Commercial'**
  String get reportCatTelemarketing;

  /// No description provided for @reportCatFinancialScam.
  ///
  /// In fr, this message translates to:
  /// **'Arnaque Financière'**
  String get reportCatFinancialScam;

  /// No description provided for @reportCatPhishing.
  ///
  /// In fr, this message translates to:
  /// **'Hameçonnage / Phishing'**
  String get reportCatPhishing;

  /// No description provided for @reportCatRobocall.
  ///
  /// In fr, this message translates to:
  /// **'Appel Automatisé / Robocall'**
  String get reportCatRobocall;

  /// No description provided for @reportCommentLabel.
  ///
  /// In fr, this message translates to:
  /// **'Commentaire (Optionnel)'**
  String get reportCommentLabel;

  /// No description provided for @reportCommentHint.
  ///
  /// In fr, this message translates to:
  /// **'Précisez le contexte de l\'appel...'**
  String get reportCommentHint;

  /// No description provided for @reportSubmitButton.
  ///
  /// In fr, this message translates to:
  /// **'Transmettre le Signalement'**
  String get reportSubmitButton;

  /// No description provided for @reportInvalidPhone.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez saisir un numéro de téléphone valide (au moins 7 chiffres).'**
  String get reportInvalidPhone;

  /// No description provided for @reportSuccessToast.
  ///
  /// In fr, this message translates to:
  /// **'Merci ! Votre signalement a été enregistré pour protéger la communauté.'**
  String get reportSuccessToast;

  /// No description provided for @smsInspectorTitle.
  ///
  /// In fr, this message translates to:
  /// **'Inspecteur de SMS & Liens'**
  String get smsInspectorTitle;

  /// No description provided for @smsInspectorOfflineTitle.
  ///
  /// In fr, this message translates to:
  /// **'Analyse 100% Hors-Ligne & Confidentielle'**
  String get smsInspectorOfflineTitle;

  /// No description provided for @smsInspectorOfflineDesc.
  ///
  /// In fr, this message translates to:
  /// **'Le texte de vos SMS n\'est jamais transmis à un serveur distant.'**
  String get smsInspectorOfflineDesc;

  /// No description provided for @smsInspectorInputHint.
  ///
  /// In fr, this message translates to:
  /// **'Collez ici le texte du SMS suspect ou le message reçu...'**
  String get smsInspectorInputHint;

  /// No description provided for @smsInspectorBtnPaste.
  ///
  /// In fr, this message translates to:
  /// **'Coller le SMS'**
  String get smsInspectorBtnPaste;

  /// No description provided for @smsInspectorBtnInspect.
  ///
  /// In fr, this message translates to:
  /// **'Inspecter'**
  String get smsInspectorBtnInspect;

  /// No description provided for @smsInspectorClipboardEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Le presse-papier est vide.'**
  String get smsInspectorClipboardEmpty;

  /// No description provided for @smsInspectorReset.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser'**
  String get smsInspectorReset;

  /// No description provided for @smsRiskAnalysisTitle.
  ///
  /// In fr, this message translates to:
  /// **'Analyse du Risque :'**
  String get smsRiskAnalysisTitle;

  /// No description provided for @smsThreatDetected.
  ///
  /// In fr, this message translates to:
  /// **'Menace Détectée'**
  String get smsThreatDetected;

  /// No description provided for @smsSuspicious.
  ///
  /// In fr, this message translates to:
  /// **'Message Suspect'**
  String get smsSuspicious;

  /// No description provided for @smsSafe.
  ///
  /// In fr, this message translates to:
  /// **'Message Semblant Sain'**
  String get smsSafe;

  /// No description provided for @smsScoreLabel.
  ///
  /// In fr, this message translates to:
  /// **'Score de Risque'**
  String get smsScoreLabel;

  /// No description provided for @smsIndicatorsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Indicateurs détectés'**
  String get smsIndicatorsLabel;

  /// No description provided for @smsAdviceLabel.
  ///
  /// In fr, this message translates to:
  /// **'Conseil de Sécurité'**
  String get smsAdviceLabel;

  /// No description provided for @settingNightShield.
  ///
  /// In fr, this message translates to:
  /// **'Mode Bouclier Nocturne'**
  String get settingNightShield;

  /// No description provided for @settingNightShieldDesc.
  ///
  /// In fr, this message translates to:
  /// **'Filtrage silencieux durant vos heures de sommeil'**
  String get settingNightShieldDesc;

  /// No description provided for @settingSmsInspector.
  ///
  /// In fr, this message translates to:
  /// **'Inspecteur de SMS & Liens'**
  String get settingSmsInspector;

  /// No description provided for @settingSmsInspectorDesc.
  ///
  /// In fr, this message translates to:
  /// **'Analyser un message suspect ou un lien de livraison'**
  String get settingSmsInspectorDesc;

  /// No description provided for @settingEmergencyWhitelist.
  ///
  /// In fr, this message translates to:
  /// **'Numéros d\'Urgence & Liste Blanche'**
  String get settingEmergencyWhitelist;

  /// No description provided for @settingEmergencyWhitelistDesc.
  ///
  /// In fr, this message translates to:
  /// **'911, 988 et contacts prioritaires garantis'**
  String get settingEmergencyWhitelistDesc;

  /// No description provided for @settingSeniorMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode Interface Simplifiée (Aînés)'**
  String get settingSeniorMode;

  /// No description provided for @settingSeniorModeDesc.
  ///
  /// In fr, this message translates to:
  /// **'Agrandit les textes, renforce les contrastes et simplifie l\'accueil'**
  String get settingSeniorModeDesc;

  /// No description provided for @sectionOfflineResilience.
  ///
  /// In fr, this message translates to:
  /// **'RÉSILIENCE & HORS-LIGNE'**
  String get sectionOfflineResilience;

  /// No description provided for @settingOfflineQueue.
  ///
  /// In fr, this message translates to:
  /// **'File d\'attente hors-ligne'**
  String get settingOfflineQueue;

  /// No description provided for @settingOfflineQueueAllSynced.
  ///
  /// In fr, this message translates to:
  /// **'Tous les signalements sont synchronisés'**
  String get settingOfflineQueueAllSynced;

  /// No description provided for @settingOfflineQueuePending.
  ///
  /// In fr, this message translates to:
  /// **'{count} signalement(s) en attente de synchronisation'**
  String settingOfflineQueuePending(Object count);

  /// No description provided for @sectionModeration.
  ///
  /// In fr, this message translates to:
  /// **'GESTION & MODÉRATION'**
  String get sectionModeration;

  /// No description provided for @consoleModerationTitle.
  ///
  /// In fr, this message translates to:
  /// **'Console de Gestion & Modération'**
  String get consoleModerationTitle;

  /// No description provided for @appVersionFooter.
  ///
  /// In fr, this message translates to:
  /// **'ShieldNet v1.0.0 • Sécurité Télécom'**
  String get appVersionFooter;

  /// No description provided for @auditCompletedSpam.
  ///
  /// In fr, this message translates to:
  /// **'Audit terminé : {count} numéro(s) suspect(s) identifié(s) dans votre journal.'**
  String auditCompletedSpam(Object count);

  /// No description provided for @auditCompletedClean.
  ///
  /// In fr, this message translates to:
  /// **'Audit terminé : Vos {count} appels récents sont sains.'**
  String auditCompletedClean(Object count);

  /// No description provided for @auditNetworkError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'effectuer l\'audit réseau.'**
  String get auditNetworkError;

  /// No description provided for @auditNoVerifiableNumbers.
  ///
  /// In fr, this message translates to:
  /// **'Aucun numéro vérifiable dans le journal récent.'**
  String get auditNoVerifiableNumbers;

  /// No description provided for @disputeModalTitle.
  ///
  /// In fr, this message translates to:
  /// **'Contestation de Faux-Positif'**
  String get disputeModalTitle;

  /// No description provided for @disputeCallNature.
  ///
  /// In fr, this message translates to:
  /// **'Nature de l\'appel légitime :'**
  String get disputeCallNature;

  /// No description provided for @disputeReasonService.
  ///
  /// In fr, this message translates to:
  /// **'Service / Entreprise'**
  String get disputeReasonService;

  /// No description provided for @disputeReasonPersonal.
  ///
  /// In fr, this message translates to:
  /// **'Personnel / Proche'**
  String get disputeReasonPersonal;

  /// No description provided for @disputeReasonDelivery.
  ///
  /// In fr, this message translates to:
  /// **'Livraison / Colis'**
  String get disputeReasonDelivery;

  /// No description provided for @disputeReasonMedical.
  ///
  /// In fr, this message translates to:
  /// **'Santé / Médical'**
  String get disputeReasonMedical;

  /// No description provided for @disputeReasonMistake.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de signalement'**
  String get disputeReasonMistake;

  /// No description provided for @disputeCommentHint.
  ///
  /// In fr, this message translates to:
  /// **'Précisions utiles (ex: cabinet de mon médecin traitant)'**
  String get disputeCommentHint;

  /// No description provided for @disputeProtectedNumber.
  ///
  /// In fr, this message translates to:
  /// **'Numéro protégé'**
  String get disputeProtectedNumber;

  /// No description provided for @disputeRiskScore.
  ///
  /// In fr, this message translates to:
  /// **'Score de risque : {score}% ({count} signalement(s))'**
  String disputeRiskScore(Object count, Object score);

  /// No description provided for @disputeFilteredNotice.
  ///
  /// In fr, this message translates to:
  /// **'Ce numéro est actuellement filtré par ShieldNet. S\'il s\'agit d\'un médecin, d\'un livreur ou d\'un proche légitime, vous pouvez contester ce blocage pour accélérer sa réhabilitation.'**
  String get disputeFilteredNotice;

  /// No description provided for @disputeBtnContest.
  ///
  /// In fr, this message translates to:
  /// **'Contester (Faux positif)'**
  String get disputeBtnContest;

  /// No description provided for @serenitySecurityLevel.
  ///
  /// In fr, this message translates to:
  /// **'Niveau de sécurité'**
  String get serenitySecurityLevel;

  /// No description provided for @serenityRecommendation.
  ///
  /// In fr, this message translates to:
  /// **'Recommandation'**
  String get serenityRecommendation;

  /// No description provided for @deviceIntegrityRooted.
  ///
  /// In fr, this message translates to:
  /// **'Sécurité Système : Appareil Rooté'**
  String get deviceIntegrityRooted;

  /// No description provided for @deviceIntegrityDesc.
  ///
  /// In fr, this message translates to:
  /// **'Un accès super-utilisateur (su / Magisk) est présent. Les protections cryptographiques locales peuvent être vulnérables.'**
  String get deviceIntegrityDesc;

  /// No description provided for @disputeSuccessToast.
  ///
  /// In fr, this message translates to:
  /// **'Avis légitime transmis ! Le consensus communautaire évalue la réhabilitation.'**
  String get disputeSuccessToast;

  /// No description provided for @disputeErrorToast.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'enregistrer votre contestation.'**
  String get disputeErrorToast;

  /// No description provided for @disputeSubmitBtn.
  ///
  /// In fr, this message translates to:
  /// **'Transmettre la contestation'**
  String get disputeSubmitBtn;

  /// No description provided for @auditHeaderTitle.
  ///
  /// In fr, this message translates to:
  /// **'Audit de sécurité du journal'**
  String get auditHeaderTitle;

  /// No description provided for @auditHeaderDesc.
  ///
  /// In fr, this message translates to:
  /// **'Vérifie vos 50 derniers appels via le Cloud'**
  String get auditHeaderDesc;

  /// No description provided for @auditHeaderBtn.
  ///
  /// In fr, this message translates to:
  /// **'Lancer'**
  String get auditHeaderBtn;

  /// No description provided for @adminFullAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Administration Totale'**
  String get adminFullAdmin;

  /// No description provided for @adminManagerSpace.
  ///
  /// In fr, this message translates to:
  /// **'Espace Gestionnaire & Modération'**
  String get adminManagerSpace;

  /// No description provided for @adminTabOverview.
  ///
  /// In fr, this message translates to:
  /// **'Vue d\'ensemble'**
  String get adminTabOverview;

  /// No description provided for @adminTabBlacklist.
  ///
  /// In fr, this message translates to:
  /// **'Liste Noire'**
  String get adminTabBlacklist;

  /// No description provided for @adminTabReports.
  ///
  /// In fr, this message translates to:
  /// **'Signalements'**
  String get adminTabReports;

  /// No description provided for @adminTabUsers.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateurs'**
  String get adminTabUsers;

  /// No description provided for @adminTabAudit.
  ///
  /// In fr, this message translates to:
  /// **'Audit & Traces'**
  String get adminTabAudit;

  /// No description provided for @adminAddNumber.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un Numéro'**
  String get adminAddNumber;

  /// No description provided for @adminRefreshAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout actualiser'**
  String get adminRefreshAll;

  /// No description provided for @sectionJurisdiction.
  ///
  /// In fr, this message translates to:
  /// **'RÉGION & CONFIDENTIALITÉ'**
  String get sectionJurisdiction;

  /// No description provided for @regionSelectionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre Région'**
  String get regionSelectionTitle;

  /// No description provided for @regionSelectionSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Protection adaptée à vos indicatifs et territoire'**
  String get regionSelectionSubtitle;

  /// No description provided for @selectCountryPrompt.
  ///
  /// In fr, this message translates to:
  /// **'1. SÉLECTIONNEZ VOTRE PAYS'**
  String get selectCountryPrompt;

  /// No description provided for @selectProvincePrompt.
  ///
  /// In fr, this message translates to:
  /// **'2. SÉLECTIONNEZ VOTRE PROVINCE / TERRITOIRE'**
  String get selectProvincePrompt;

  /// No description provided for @selectStatePrompt.
  ///
  /// In fr, this message translates to:
  /// **'2. SÉLECTIONNEZ VOTRE ÉTAT (STATE)'**
  String get selectStatePrompt;

  /// No description provided for @applyRegionBtn.
  ///
  /// In fr, this message translates to:
  /// **'Appliquer cette région'**
  String get applyRegionBtn;

  /// No description provided for @onboardingRegionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Protection Régionale'**
  String get onboardingRegionTitle;

  /// No description provided for @onboardingRegionDesc.
  ///
  /// In fr, this message translates to:
  /// **'ShieldNet adapte automatiquement son niveau de protection à votre territoire pour bloquer le spam local tout en protégeant vos urgences (911, 811, 988) et votre vie privée.'**
  String get onboardingRegionDesc;

  /// No description provided for @helpFaqTitle.
  ///
  /// In fr, this message translates to:
  /// **'Centre d\'Aide & FAQ'**
  String get helpFaqTitle;

  /// No description provided for @helpFaqSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Questions fréquentes, confidentialité et documentation'**
  String get helpFaqSubtitle;

  /// No description provided for @openWebHelpBtn.
  ///
  /// In fr, this message translates to:
  /// **'Consulter le Centre d\'Assistance Web'**
  String get openWebHelpBtn;

  /// No description provided for @webHelpNotice.
  ///
  /// In fr, this message translates to:
  /// **'Accédez aux guides détaillés, politiques de confidentialité et contact support sur notre portail web.'**
  String get webHelpNotice;

  /// No description provided for @searchFaqPlaceholder.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une question...'**
  String get searchFaqPlaceholder;

  /// No description provided for @faqCategoryFiltering.
  ///
  /// In fr, this message translates to:
  /// **'Filtrage & Efficacité'**
  String get faqCategoryFiltering;

  /// No description provided for @faqCategoryPrivacy.
  ///
  /// In fr, this message translates to:
  /// **'Confidentialité & Données'**
  String get faqCategoryPrivacy;

  /// No description provided for @faqCategoryEmergency.
  ///
  /// In fr, this message translates to:
  /// **'Numéros d\'Urgence & Faux Positifs'**
  String get faqCategoryEmergency;

  /// No description provided for @faqCategoryPermissions.
  ///
  /// In fr, this message translates to:
  /// **'Permissions Android'**
  String get faqCategoryPermissions;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
