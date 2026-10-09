# ShieldNet — Application Multiplateforme & Natif Android (Flutter & Kotlin)

Application cliente sécurisée de la plateforme **ShieldNet**, conçue pour filtrer les appels indésirables et détecter les messages frauduleux sur Android (avec service natif Kotlin `CallScreeningService`), tout en supportant les environnements multiplateformes (Web, iOS, Windows, macOS, Linux). Elle garantit le respect absolu de la vie privée de l'utilisateur (conformité Loi 25 du Québec, LPRPDE/PIPEDA et TCPA).

L'application prend ses décisions de filtrage directement sur le téléphone. Elle ne transfère jamais le carnet d'adresses vers l'extérieur et ne stocke aucun numéro de téléphone en clair sur les serveurs distants.

---

## 1. Comment fonctionne le filtrage des appels ?

L'interception utilise le service natif Android `CallScreeningService` codé en Kotlin, connecté à une base SQLite locale en mode Write-Ahead Logging (WAL) :

```text
[ Appel Entrant ]
       │
       ▼
[ Gestionnaire d'appels Android ]
       │
       ▼
[ ShieldNetCallScreeningService (Kotlin) ]
       │
       ├── 1. Normalisation du numéro au format international E.164 (+1)
       ├── 2. Calcul de l'empreinte cryptographique HMAC-SHA256 (< 0.2 ms)
       ├── 3. Consultation rapide de la base SQLite locale (< 1.5 ms)
       │
       ▼
[ Décision en moins de 2 ms ]
       ├── Numéro bloqué  ──> Rejet silencieux de l'appel (CallResponse.disallowCall)
       └── Numéro sûr     ──> Sonnerie normale
```

### Pourquoi une décision locale ?

Android exige que le service de filtrage réponde en moins de quelques dizaines de millisecondes. Faire une requête réseau à chaque appel entrant serait trop lent et exposerait la vie privée de l'utilisateur. En stockant la liste des numéros signalés localement dans SQLite, l'application atteint des performances de décision locale inférieures à 2 millisecondes sans dépendre d'une connexion internet active.

---

## 2. Sécurité de Session & Authentification

L'application intègre une politique de sécurité bancaire et de protection de la vie privée à plusieurs niveaux :

### Verrouillage automatique de session (5 minutes)
- **Détection d'absence** : Via `WidgetsBindingObserver` et le service [SessionTimeoutService](file:///c:/Projet/Projet%20synthese/ShieldNet/lib/core/services/session_timeout_service.dart), l'application enregistre chaque mise en arrière-plan (`paused` / `inactive`).
- **Seuil d'inactivité** : Dès que l'utilisateur quitte l'application pendant **plus de 5 minutes** (300 secondes), la session se verrouille automatiquement pour protéger les données confidentielles.
- **Persistance** : L'état d'horodatage est conservé dans `SharedPreferences` pour survivre à la fermeture forcée de l'application par l'OS.

### Déverrouillage biométrique prioritaire & Fallback mot de passe
- **Biométrie native** : L'écran [SessionLockScreen](file:///c:/Projet/Projet%20synthese/ShieldNet/lib/core/widgets/session_lock_screen.dart) déclenche en priorité l'authentification par empreinte digitale ou Face ID via `local_auth`.
- **Fallback mot de passe** : Si la biométrie est annulée, indisponible ou échoue, l'utilisateur peut déverrouiller son compte avec son mot de passe habituel.

### Récupération de mot de passe par code OTP
- **Feuille de récupération [ForgotPasswordSheet](file:///c:/Projet/Projet%20synthese/ShieldNet/lib/core/widgets/forgot_password_sheet.dart)** :
  1. Envoi d'un code OTP à 6 chiffres par courriel sécurisé via l'API ShieldNet.
  2. Saisie du code reçu et définition du nouveau mot de passe.
  3. Validation, mise à jour immédiate et reconnexion automatique avec déverrouillage de la session.

### Authentification Google Sign-In & JWT
- Prise en charge officielle de **Google Sign-In** avec transmission sécurisée du jeton d'authentification ID au backend Django.
- Gestion transparente des jetons d'accès et de rafraîchissement JWT via `flutter_secure_storage`.

---

## 3. Structure du code source

Le code Flutter est organisé selon les principes de la **Clean Architecture**, avec injection de dépendances via **Riverpod** :

```text
ShieldNet/
├── android/
│   ├── app/build.gradle.kts                   # Configuration Android & Gradle 8.13+
│   └── app/src/main/kotlin/.../
│       ├── ShieldNetCallScreeningService.kt   # Service natif d'interception d'appels
│       ├── ShieldNetDatabaseHelper.kt         # Gestionnaire SQLite natif
│       ├── ShieldNetAppWidgetProvider.kt      # Widget d'écran d'accueil
│       └── MainActivity.kt                    # Pont Flutter <-> Android
│
├── lib/
│   ├── core/
│   │   ├── database/                          # SQLite local, requêtes WAL & migrations
│   │   ├── network/                           # Client HTTP Dio, fallbacks d'URL & certificate pinning
│   │   ├── providers/                         # Notifiers Riverpod (auth, thème, langue, région)
│   │   ├── security/                          # Hachage HMAC-SHA256 & crypto-utils
│   │   ├── services/                          # Biométrie, session timeout & sync d'arrière-plan
│   │   ├── theme/                             # Thème sombre, clair et Design System
│   │   └── widgets/                           # AuthGate, SessionLockScreen, ForgotPasswordSheet, logos
│   │
│   ├── features/
│   │   ├── call_filtering/                    # Dashboard, radar de protection, historique et signalements
│   │   ├── onboarding/                        # Écrans de bienvenue et configuration initiale
│   │   ├── settings/                          # Préférences, langue, mode Senior et console d'administration
│   │   └── sms_inspector/                     # Analyseur heuristique de SMS frauduleux
│   │
│   ├── l10n/                                  # Traductions bilingues ARB (français et anglais)
│   └── main.dart                              # Point d'entrée de l'application
│
└── test/                                      # 52 tests automatisés (100% de réussite)
    ├── services/                              # Tests auth, api et session timeout
    └── unit/                                  # Tests IA prédictive, crypto et filtrage d'appels
```

---

## 4. Fonctionnalités clés

- **Filtrage silencieux et automatique** : Bloque les numéros indésirables avant la première sonnerie.
- **Immunité totale des urgences** : Les services d'urgence (911, 811, 988, etc.) et les favoris ne sont jamais bloqués.
- **Fonctionnement hors-ligne d'abord (Offline-First)** : Le filtrage fonctionne sans connexion. Les signalements hors-ligne sont synchronisés dès le retour du réseau.
- **Contestation citoyenne** : Permet de certifier un faux positif comme légitime directement depuis l'historique d'appels.
- **Vérification unitaire et prédiction IA** : Diagnostic heuristique et analyse par intelligence artificielle des indicatifs et schémas d'usurpation (Neighbor Spoofing).
- **Inspecteur de SMS frauduleux** : Analyse locale des messages suspects (faux colis, faux virements bancaires).
- **Mode Senior** : Grossissement ergonomique du texte (`TextScaler 1.22x`) activable dans les paramètres.
- **Conformité régionale** : Paramétrage adapté selon la juridiction (Loi 25 du Québec, LPRPDE Canada, TCPA USA).
- **Prise en charge bilingue complète** : Interface entièrement traduite en français et en anglais.

---

## 5. Démarrage et configuration

### Configuration (`.env`)

À la racine du dossier `ShieldNet/`, configurez le fichier `.env` (inspiré de `.env.example`) :

```env
# Mode 1 : Téléphone physique USB (avec adb reverse tcp:8000 tcp:8000) ou Desktop/Web
API_BASE_URL=http://127.0.0.1:8000/api/v1

# Mode 2 : Émulateur Android Studio
# API_BASE_URL=http://10.0.2.2:8000/api/v1

API_KEY=dev-local-api-key-test-do-not-use-in-prod
HASH_SALT=dev-local-hash-salt-test-do-not-use-in-prod
```

### Commandes usuelles

```powershell
# Installer les dépendances
flutter pub get

# Générer les fichiers de langues
flutter gen-l10n

# Lancer la suite de 52 tests automatisés
flutter test

# Vérifier l'analyse statique du code (0 avertissement)
flutter analyze

# Lancer l'application sur émulateur ou téléphone
flutter run
```
