// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ShieldNet Anti-Spam';

  @override
  String get tabProtection => 'Protection';

  @override
  String get tabActivity => 'Activity';

  @override
  String get tabHistory => 'Activity';

  @override
  String get tabBlacklist => 'Blacklist';

  @override
  String get tabReport => 'Report';

  @override
  String get tabSettings => 'Settings';

  @override
  String get shieldRealtime => 'Real-time shield';

  @override
  String get shieldSuspended => 'Filtering suspended';

  @override
  String get shieldProtected => 'You are protected';

  @override
  String get shieldInactive => 'Protection inactive';

  @override
  String get shieldActiveDesc =>
      'ShieldNet automatically filters malicious calls.';

  @override
  String get shieldInactiveDesc => 'Enable filtering to block unwanted calls.';

  @override
  String get btnActivateProtection => 'Activate protection';

  @override
  String get protectionActiveSuccess =>
      'ShieldNet protection activated successfully!';

  @override
  String get protectionPermissionRequired =>
      'Please grant permissions to activate protection.';

  @override
  String get shieldStrictBadge => 'Strict Shield (Contacts Only)';

  @override
  String get shieldStrictTitle => 'Maximum Protection';

  @override
  String get shieldStrictDesc =>
      'Only your saved contacts are allowed to ring.';

  @override
  String get settingContactsOnly => 'Contacts Only Mode';

  @override
  String get settingContactsOnlyDesc => 'Only allow saved contacts to ring';

  @override
  String get searchSuspectNumber => 'Check a suspect number';

  @override
  String get searchSuspectDesc => 'Instantly search the anti-spam database';

  @override
  String get statSpamIntercepted => 'Spam intercepted';

  @override
  String get statNumbersBlocked => 'Blocked numbers';

  @override
  String get recentBlockedSpams => 'Recent Blocked Spams';

  @override
  String get verifyCallAction => 'Check a call';

  @override
  String get calmLineTitle => 'Quiet and secure line';

  @override
  String get calmLineDesc => 'No recent threats detected on your device.';

  @override
  String get badgeBlocked => 'Blocked';

  @override
  String get maskedNumberDefault => 'Masked number';

  @override
  String get dialogCheckNumber => 'Check a number';

  @override
  String get dialogCheckPrompt =>
      'Enter a number to check if it has been reported as spam:';

  @override
  String get btnCancel => 'Cancel';

  @override
  String get btnVerify => 'Check';

  @override
  String get btnUnderstood => 'Got it';

  @override
  String get dialogVerified => 'Verified Number';

  @override
  String get dialogSpamDetected => 'Warning: Spam Detected';

  @override
  String get dialogSafeNumber => 'Safe Number';

  @override
  String get dialogVerifiedDesc =>
      'This number is verified and certified by the administrator.';

  @override
  String get dialogSpamDesc => 'This number has been identified as unwanted.';

  @override
  String get dialogSafeDesc => 'No malicious reports found for this number.';

  @override
  String get activityTitle => 'Phone Activity';

  @override
  String get tabRecentCalls => 'Recent Calls';

  @override
  String get tabBlockedNumbers => 'Blocked Numbers';

  @override
  String get noRecentCalls => 'No recent calls';

  @override
  String get noRecentCallsDesc =>
      'Recent calls will appear here with their security status.';

  @override
  String get noBlockedNumbers => 'No blocked numbers';

  @override
  String get noBlockedNumbersDesc =>
      'All numbers reported or blocked by automatic filter will appear here.';

  @override
  String get noResultsFound => 'No results found';

  @override
  String get tryAnotherSearch => 'Try another search term.';

  @override
  String get searchBlockedPlaceholder => 'Search blocked number...';

  @override
  String get blockAndReport => 'Block & Report';

  @override
  String get reportReason => 'Reason for report:';

  @override
  String get categoryScam => 'Scam';

  @override
  String get categoryTelemarketing => 'Telemarketing';

  @override
  String get categoryPhishing => 'Phishing';

  @override
  String get categoryRobocall => 'Robocall / Silence';

  @override
  String get btnBlockThisNumber => 'Block this number';

  @override
  String get incomingCall => 'Incoming call';

  @override
  String get spamBlocked => 'Spam blocked';

  @override
  String get riskWord => 'risk';

  @override
  String get timeJustNow => 'Just now';

  @override
  String get timeTodayAt => 'Today at';

  @override
  String get timeYesterdayAt => 'Yesterday at';

  @override
  String get unknownCaller => 'Unknown';

  @override
  String get reportSuccessMessage =>
      'Number blocked and reported successfully.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get sectionSecurity => 'SECURITY';

  @override
  String get sectionPreferences => 'PREFERENCES';

  @override
  String get sectionAdmin => 'ADMINISTRATION';

  @override
  String get settingCallFiltering => 'Call filtering';

  @override
  String get settingSmsFiltering => 'SMS filtering';

  @override
  String get settingBgSync => 'Background sync';

  @override
  String get settingUpdateDb => 'Update database';

  @override
  String get btnSync => 'Sync';

  @override
  String get syncSuccess => 'Synchronization successful';

  @override
  String get syncSuccessDetail =>
      'Protection up to date: numbers synchronized.';

  @override
  String get settingTheme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingLanguage => 'Language';

  @override
  String get langFrench => 'Français';

  @override
  String get langEnglish => 'English';

  @override
  String get adminConsoleTitle => 'Admin Console';

  @override
  String get userAccountTitle => 'User Account';

  @override
  String get userAccountSubtitle => 'Sign in or register';

  @override
  String get btnLogout => 'Sign out';

  @override
  String get logoutSuccess => 'Successfully signed out.';

  @override
  String get protectionActive => '100% PROTECTED';

  @override
  String get protectionPartial => 'PARTIAL PROTECTION';

  @override
  String get protectionActiveDescOld =>
      'ShieldNet blocks unwanted calls in real time before ringing.';

  @override
  String get protectionPartialDesc =>
      'Enable native Android filtering to activate full protection.';

  @override
  String get btnEnableNative => 'Enable Native Filtering';

  @override
  String get statLocalDb => 'Local Database';

  @override
  String get statFiltered => 'Filtered numbers';

  @override
  String get statProtectedZone => 'Protected Zone';

  @override
  String get statZoneDesc => '+1 (Canada / US)';

  @override
  String get callLogTitle => 'Call History';

  @override
  String get callLogReportPrompt => 'Report this number?';

  @override
  String get callLogReportDesc =>
      'Do you want to report this number as spam? It will be shared with the community.';

  @override
  String get btnReport => 'Report';

  @override
  String get reportSuccess => 'Report successful!';

  @override
  String get reportLocal => 'Saved locally.';

  @override
  String get emergencyWhitelistTitle => 'Emergency Numbers & Immunity';

  @override
  String get addEmergencyContact => 'Add a Contact';

  @override
  String get addWhitelistTitle => 'Add to Whitelist';

  @override
  String get addWhitelistDesc =>
      'This number will receive full immunity. It will never be blocked or filtered by ShieldNet.';

  @override
  String get labelField => 'Name or Organization';

  @override
  String get labelHint => 'Ex: Hospital, Dr. Smith, School...';

  @override
  String get labelValidator => 'Please enter a label';

  @override
  String get phoneField => 'Phone number';

  @override
  String get phoneHint => 'Ex: +1 819 555 0199 or 8195550199';

  @override
  String get phoneValidatorEmpty => 'Please enter a number';

  @override
  String get phoneValidatorShort => 'Number too short';

  @override
  String get btnSaveImmunity => 'Save with Immunity';

  @override
  String get addSuccess => 'Emergency contact protected successfully.';

  @override
  String get addError => 'Error while saving contact.';

  @override
  String get confirmRemoveTitle => 'Remove from Whitelist?';

  @override
  String get confirmRemoveDesc =>
      'Do you want to remove this contact from emergency whitelist? It will be subject to standard filters again.';

  @override
  String get btnRemove => 'Remove';

  @override
  String get removeSuccess => 'Contact removed from whitelist.';

  @override
  String get zeroFalsePositiveTitle => 'Zero False-Positive Guarantee';

  @override
  String get zeroFalsePositiveDesc =>
      'These priority numbers are never blocked or filtered, even if Strict Shield (Contacts Only) or Night Mode is active.';

  @override
  String get customEmergencyContactsHeader => 'USER PRIORITY CONTACTS';

  @override
  String get emptyCustomContactsTitle => 'No priority contact added';

  @override
  String get emptyCustomContactsDesc =>
      'Add your doctor, hospital, or clinic to ensure their calls always go through.';

  @override
  String get nationalEmergencyServicesHeader =>
      'NATIONAL EMERGENCY SERVICES (CANADA / UNITED STATES)';

  @override
  String get inviolableBadge => 'Inviolable';

  @override
  String get officialShortcut => 'Official shortcut';

  @override
  String get systemProtectionTooltip => 'Non-removable system protection';

  @override
  String get welcomeTitle => 'Welcome to ShieldNet';

  @override
  String get welcomeSubtitle => 'Choose your preferred language:';

  @override
  String get btnSelectLanguage => 'Confirm Language';

  @override
  String get selectLanguagePrompt =>
      'You can change your language anytime in settings.';

  @override
  String get languageFr => 'Français (Canada)';

  @override
  String get languageEn => 'English (US / Canada)';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingContinue => 'Continue';

  @override
  String get onboardingActivate => 'Activate Protection';

  @override
  String get onboardingSlide1Title => 'Anti-Spam Protection';

  @override
  String get onboardingSlide1Sub => 'Total peace of mind every day';

  @override
  String get onboardingSlide1Text =>
      'ShieldNet filters malicious calls and aggressive telemarketing in real time without disrupting your line.';

  @override
  String get onboardingSlide1Feat1 => 'Automatic blocking of known spam';

  @override
  String get onboardingSlide1Feat2 =>
      'Silent background filtering without ringing';

  @override
  String get onboardingSlide1Feat3 => 'Instant lookup of suspicious numbers';

  @override
  String get onboardingSlide2Title => 'Total Privacy';

  @override
  String get onboardingSlide2Sub => 'Your data never leaves your device';

  @override
  String get onboardingSlide2Text =>
      'Your contacts and address book remain strictly on your device. Only suspicious callers are verified without ever exposing your private data.';

  @override
  String get onboardingSlide2Feat1 => '100% local and secure verification';

  @override
  String get onboardingSlide2Feat2 => 'Zero sharing of personal contacts';

  @override
  String get onboardingSlide2Feat3 => 'Absolute respect for your privacy';

  @override
  String get onboardingSlide3Title => 'Ready in 1 Step';

  @override
  String get onboardingSlide3Sub => 'Activate the smart shield';

  @override
  String get onboardingSlide3Text =>
      'Grant the required permissions to allow ShieldNet to intercept spam calls before they ring.';

  @override
  String get onboardingSlide3Feat1 => 'Native call screening role';

  @override
  String get onboardingSlide3Feat2 => 'Proactive SMS phishing detection';

  @override
  String get onboardingSlide3Feat3 => '24/7 active silent protection';

  @override
  String get seniorModeActiveTitle => 'Simplified Mode Active';

  @override
  String get seniorModeActiveDesc =>
      'Enlarged text and buttons. Your phone is protected against fraud.';

  @override
  String get actionCheckNumber => 'Check Number';

  @override
  String get actionCheckNumberSub => 'Anti-spam directory';

  @override
  String get actionSmsInspector => 'SMS Inspector';

  @override
  String get actionSmsInspectorSub => 'Phishing detection';

  @override
  String get nightShieldActiveBadge => 'Night Shield Active';

  @override
  String get copiedNumberDetected => 'Copied number detected';

  @override
  String get serenityOptimal => 'Optimal Protection';

  @override
  String get serenityHigh => 'High Protection';

  @override
  String get serenityPartial => 'Partial Protection';

  @override
  String get serenityVulnerable => 'Vulnerable Device';

  @override
  String get serenityAllBarriers => 'All security barriers are active.';

  @override
  String serenityActionsNeeded(Object count) {
    return '$count recommended action(s) for 100% protection.';
  }

  @override
  String get serenityTipPrefix => 'Tip:';

  @override
  String get serenityImproveScore => 'Improve my score';

  @override
  String get recNativeFilterTitle => 'Enable native call screening';

  @override
  String get recNativeFilterDesc =>
      'Automatically blocks malicious numbers before phone rings.';

  @override
  String get recUpdateDbTitle => 'Update anti-spam database';

  @override
  String get recUpdateDbDesc =>
      'Download latest threat reports to stay protected offline.';

  @override
  String get recAutoBlockTitle => 'Enable automatic blocking';

  @override
  String get recAutoBlockDesc =>
      'Directly rejects verified scams without disturbing you.';

  @override
  String get recBiometricTitle => 'Secure access with biometrics';

  @override
  String get recBiometricDesc =>
      'Protect your whitelist and personal data with fingerprint or face.';

  @override
  String get recContactsOnlyTitle => 'Enable Contacts Only mode';

  @override
  String get recContactsOnlyDesc =>
      'For total protection, only saved contacts can ring your device.';

  @override
  String get citizenImpactTitle => 'Community Reports';

  @override
  String get citizenImpactSub => 'Shared Reports';

  @override
  String citizenProtectedCount(Object count) {
    return '~$count citizens protected';
  }

  @override
  String get citizenReportToProtect =>
      'Report a spam call to protect other users.';

  @override
  String citizenThanksReports(Object count) {
    return 'Thanks to your $count verified report(s).';
  }

  @override
  String get rankInitial => 'Level 1: Initial Report';

  @override
  String get rankSentinel => 'Vigilant Sentinel';

  @override
  String get rankGuardian => 'Citizen Guardian';

  @override
  String get rankPillar => 'Community Pillar';

  @override
  String get regionalRadarTitle => 'Regional Scam Radar';

  @override
  String get regionalRadarDesc =>
      'Real-time analysis of targeted spoofing waves by North American area codes (Canada / US).';

  @override
  String get regionalAlertPrefix => 'Area Code Alert';

  @override
  String regionalWaveDesc(Object region) {
    return 'Active wave of fraudulent calls targeting: $region.';
  }

  @override
  String get regionalReportsCount => 'reports • Type:';

  @override
  String get reportPageTitle => 'Report a Number';

  @override
  String get reportHelpCommunity => 'Help the community';

  @override
  String get reportHelpCommunityDesc =>
      'Report a suspicious number to block it and protect ShieldNet users.';

  @override
  String get reportPhoneLabel => 'Suspicious phone number';

  @override
  String get reportCategoryLabel => 'Nature of nuisance';

  @override
  String get reportCatFraud => 'Fraud / Scam';

  @override
  String get reportCatTelemarketing => 'Telemarketing';

  @override
  String get reportCatFinancialScam => 'Financial Scam';

  @override
  String get reportCatPhishing => 'Phishing';

  @override
  String get reportCatRobocall => 'Automated Call / Robocall';

  @override
  String get reportCommentLabel => 'Comment (Optional)';

  @override
  String get reportCommentHint => 'Describe call context...';

  @override
  String get reportSubmitButton => 'Submit Report';

  @override
  String get reportInvalidPhone =>
      'Please enter a valid phone number (at least 7 digits).';

  @override
  String get reportSuccessToast =>
      'Thank you! Your report was recorded to protect the community.';

  @override
  String get smsInspectorTitle => 'SMS & Link Inspector';

  @override
  String get smsInspectorOfflineTitle => '100% Offline & Private Analysis';

  @override
  String get smsInspectorOfflineDesc =>
      'Your SMS text is never transmitted to any remote server.';

  @override
  String get smsInspectorInputHint =>
      'Paste suspicious SMS text or message here...';

  @override
  String get smsInspectorBtnPaste => 'Paste SMS';

  @override
  String get smsInspectorBtnInspect => 'Inspect';

  @override
  String get smsInspectorClipboardEmpty => 'Clipboard is empty.';

  @override
  String get smsInspectorReset => 'Reset';

  @override
  String get smsRiskAnalysisTitle => 'Risk Analysis:';

  @override
  String get smsThreatDetected => 'Threat Detected';

  @override
  String get smsSuspicious => 'Suspicious Message';

  @override
  String get smsSafe => 'Message Appears Safe';

  @override
  String get smsScoreLabel => 'Risk Score';

  @override
  String get smsIndicatorsLabel => 'Detected indicators';

  @override
  String get smsAdviceLabel => 'Security Advice';

  @override
  String get settingNightShield => 'Night Shield Mode';

  @override
  String get settingNightShieldDesc =>
      'Silent filtering during your sleeping hours';

  @override
  String get settingSmsInspector => 'SMS & Link Inspector';

  @override
  String get settingSmsInspectorDesc =>
      'Analyze suspicious text message or delivery link';

  @override
  String get settingEmergencyWhitelist => 'Emergency Numbers & Whitelist';

  @override
  String get settingEmergencyWhitelistDesc =>
      '911, 988 and guaranteed priority contacts';

  @override
  String get settingSeniorMode => 'Simplified Mode (Seniors)';

  @override
  String get settingSeniorModeDesc =>
      'Enlarges text, increases contrast and simplifies dashboard';

  @override
  String get sectionOfflineResilience => 'OFFLINE & RESILIENCE';

  @override
  String get settingOfflineQueue => 'Offline Queue';

  @override
  String get settingOfflineQueueAllSynced => 'All reports are synchronized';

  @override
  String settingOfflineQueuePending(Object count) {
    return '$count report(s) pending synchronization';
  }

  @override
  String get sectionModeration => 'MANAGEMENT & MODERATION';

  @override
  String get consoleModerationTitle => 'Management & Moderation Console';

  @override
  String get appVersionFooter => 'ShieldNet v1.0.0 • Telecom Security';

  @override
  String auditCompletedSpam(Object count) {
    return 'Audit complete: $count suspect number(s) identified in your call log.';
  }

  @override
  String auditCompletedClean(Object count) {
    return 'Audit complete: Your $count recent calls are clean.';
  }

  @override
  String get auditNetworkError => 'Unable to perform network audit.';

  @override
  String get auditNoVerifiableNumbers =>
      'No verifiable numbers in recent call log.';

  @override
  String get disputeModalTitle => 'False Positive Dispute';

  @override
  String get disputeCallNature => 'Nature of legitimate call:';

  @override
  String get disputeReasonService => 'Business / Service';

  @override
  String get disputeReasonPersonal => 'Personal / Family';

  @override
  String get disputeReasonDelivery => 'Delivery / Package';

  @override
  String get disputeReasonMedical => 'Health / Medical';

  @override
  String get disputeReasonMistake => 'Reporting mistake';

  @override
  String get disputeCommentHint =>
      'Useful details (e.g. my family doctor\'s office)';

  @override
  String get disputeProtectedNumber => 'Protected number';

  @override
  String disputeRiskScore(Object count, Object score) {
    return 'Risk score: $score% ($count report(s))';
  }

  @override
  String get disputeFilteredNotice =>
      'This number is currently filtered by ShieldNet. If this is a doctor, delivery person, or legitimate family member, you can dispute this block to accelerate whitelisting.';

  @override
  String get disputeBtnContest => 'Dispute (False positive)';

  @override
  String get serenitySecurityLevel => 'Security Level';

  @override
  String get serenityRecommendation => 'Recommendation';

  @override
  String get deviceIntegrityRooted => 'System Security: Rooted Device';

  @override
  String get deviceIntegrityDesc =>
      'Superuser access (su / Magisk) detected. Local cryptographic protections may be vulnerable.';

  @override
  String get disputeSuccessToast =>
      'Legitimate report submitted! Community consensus is evaluating reinstatement.';

  @override
  String get disputeErrorToast => 'Unable to record your dispute.';

  @override
  String get disputeSubmitBtn => 'Submit Dispute';

  @override
  String get auditHeaderTitle => 'Call Log Security Audit';

  @override
  String get auditHeaderDesc => 'Scans your last 50 calls via Cloud';

  @override
  String get auditHeaderBtn => 'Scan';

  @override
  String get adminFullAdmin => 'Full Administration';

  @override
  String get adminManagerSpace => 'Manager & Moderation Workspace';

  @override
  String get adminTabOverview => 'Overview';

  @override
  String get adminTabBlacklist => 'Blacklist';

  @override
  String get adminTabReports => 'Reports';

  @override
  String get adminTabUsers => 'Users';

  @override
  String get adminTabAudit => 'Audit & Logs';

  @override
  String get adminAddNumber => 'Add Number';

  @override
  String get adminRefreshAll => 'Refresh all';

  @override
  String get sectionJurisdiction => 'REGION & PRIVACY';

  @override
  String get regionSelectionTitle => 'Your Region';

  @override
  String get regionSelectionSubtitle =>
      'Protection tailored to your area code & territory';

  @override
  String get selectCountryPrompt => '1. SELECT YOUR COUNTRY';

  @override
  String get selectProvincePrompt => '2. SELECT YOUR PROVINCE / TERRITORY';

  @override
  String get selectStatePrompt => '2. SELECT YOUR STATE';

  @override
  String get applyRegionBtn => 'Apply this region';

  @override
  String get onboardingRegionTitle => 'Regional Protection';

  @override
  String get onboardingRegionDesc =>
      'ShieldNet adapts its protection to your territory to block local spam while strictly protecting your emergency services (911, 811, 988) and privacy.';

  @override
  String get helpFaqTitle => 'Help Center & FAQ';

  @override
  String get helpFaqSubtitle =>
      'Frequently asked questions, privacy and documentation';

  @override
  String get openWebHelpBtn => 'Visit Web Help Center';

  @override
  String get webHelpNotice =>
      'Access in-depth documentation, privacy policies, and technical support on our web portal.';

  @override
  String get searchFaqPlaceholder => 'Search a question...';

  @override
  String get faqCategoryFiltering => 'Filtering & Performance';

  @override
  String get faqCategoryPrivacy => 'Privacy & Data Protection';

  @override
  String get faqCategoryEmergency => 'Emergency Numbers & False Positives';

  @override
  String get faqCategoryPermissions => 'Android Permissions';
}
