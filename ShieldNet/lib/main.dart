import 'dart:async';
import 'package:shieldnet/core/utils/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/database/database_helper.dart';
import 'core/providers/app_providers.dart';
import 'core/security/crypto_utils.dart';

import 'features/call_filtering/presentation/pages/dashboard_page.dart';
import 'features/call_filtering/presentation/pages/activity_page.dart';
import 'features/settings/presentation/pages/settings_page.dart';
import 'features/onboarding/presentation/pages/onboarding_page.dart';

import 'core/services/background_sync_service.dart';
import 'core/services/session_timeout_service.dart';

import 'core/widgets/auth_gate.dart';

export 'core/providers/app_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Chargement ultra-rapide des configurations indispensables (< 15ms)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    AppLogger.log("[Main] AVERTISSEMENT : .env ($e).");
  }

  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {}

  final hasSeenOnboarding = prefs?.getBool('has_seen_onboarding') ?? false;

  // Rendu graphique instantané : l'application s'affiche immédiatement
  final sentryDsn = dotenv.isInitialized ? (dotenv.env['SENTRY_DSN'] ?? '').trim() : '';
  if (sentryDsn.isNotEmpty && !sentryDsn.contains('placeholder')) {
    unawaited(
      SentryFlutter.init(
        (options) {
          options.dsn = sentryDsn;
          options.tracesSampleRate = 1.0;
        },
        appRunner: () => runApp(
          ProviderScope(
            child: ShieldNetApp(hasSeenOnboarding: hasSeenOnboarding),
          ),
        ),
      ),
    );
  } else {
    runApp(
      ProviderScope(
        child: ShieldNetApp(hasSeenOnboarding: hasSeenOnboarding),
      ),
    );
  }

  // Initialisation asynchrone non-bloquante des services en arrière-plan
  unawaited(_initBackgroundServices());
}

/// Initialise les services lourds (SQLite, Keystore, WorkManager) en arrière-plan sans bloquer l'affichage
Future<void> _initBackgroundServices() async {
  // 1. Synchronisation sécurisée du sel cryptographique avec le Keystore Android
  try {
    final salt = CryptoUtils.resolveSalt();
    if (salt.isNotEmpty) {
      const MethodChannel('com.shieldnet.security')
          .invokeMethod('setCryptoSalt', {'salt': salt});
    }
  } catch (e) {
    AppLogger.log("[Main] Sel Keystore non synchronisé: $e");
  }

  // 2. Initialisation préventive du cache SQLite local
  try {
    await DatabaseHelper.instance.database;
  } catch (e) {
    AppLogger.log("[Main] Erreur DatabaseHelper init: $e");
  }

  // 3. Worker de synchronisation en tâche de fond (WorkManager)
  try {
    await BackgroundSyncService.instance.initialize();
  } catch (e) {
    AppLogger.log("[Main] BackgroundSync init exception: $e");
  }

  // 4. Initialisation du gestionnaire de temporisation de session
  try {
    await SessionTimeoutService.instance.initialize();
  } catch (e) {
    AppLogger.log("[Main] Erreur init SessionTimeoutService: $e");
  }

  // 5. Synchronisation discrète de la liste noire en arrière-plan
  try {
    final enabled = await BackgroundSyncService.instance.isAutoSyncEnabled();
    if (enabled) {
      final count = await BackgroundSyncService.instance.syncNow();
      AppLogger.log("Synchronisation automatique au démarrage: $count numéros synchronisés.");
    }
  } catch (err) {
    AppLogger.log("Sync au démarrage ignorée (backend hors-ligne ou pas de réseau): $err");
  }
}

class ShieldNetApp extends ConsumerWidget {
  final bool hasSeenOnboarding;
  const ShieldNetApp({super.key, this.hasSeenOnboarding = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final isSeniorMode = ref.watch(seniorModeProvider);

    return MaterialApp(
      title: 'ShieldNet Anti-Spam',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      locale: locale,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        if (isSeniorMode) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: const TextScaler.linear(1.22),
            ),
            child: child,
          );
        }
        return child;
      },
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', ''),
        Locale('en', ''),
      ],
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: hasSeenOnboarding
          ? const AuthGate(child: MainTabNavigationScreen())
          : const OnboardingPage(),
      onUnknownRoute: (settings) {
        AppLogger.log('[Navigation] Route inconnue interceptée: ${settings.name}');
        return MaterialPageRoute(
          builder: (_) => const AuthGate(child: MainTabNavigationScreen()),
        );
      },
    );
  }
}

class MainTabNavigationScreen extends ConsumerStatefulWidget {
  const MainTabNavigationScreen({super.key});

  @override
  ConsumerState<MainTabNavigationScreen> createState() => _MainTabNavigationScreenState();
}

class _MainTabNavigationScreenState extends ConsumerState<MainTabNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardPage(),
    ActivityPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context);
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final protectionLabel = l10n?.tabProtection ?? (isEn ? 'Protection' : 'Protection');
    final activityLabel = l10n?.tabActivity ?? (isEn ? 'Activity' : 'Activité');
    final settingsLabel = l10n?.tabSettings ?? (isEn ? 'Settings' : 'Paramètres');

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        indicatorColor: AppTheme.primaryColor.withValues(alpha: 0.15),
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.shield_outlined),
            selectedIcon: const Icon(Icons.shield, color: AppTheme.primaryColor),
            label: protectionLabel,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history, color: AppTheme.primaryColor),
            label: activityLabel,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings, color: AppTheme.primaryColor),
            label: settingsLabel,
          ),
        ],
      ),
    );
  }
}
