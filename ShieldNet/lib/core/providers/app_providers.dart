import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../network/api_service.dart';
import '../services/call_screening_service.dart';
import '../services/background_sync_service.dart';
import '../services/citizen_impact_service.dart';
import '../services/offline_sync_service.dart';
import '../services/home_widget_sync_service.dart';
import '../security/device_integrity_checker.dart';
import '../security/bloom_filter_client.dart';
import '../models/regional_threat.dart';
export 'auth_provider.dart';

/// Notifier pour le mode de thème (Clair / Sombre / Système) avec persistance SharedPreferences
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString('settings_theme_mode');
      if (modeStr != null) {
        state = ThemeMode.values.firstWhere(
          (m) => m.name == modeStr,
          orElse: () => ThemeMode.system,
        );
      }
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('settings_theme_mode', mode.name);
    } catch (_) {}
  }
}

/// Provider pour le mode de thème (Clair / Sombre / Système)
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

/// Notifier pour la langue de l'application (Français par défaut ou Anglais)
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('fr')) {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString('settings_language') ?? 'fr';
      state = Locale(code);
    } catch (_) {}
  }

  Future<void> setLocale(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('settings_language', languageCode);
      state = Locale(languageCode);
    } catch (_) {}
  }
}

/// Provider pour la langue de l'application
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

/// Provider unique pour le client API ShieldNet
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

/// Provider pour le service natif de filtrage d'appels
final callScreeningServiceProvider = Provider<CallScreeningService>((ref) => CallScreeningService());

/// Notifier pour l'état d'activation de la protection native Android
class ProtectionNotifier extends StateNotifier<AsyncValue<bool>> {
  final CallScreeningService _screeningService;

  ProtectionNotifier(this._screeningService) : super(const AsyncValue.data(true)) {
    checkStatus();
  }

  Future<void> checkStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userAutoBlock = prefs.getBool('settings_auto_block') ?? true;
      final userSms = prefs.getBool('settings_sms_analysis') ?? true;
      final nativeActive = await _screeningService.isCallScreeningActive();
      final phoneGranted = await Permission.phone.isGranted;

      // La protection sur l'accueil est active si les autorisations sont accordées
      // et que les fonctionnalités de filtrage (appels et SMS) sont activées.
      final isProtected = (nativeActive || phoneGranted) && userAutoBlock && userSms;
      state = AsyncValue.data(isProtected);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> requestPermission() async {
    state = const AsyncValue.loading();
    try {
      // Permission système standard pour l'état d'appel (READ_PHONE_STATE)
      final phoneStatus = await Permission.phone.request();

      // Dialogue système Android Telecom pour accorder le rôle ROLE_CALL_SCREENING
      final roleGranted = await _screeningService.requestCallScreeningRole();

      // Active les protections associées dans les préférences de l'application
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('settings_auto_block', true);
      await prefs.setBool('settings_sms_analysis', true);

      final isNowActive = roleGranted || phoneStatus.isGranted;
      state = AsyncValue.data(isNowActive);
      return isNowActive;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> updateAutoBlock(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_auto_block', enabled);
    await checkStatus();
  }

  Future<void> updateSmsAnalysis(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_sms_analysis', enabled);
    await checkStatus();
  }

  Future<void> disableProtection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_auto_block', false);
    await prefs.setBool('settings_sms_analysis', false);
    state = const AsyncValue.data(false);
  }

  Future<void> toggleProtection() async {
    final current = state.value ?? false;
    if (current) {
      await disableProtection();
    } else {
      await requestPermission();
    }
  }
}

/// Provider pour observer le statut de protection globale
final protectionStatusProvider = StateNotifierProvider<ProtectionNotifier, AsyncValue<bool>>((ref) {
  return ProtectionNotifier(ref.watch(callScreeningServiceProvider));
});

/// Notifier pour le mode Contacts Uniquement (VIP Allowlist)
class ContactsOnlyNotifier extends StateNotifier<bool> {
  final CallScreeningService _service;

  ContactsOnlyNotifier(this._service) : super(false) {
    _loadState();
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool('settings_contacts_only') ?? false;
    } catch (_) {}
  }

  Future<bool> toggle(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('settings_contacts_only', enabled);
      await _service.setContactsOnlyMode(enabled);
      state = enabled;
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Provider d'état pour le mode Contacts Uniquement
final contactsOnlyProvider = StateNotifierProvider<ContactsOnlyNotifier, bool>((ref) {
  return ContactsOnlyNotifier(ref.watch(callScreeningServiceProvider));
});

/// État réactif des réglages de sécurité et de filtrage
class AppSettingsState {
  final bool autoBlock;
  final bool smsAnalysis;
  final bool autoSync;
  final bool seniorMode;

  const AppSettingsState({
    this.autoBlock = true,
    this.smsAnalysis = true,
    this.autoSync = true,
    this.seniorMode = false,
  });

  AppSettingsState copyWith({
    bool? autoBlock,
    bool? smsAnalysis,
    bool? autoSync,
    bool? seniorMode,
  }) {
    return AppSettingsState(
      autoBlock: autoBlock ?? this.autoBlock,
      smsAnalysis: smsAnalysis ?? this.smsAnalysis,
      autoSync: autoSync ?? this.autoSync,
      seniorMode: seniorMode ?? this.seniorMode,
    );
  }
}

/// Notifier pour centraliser et persister les préférences de filtrage
class AppSettingsNotifier extends StateNotifier<AppSettingsState> {
  final Ref _ref;

  AppSettingsNotifier(this._ref) : super(const AppSettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final autoBlock = prefs.getBool('settings_auto_block') ?? true;
      final sms = prefs.getBool('settings_sms_analysis') ?? true;
      final autoSync = await BackgroundSyncService.instance.isAutoSyncEnabled();
      final senior = prefs.getBool('settings_senior_mode') ?? false;
      state = AppSettingsState(
        autoBlock: autoBlock,
        smsAnalysis: sms,
        autoSync: autoSync,
        seniorMode: senior,
      );
    } catch (_) {}
  }

  Future<void> setAutoBlock(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_auto_block', enabled);
    state = state.copyWith(autoBlock: enabled);
    await _ref.read(protectionStatusProvider.notifier).checkStatus();
  }

  Future<void> setSmsAnalysis(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_sms_analysis', enabled);
    state = state.copyWith(smsAnalysis: enabled);
    await _ref.read(protectionStatusProvider.notifier).checkStatus();
  }

  Future<void> setAutoSync(bool enabled) async {
    await BackgroundSyncService.instance.setAutoSyncEnabled(enabled);
    state = state.copyWith(autoSync: enabled);
  }

  Future<void> setSeniorMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_senior_mode', enabled);
    state = state.copyWith(seniorMode: enabled);
  }
}

/// Provider pour les réglages globaux de sécurité
final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettingsState>((ref) {
  return AppSettingsNotifier(ref);
});

/// Provider pour le mode simplifié seniors / aînés réactif
final seniorModeProvider = Provider<bool>((ref) {
  return ref.watch(appSettingsProvider).seniorMode;
});

/// Notifier pour l'activation de la synchronisation automatique en arrière-plan
class AutoSyncNotifier extends StateNotifier<bool> {
  AutoSyncNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    try {
      final enabled = await BackgroundSyncService.instance.isAutoSyncEnabled();
      state = enabled;
    } catch (_) {}
  }

  Future<void> toggle(bool enabled) async {
    try {
      await BackgroundSyncService.instance.setAutoSyncEnabled(enabled);
      state = enabled;
    } catch (_) {}
  }
}

/// Provider pour le statut de synchronisation automatique
final autoSyncProvider = StateNotifierProvider<AutoSyncNotifier, bool>((ref) {
  return AutoSyncNotifier();
});

/// Provider pour le service de synchronisation hors-ligne
final offlineSyncServiceProvider = Provider<OfflineSyncService>((ref) {
  return OfflineSyncService.instance;
});

/// Provider pour observer le nombre d'éléments en attente dans la file d'attente hors-ligne
final offlineQueueCountProvider = FutureProvider.autoDispose<int>((ref) async {
  return await OfflineSyncService.instance.getPendingCount();
});

/// Provider pour les statistiques d'impact citoyen
final citizenImpactProvider = FutureProvider.autoDispose.family<CitizenImpactData, int>((ref, localBlockedCount) async {
  return CitizenImpactService.getImpactData(localBlockedSpams: localBlockedCount);
});

/// Provider pour l'intégrité de l'appareil (Root / Jailbreak detection)
final deviceIntegrityProvider = FutureProvider.autoDispose<DeviceIntegrityResult>((ref) async {
  return await DeviceIntegrityChecker.checkIntegrity();
});

/// Provider pour les données publiées au widget d'accueil Android
final homeWidgetDataProvider = FutureProvider.autoDispose<HomeWidgetData>((ref) async {
  return await HomeWidgetSyncService.getWidgetData();
});

/// Provider pour les alertes et menaces téléphoniques régionales
final regionalThreatsProvider = FutureProvider.autoDispose<RegionalThreatSummary?>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getRegionalThreats();
});

/// Notifier pour le filtre de Bloom en mémoire vive (évaluation probabiliste O(1))
class BloomFilterNotifier extends StateNotifier<BloomFilterClient?> {
  final ApiService _api;

  BloomFilterNotifier(this._api) : super(null) {
    _load();
  }

  Future<void> _load() async {
    try {
      final filter = await _api.downloadBloomFilter();
      if (filter != null) {
        state = filter;
      }
    } catch (_) {}
  }

  Future<void> refresh() async {
    try {
      final filter = await _api.downloadBloomFilter();
      if (filter != null) {
        state = filter;
      }
    } catch (_) {}
  }
}

/// Provider pour le filtre de Bloom en mémoire vive
final bloomFilterProvider = StateNotifierProvider<BloomFilterNotifier, BloomFilterClient?>((ref) {
  final api = ref.watch(apiServiceProvider);
  return BloomFilterNotifier(api);
});

