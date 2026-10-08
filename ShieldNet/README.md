# ShieldNet — Application Multiplateforme & Natif Android (Flutter & Kotlin)

Application cliente de la plateforme ShieldNet, conçue pour filtrer les appels indésirables et détecter les messages frauduleux sur Android (avec service natif Kotlin `CallScreeningService`), tout en supportant les environnements multiplateformes (Web, iOS, Windows, macOS, Linux). Elle garantit le respect total de la vie privée de l'utilisateur (conformité Loi 25 et LPRPDE).

L'application prend ses décisions de filtrage directement sur le téléphone. Elle ne transfère jamais le carnet d'adresses vers l'extérieur et ne stocke aucun numéro de téléphone en clair sur les serveurs distants.

---

## 1. Comment fonctionne le filtrage des appels ?

L'interception utilise le service natif Android `CallScreeningService` codé en Kotlin, connecté à une base SQLite locale :

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

Android exige que le service de filtrage réponde en moins de quelques dizaines de millisecondes. Faire une requête réseau à chaque appel entrant serait trop lent et exposerait la vie privée de l'utilisateur. En stockant la liste des numéros signalés localement dans SQLite (mode *Write-Ahead Logging*), l'application vise des performances de décision locale inférieures à 2 millisecondes (objectifs mesurés sur matériel Android de référence) sans dépendre d'une connexion internet active.

---

## 2. Structure du code source

Le code Flutter est organisé selon les principes de la *Clean Architecture*, avec injection de dépendances via **Riverpod** :

```text
ShieldNet/
├── android/
│   └── app/src/main/kotlin/.../
│       ├── ShieldNetCallScreeningService.kt   # Service d'interception d'appels
│       ├── ShieldNetDatabaseHelper.kt         # Gestionnaire de base SQLite natif
│       ├── ShieldNetAppWidgetProvider.kt      # Widget pour l'écran d'accueil
│       └── MainActivity.kt                    # Communication Flutter <-> Android
│
├── lib/
│   ├── core/
│   │   ├── database/           # SQLite local et migrations
│   │   ├── network/            # Client HTTP Dio et gestion des erreurs réseau
│   │   ├── providers/          # États globaux et logique d'authentification
│   │   ├── security/           # Fonctions de hachage et normalisation des numéros
│   │   ├── services/           # Synchronisation et gestion hors-ligne
│   │   └── theme/              # Thèmes clair et sombre
│   │
│   ├── features/
│   │   ├── call_filtering/     # Écrans d'accueil, historique des appels et signalements
│   │   ├── onboarding/         # Écrans de bienvenue et explications initiales
│   │   ├── settings/           # Préférences, choix de langue et accès administrateur
│   │   └── sms_inspector/      # Analyseur de SMS suspects
│   │
│   ├── l10n/                   # Traductions bilingues (français et anglais)
│   └── main.dart               # Point d'entrée de l'application
│
└── test/                       # 35 tests automatisés (unitaires et intégration)
```

---

## 3. Fonctionnalités clés

- **Filtrage silencieux et automatique** : Bloque les numéros identifiés comme malveillants avant la première sonnerie.
- **Immunité totale des urgences** : Les services d'urgence (911, 811, 988, etc.) et les contacts favoris ne sont jamais bloqués, quelles que soient les règles de filtrage.
- **Fonctionnement hors-ligne** : Le filtrage fonctionne même sans réseau. Les signalements effectués sans connexion sont mis en attente et envoyés dès que le réseau redevient disponible.
- **Contestation citoyenne** : Si un numéro légitime est bloqué par erreur (faux positif), l'utilisateur peut le certifier comme légitime directement depuis l'historique d'appels.
- **Vérification rapide de numéro** : Permet de tester manuellement un numéro douteux pour obtenir une évaluation claire et compréhensible.
- **Détecteur de SMS frauduleux** : Analyse les messages suspects localement pour détecter les arnaques aux faux colis ou faux virements, sans envoyer le texte du SMS sur un serveur.
- **Prise en charge bilingue complète** : Interface entièrement traduite en français et en anglais.

---

## 4. Démarrage et configuration

### Configuration (`.env`)

À la racine du dossier `ShieldNet/`, configurez le fichier `.env` :

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

# Lancer la suite de 35 tests automatisés
flutter test

# Vérifier l'analyse statique du code
flutter analyze

# Lancer l'application sur émulateur ou téléphone
flutter run
```
