# Architecture logicielle et conception — ShieldNet

Ce document détaille l'architecture globale, la modélisation des composants et les flux de données du projet **ShieldNet**. Il présente les choix d'ingénierie retenus pour concilier réactivité en temps réel sur mobile, fonctionnement hors-ligne (*offline-first*) et protection rigoureuse de la vie privée.

---

## 1. Principes d'architecture et séparation des responsabilités

Le système ShieldNet est articulé autour de trois environnements complémentaires :

1. **L'application mobile (Flutter / Dart)** : Fournit l'interface utilisateur réactive, la gestion d'état avec Riverpod et les appels réseau avec Dio en gérant le cache et les erreurs hors-ligne.
2. **Le module natif Android (Kotlin)** : Implémente le `CallScreeningService` du système d'exploitation pour intercepter les appels entrants en temps réel, avec une contrainte de réponse rapide (< 100 ms).
3. **Le backend (Django / Python)** : Propose une API REST, la gestion des comptes et permissions (RBAC), le moteur de réputation collaborative et un journal d'audit pour les actions administratives.

Afin de faciliter la maintenance et d'éviter un couplage fort avec les bibliothèques externes, le code Flutter suit les principes de la **Clean Architecture** :

```mermaid
graph TD
    subgraph Presentation_Layer ["Couche Présentation (lib/features/*/presentation)"]
        UI_Pages["Pages (Dashboard, Settings, SmsInspector, AdminConsole)"]
        UI_Widgets["Composants graphiques réutilisables"]
        Controllers["Contrôleurs d'état (Riverpod Notifiers)"]
    end

    subgraph Domain_Layer ["Couche Domaine (lib/features/*/domain) - Dart pur"]
        UseCases["Cas d'utilisation (AnalyzeSmsUseCase, CheckNumberUseCase)"]
        Entities["Entités métier (AdminStats, AuditLogEntry, PhishingResult)"]
        RepoInterfaces["Interfaces de dépôts (AdminRepository, BlacklistRepository)"]
    end

    subgraph Data_Layer ["Couche Données (lib/features/*/data)"]
        RepoImpl["Implémentations (AdminRepositoryImpl, BlacklistRepositoryImpl)"]
        DataSources["Sources de données (ApiService, DatabaseHelper)"]
        DTOs["Modèles de transfert de données (BlacklistedNumber)"]
    end

    subgraph Core_Layer ["Socle transverse (lib/core)"]
        Crypto["Cryptographie (HMAC-SHA256, normalisation E.164)"]
        Network["Client HTTP (Dio, gestion des erreurs et intercepteurs)"]
        Database["Base de données locale SQLite (DatabaseHelper en mode WAL)"]
        Services["Services d'arrière-plan et synchronisation"]
    end

    subgraph Native_Android ["Module natif Android (android/app/src/main/kotlin)"]
        CallScreening["ShieldNetCallScreeningService (Interception système)"]
        NativeDB["ShieldNetDatabaseHelper (Lecture directe SQLite)"]
    end

    subgraph Backend_Django ["Serveur Backend (Django REST Framework)"]
        DjangoAPI["API REST (/api/v1/sync/delta, /check, /reports)"]
        DjangoDB["Base de données PostgreSQL / SQLite"]
    end

    UI_Widgets --> UI_Pages
    UI_Pages --> Controllers
    Controllers --> UseCases
    UseCases --> RepoInterfaces
    UseCases --> Entities
    RepoImpl -.-> RepoInterfaces
    RepoImpl --> DataSources
    DataSources --> Core_Layer
    Core_Layer -. Partage SQLite .-> Native_Android
    DataSources -. Requêtes HTTPS (HMAC) .-> Backend_Django
```

### Avantages de ce découpage
- **Indépendance des règles métier** : Le calcul du score de risque, l'analyse heuristique des SMS et les logiques de décision ne dépendent d'aucun framework graphique.
- **Facilité des tests** : Les interfaces permettent d'injecter facilement des mocks lors des tests automatisés (35 tests côté Flutter et 74 tests côté Django, soit 109 tests au total).

---

## 2. Diagramme de composants du système

L'application a été conçue selon une approche *offline-first*. Même en l'absence de réseau mobile ou Wi-Fi, le filtrage téléphonique reste 100 % opérationnel grâce à la base de données locale synchronisée.

```mermaid
flowchart TD
    subgraph Mobile ["Téléphone Android (Utilisateur)"]
        Telecom["Système Téléphonie Android (Telecom)"]
        
        subgraph Native_Kotlin ["Module Natif Kotlin"]
            ScreenService["ShieldNetCallScreeningService"]
            NativeDB["Accès SQLite Natif"]
        end
        
        LocalDB[("Base locale (shieldnet.db en WAL)")]
        
        subgraph App_Flutter ["Application Mobile Flutter"]
            UI["Interface Utilisateur"]
            StateMgr["Gestion d'état Riverpod"]
            CryptoEngine["Module HMAC-SHA256"]
            OfflineQueue["Service de synchronisation"]
        end
    end

    subgraph Backend ["Serveur Backend ShieldNet"]
        subgraph Django ["API Django REST"]
            AuthAPI["Authentification & Permissions RBAC"]
            DeltaAPI["Synchronisation différentielle"]
            ConsensusAPI["Gestion du consensus communautaire"]
            AuditAPI["Journal d'audit administratif"]
            RepEngine["Moteur de réputation"]
        end
        CentralDB[("Base de données centrale")]
    end

    Telecom -->|Appel entrant détecté| ScreenService
    ScreenService -->|Vérification empreinte < 2 ms| NativeDB
    NativeDB -->|Lecture indexée B-Tree| LocalDB
    LocalDB  -->|Mise à jour SQLite| StateMgr
    
    UI -->|Action utilisateur| StateMgr
    StateMgr -->|Hachage normalisé| CryptoEngine
    OfflineQueue -->|GET /sync/delta| DeltaAPI
    DeltaAPI -->|Lecture deltas| CentralDB
    ConsensusAPI -->|Seuil de signalements| CentralDB
    AuditAPI -->|Traçabilité| CentralDB
    RepEngine -->|Calcul du score| CentralDB
```

---

## 3. Diagramme de classes UML (Client mobile)

Voici l'organisation des classes et interfaces principales du client Flutter :

```mermaid
classDiagram
    %% Couche Domaine
    class AdminRepository {
        <<interface>>
        +getStats() Future~AdminStats~
        +getAuditLogs(page, limit) Future~List~AuditLogEntry~~
        +purgeInactiveEntries(days) Future~int~
        +runConsensusAudit() Future~Map~String, dynamic~~
    }

    class AdminStats {
        +int totalBlacklisted
        +int verifiedSpam
        +int activeCommunityReports
        +int totalProtectedUsers
        +DateTime lastSyncTimestamp
        +fromMap(Map) AdminStats
    }

    class AuditLogEntry {
        +String id
        +String action
        +String performedBy
        +DateTime timestamp
        +String details
        +String ipAddress
        +fromMap(Map) AuditLogEntry
    }

    class AnalyzeSmsUseCase {
        -SmsPhishingDetector _detector
        +call(String text) PhishingResult
        +extractUrls(String text) List~String~
    }

    class PhishingResult {
        +bool isSuspicious
        +double riskScore
        +List~String~ detectedKeywords
        +List~String~ suspiciousUrls
        +String recommendation
    }

    %% Couche Données
    class AdminRepositoryImpl {
        -ApiService _apiService
        +getStats() Future~AdminStats~
        +getAuditLogs(page, limit) Future~List~AuditLogEntry~~
        +purgeInactiveEntries(days) Future~int~
        +runConsensusAudit() Future~Map~String, dynamic~~
    }

    %% Socle Technique
    class ApiService {
        -Dio _dio
        -DatabaseHelper _dbHelper
        +syncBlacklistWithBackend(delta: bool) Future~int~
        +reportSpamNumber(hash, reason) Future~bool~
        +submitSafeReport(hash, category, notes) Future~bool~
        +checkNumbersBatch(hashes) Future~Map~String, dynamic~~
        +checkNumberReputation(hash) Future~Map~
    }

    class DatabaseHelper {
        <<singleton>>
        -Database _database
        +instance DatabaseHelper
        +insertBlacklistBatch(List) Future~int~
        +isNumberBlocked(hash) Future~bool~
        +isEmergencyNumber(number) Future~bool~
        +getAllEmergencyContacts() Future~List~
    }

    class CryptoUtils {
        <<utilitaire>>
        +normalizePhoneNumber(raw) String
        +computeHmacSha256(phone, salt) String
        +maskPhoneNumber(phone) String
    }

    %% Composants Android Natifs
    class ShieldNetCallScreeningService {
        +onScreenCall(CallDetails) void
        -evaluateIncomingCall(number) CallResponse
    }

    class ShieldNetDatabaseHelper {
        +isNumberBlocked(hash) Boolean
        +isEmergencyNumber(rawNumber) Boolean
    }

    %% Relations
    AdminRepository <|.. AdminRepositoryImpl : implémente
    AdminRepositoryImpl --> ApiService : utilise
    AdminRepository --> AdminStats : renvoie
    AdminRepository --> AuditLogEntry : renvoie
    AnalyzeSmsUseCase --> PhishingResult : renvoie
    ApiService --> DatabaseHelper : synchronise
    ApiService --> CryptoUtils : calcule les empreintes
    ShieldNetCallScreeningService --> ShieldNetDatabaseHelper : consulte
    ShieldNetDatabaseHelper ..> DatabaseHelper : partage shieldnet.db
```

---

## 4. Application pratique des principes SOLID

La structure du code s'appuie sur les principes de conception orientée objet :

| Principe | Application concrète dans ShieldNet |
|---|---|
| **Responsabilité unique (SRP)** | Chaque classe a une tâche bien délimitée. Par exemple, `CryptoUtils` s'occupe exclusivement de la normalisation et du hachage, tandis que `AnalyzeSmsUseCase` gère l'évaluation de texte sans se soucier de l'affichage. |
| **Ouvert / Fermé (OCP)** | Les règles d'évaluation peuvent être étendues (ajout de nouveaux critères, filtres par indicatif, etc.) sans altérer la logique centrale de stockage ou de présentation. |
| **Substitution de Liskov (LSP)** | Les implémentations de dépôts (`AdminRepositoryImpl`) respectent strictement les contrats d'interface, ce qui permet de les remplacer par des simulacres (*mocks*) dans les tests sans surprise. |
| **Ségrégation des interfaces (ISP)** | Les interfaces sont divisées par fonctionnalités (administration, vérification de numéros, analyse SMS) pour éviter que les composants ne dépendent de méthodes superflues. |
| **Inversion des dépendances (DIP)** | Les contrôleurs d'affichage dépendent d'abstractions de cas d'utilisation injectées par Riverpod, plutôt que d'instancier directement des classes de bas niveau (comme les clients HTTP). |

---

## 5. Flux fonctionnels clés

### 5.1. Interception d'un appel entrant en temps réel (< 2 ms)
Lorsqu'un appel arrive, le système Android transmet le numéro au service d'interception. La priorité absolue est donnée à la non-interférence avec les numéros d'urgence :

```mermaid
sequenceDiagram
    autonumber
    actor Appelant as Appelant
    participant AndroidOS as Téléphonie Android
    participant NativeService as ShieldNetCallScreeningService (Kotlin)
    participant NativeDB as Base SQLite locale (shieldnet.db)
    actor Utilisateur as Destinataire

    Appelant->>AndroidOS: Appel entrant (+1 514-555-0199)
    AndroidOS->>NativeService: onScreenCall(callDetails)
    
    %% Contrôle de priorité absolue : urgences
    Note over NativeService,NativeDB: Vérification immédiate d'immunité (911, 811, 988, contacts favoris)
    NativeService->>NativeDB: isEmergencyNumber(rawNumber)
    alt Numéro d'urgence ou contact prioritaire
        NativeDB-->>NativeService: Oui
        NativeService->>AndroidOS: respondToCall(ALLOW)
        AndroidOS->>Utilisateur: Sonnerie normale prioritaire
    else Numéro ordinaire
        NativeDB-->>NativeService: Non
        
        %% Hachage et consultation de la liste
        Note over NativeService: Normalisation E.164 + HMAC-SHA256 (< 0.2 ms)
        NativeService->>NativeDB: isNumberBlocked(phoneHash)
        
        alt Numéro présent dans la liste de blocage
            NativeDB-->>NativeService: Oui (numéro indésirable)
            NativeService->>AndroidOS: respondToCall(DISALLOW, rejet silencieux)
            Note over AndroidOS: Appel bloqué sans faire sonner le téléphone (< 2 ms)
            NativeService->>NativeDB: logBlockedCallEvent(phoneHash, date)
        else Numéro absent de la liste
            NativeDB-->>NativeService: Non
            
            alt Mode "Contacts uniquement" activé et numéro inconnu
                NativeService->>AndroidOS: respondToCall(SILENCE, renvoi messagerie)
            else Mode normal
                NativeService->>AndroidOS: respondToCall(ALLOW)
                AndroidOS->>Utilisateur: Sonnerie normale
            end
        end
    end
```

---

### 5.2. Synchronisation incrémentale (Delta Sync)
Pour économiser la bande passante mobile et la batterie, le client ne télécharge pas l'ensemble de la base à chaque fois. Il demande uniquement les changements intervenus depuis sa dernière version connue :

```mermaid
sequenceDiagram
    autonumber
    participant Scheduler as Tâche d'arrière-plan (WorkManager)
    participant SyncService as BackgroundSyncService
    participant ApiService as Client HTTP Dio
    participant DjangoAPI as API Backend (/api/v1/sync/delta)
    participant LocalDB as Base SQLite locale

    Scheduler->>SyncService: Déclenchement planifié
    SyncService->>LocalDB: Récupération de la version locale (sync_version)
    LocalDB-->>SyncService: version = 142
    
    SyncService->>ApiService: syncDelta(since_version: 142)
    ApiService->>DjangoAPI: GET /api/v1/sync/delta?since_version=142
    DjangoAPI-->>ApiService: 200 OK { new_version: 145, active: [h1, h2], removed: [h3] }
    
    Note over ApiService,LocalDB: Transaction SQLite locale
    ApiService->>LocalDB: Début de transaction
    ApiService->>LocalDB: Ajout ou mise à jour des numéros (h1, h2)
    ApiService->>LocalDB: Suppression des numéros réhabilités (h3)
    ApiService->>LocalDB: Enregistrement nouvelle version = 145
    ApiService->>LocalDB: Validation de transaction (commit)
    
    ApiService-->>SyncService: Synchronisation réussie (+2 ajoutés, -1 retiré)
    SyncService-->>Scheduler: Fin de la tâche
```

---

### 5.3. Analyse de SMS dans l'inspecteur
L'utilisateur peut coller un message douteux pour obtenir une évaluation immédiate. Le texte reste analysé localement sur le terminal, préservant la confidentialité des correspondances privées :

```mermaid
sequenceDiagram
    autonumber
    actor Utilisateur as Utilisateur
    participant UI as Page SmsInspector
    participant UseCase as AnalyzeSmsUseCase
    participant Detector as SmsPhishingDetector (Heuristique)
    participant ApiService as Client HTTP
    participant Backend as API Django

    Utilisateur->>UI: Coller le SMS et lancer l'analyse
    UI->>UseCase: call(smsText)
    
    UseCase->>Detector: analyzeText(smsText)
    Note over Detector: Recherche de motifs (urgence financière, faux colis, usurpation)
    Detector-->>UseCase: Résultat local (score de risque, URL détectée)
    
    opt Si une URL est présente dans le texte et le réseau disponible
        UseCase->>ApiService: checkUrlReputation(url)
        ApiService->>Backend: POST /api/v1/check-url/
        Backend-->>ApiService: { is_malicious: true, category: "PHISHING" }
        ApiService-->>UseCase: Confirmation de menace
    end
    
    UseCase-->>UI: Synthèse finale (niveau de risque, indicateurs et conseils)
    UI->>Utilisateur: Affichage du rapport clair
```

---

### 5.4. Signalement participatif et modération par consensus
Le modèle collaboratif permet aux utilisateurs de signaler les numéros indésirables, tout en prévenant les abus grâce à un seuil de consensus :

```mermaid
sequenceDiagram
    autonumber
    actor Utilisateur as Utilisateur
    participant App as Application ShieldNet
    participant Crypto as Module HMAC-SHA256
    participant Backend as API Django (/api/v1/reports/)
    participant Consensus as Moteur de consensus
    participant Admin as Interface de modération

    Utilisateur->>App: Signalement de spam ou contestation légitime
    App->>Crypto: Calcul de l'empreinte normalisée avec sel
    Crypto-->>App: Hash HMAC-SHA256 (aucun numéro transmis en clair)
    
    alt Cas d'un signalement de spam
        App->>Backend: POST /api/v1/reports/ { phone_hash: h, category: "FRAUD" }
        Backend-->>App: Signalement enregistré
        
        Consensus->>Consensus: Vérification du seuil (utilisateurs distincts)
        alt Seuil atteint (>= 3 signalements indépendants)
            Consensus->>Backend: Ajout en liste de blocage et traçabilité dans l'AuditLog
        else Seuil non atteint
            Consensus->>Backend: Conservation en surveillance
        end
    else Cas d'une contestation (numéro légitime signalé par erreur)
        App->>Backend: POST /api/v1/reports/safe/ { phone_hash: h, category: "HEALTH" }
        Consensus->>Consensus: Évaluation du ratio contestations / signalements
        Consensus->>Backend: Réhabilitation du numéro (retrait du blocage)
        Consensus->>Backend: Journalisation de l'action dans l'AuditLog
        Backend-->>App: Contestation prise en compte
    end
    
    Admin->>Backend: Suivi et ajustements manuels éventuels par les administrateurs
```
