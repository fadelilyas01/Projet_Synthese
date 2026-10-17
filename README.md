# ShieldNet — Filtrage d'appels indésirables et respect de la vie privée

ShieldNet est un projet de synthèse en génie logiciel dédié à la protection des citoyens contre les appels indésirables, les tentatives de fraude téléphonique et le démarchage automatisé (*robocalls*), principalement sur le plan de numérotation nord-américain (+1, Québec, Canada et États-Unis).

Contrairement à la majorité des applications commerciales qui aspirent le carnet de contacts vers des serveurs distants, ShieldNet a été conçu selon le principe de **protection de la vie privée dès la conception** (*Privacy by Design*). Les décisions de blocage sont prises localement sur le téléphone et aucune donnée personnelle en clair n'est transmise ou stockée sur le serveur, en stricte conformité avec la **Loi 25 du Québec**, la **LPRPDE** canadienne et la **TCPA** américaine.

---

## 1. Principes de fonctionnement

1. **Aucune collecte de carnet d'adresses** : Les contacts personnels restent strictement dans la mémoire du téléphone. Aucun contact n'est extrait, transmis ou indexé sur un serveur distant.
2. **Données anonymisées par empreinte (HMAC-SHA256)** : Les numéros signalés ne transitent jamais en clair. Ils sont convertis en empreintes cryptographiques avec un sel d'infrastructure avant tout échange réseau.
3. **Interception locale instantanée (< 2 ms)** : Sur Android, le filtrage s'appuie sur le service système `CallScreeningService` et une base SQLite locale en mode WAL (*Write-Ahead Logging*). La vérification prend moins de 2 millisecondes, permettant de bloquer l'appel avant même la première sonnerie.
4. **Démarrage instantané (0 ms de latence perçue)** : Pré-chargement asynchrone parallélisé au boot (< 15 ms), élimination des écrans de chargement clignotants et accès direct à l'interface principale dès l'ouverture.
5. **Radar des arnaques au Québec et par région** : Surveillance ciblée des vagues d'usurpation d'indicatifs. Si l'utilisateur réside au Québec, seules les alertes de ses indicatifs (514, 438, 450, 418, 819...) et de ses villes sont affichées, à l'exclusion stricte des autres provinces et États.
6. **Espace « Mes numéros bloqués » strictement privé** : L'onglet des numéros bloqués affiche exclusivement les numéros que l'utilisateur a lui-même bloqués personnellement, sans les mélanger avec la base de données globale du serveur.
7. **Sécurité de session et contrôle d'accès renforcé** : Verrouillage automatique de session après **5 minutes d'inactivité ou de mise en arrière-plan**, déverrouillage biométrique prioritaire (Face ID / Empreinte digitale) et récupération de mot de passe par code OTP à 6 chiffres par courriel.
8. **Prévention des faux positifs & Avis citoyen** : Pour éviter de bloquer des correspondants légitimes (hôpitaux, cliniques médicales, pharmacies, livreurs), le système combine les avis de la communauté et les attestations télécom STIR/SHAKEN.
9. **Immunité absolue des urgences** : Les numéros d'urgence (911, 811, 988, etc.) ainsi que les contacts favoris de l'utilisateur sont protégés et ne peuvent jamais être filtrés.
10. **Zéro jargon informatique** : Interface conçue pour tous en français naturel (« Vérifier mes appels », « Signaler comme sûr », « Faux numéros usurpés » au lieu de jargon technique intimidant).

---

## 2. Structure du projet

Le projet est divisé en deux grandes composantes complémentaires avec une infrastructure CI/CD complète :

```text
Projet synthese/
├── ShieldNet/                # Application mobile client (Flutter & Kotlin natif)
│   ├── android/              # Service natif d'interception (CallScreeningService) & Gradle 8.13+
│   ├── lib/                  # Code source Flutter (Clean Architecture, Riverpod)
│   ├── l10n/                 # Fichiers de localisation bilingues (français / anglais)
│   └── test/                 # 71 tests automatisés (unitaires, services, radar québécois et sécurité)
│
├── shieldnet_backend/        # Serveur d'API REST et console de modération (Django)
│   ├── shield_api/           # API REST, modèles, moteur IA, modération, OTP et consensus
│   │   └── tests/            # 93 tests automatisés du backend (API, consensus, RBAC, OAuth et sécurité)
│   ├── shieldnet_backend/    # Configuration générale et routage Django
│   └── templates/            # Gabarits HTML de la console d'administration SOC
│
├── docs/                     # Documentation technique détaillée
│   ├── ARCHITECTURE_ET_CONCEPTION.md
│   ├── DEPLOIEMENT_ET_CI_CD.md
│   ├── OPERATIONS_PRODUCTION_ET_MAINTENANCE.md # Guide des opérations, PRA, scalabilité et versioning
│   └── SECURITY_AND_THREAT_MODEL.md
│
├── .github/workflows/ci.yml  # Pipeline GitHub Actions CI/CD (164 tests automatisés, linting, couverture)
├── Jenkinsfile               # Pipeline Jenkins CI/CD alternatif
├── docker-compose.jenkins.yml# Déploiement local du serveur Jenkins LTS conteneurisé
├── start-dev.ps1             # Script de démarrage de l'environnement de développement
└── test-all.ps1              # Script PowerShell pour exécuter l'ensemble des 164 tests automatisés
```

---

## 3. Guide de démarrage rapide

### Prérequis
- **Python 3.10 ou supérieur** (testé avec Python 3.12)
- **Flutter SDK 3.27 ou supérieur**
- **Android Studio** avec un émulateur configuré (API 29+) ou un appareil Android en mode débogage
- **Docker** (optionnel, pour exécuter le serveur Jenkins CI/CD local)

---

### Étape 1 : Lancement du serveur backend (Django)

Dans un premier terminal :

```powershell
cd shieldnet_backend

# Créer et activer l'environnement virtuel
python -m venv venv
.\venv\Scripts\Activate.ps1

# Installer les dépendances
pip install -r requirements.txt

# Appliquer les migrations de base de données
python manage.py migrate

# Initialiser les comptes administrateur et modérateur
# (Les identifiants sécurisés sont configurés dans votre fichier .env)
python manage.py ensure_admin

# Démarrer le serveur
python manage.py runserver 0.0.0.0:8000
```

Une fois le serveur en ligne :
- **Console d'administration SOC** : [http://127.0.0.1:8000/admin/](http://127.0.0.1:8000/admin/)
  - Accès sécurisé : comptes configurés via les variables d'environnement (`ADMIN_EMAIL`, `ADMIN_PASSWORD` dans `.env`) ou créés avec `python manage.py createsuperuser`
- **Documentation Swagger / OpenAPI** : [http://127.0.0.1:8000/api/v1/docs/](http://127.0.0.1:8000/api/v1/docs/)
- **Sonde de santé de l'API** : [http://127.0.0.1:8000/api/v1/health/](http://127.0.0.1:8000/api/v1/health/)

---

### Étape 2 : Lancement de l'application mobile (Flutter)

Dans un second terminal :

```powershell
cd ShieldNet

# Télécharger les paquets Flutter et générer les traductions
flutter pub get
flutter gen-l10n

# Lancer l'application sur l'émulateur ou le téléphone
flutter run
```

*Note : si vous utilisez l'émulateur standard Android, l'adresse de votre machine hôte est automatiquement configurée sur `10.0.2.2:8000` via le client intelligent [`ApiClient`](file:///C:/Projet/Projet%20synthese/ShieldNet/lib/core/network/api_client.dart).*

---

## 4. Tests automatisés et qualité du code

Le projet comprend **164 tests automatisés (100% au vert)** validant le bon fonctionnement de l'ensemble de la solution :

- **93 tests côté backend (Django)** : couvrent l'API REST, l'authentification JWT, les codes OTP avec anti-bombardement (CWE-307), la protection anti-Confused Deputy OAuth Google (CWE-287), la mitigation des timing attacks (CWE-208), le masquage Loi 25, le moteur IA d'arbitrage sémantique, les calculs de consensus citoyen, le filtrage régional, les métriques SOC, la modération et la résilience aux pannes.
- **71 tests côté mobile (Flutter)** : valident le filtrage d'appels natif, l'IA heuristique prédictive (Neighbor Spoofing, Burst Dialing, entropie), le hachage HMAC-SHA256, la gestion de session (timeout 5 min avec reverrouillage biométrique), le filtre d'appels nocturne et strict, le stockage sécurisé et la synchronisation résiliente.

Pour exécuter la suite complète des 164 tests d'un seul coup :
```powershell
.\test-all.ps1
```

---

## 5. Pipelines d'Intégration Continue (CI/CD)

La qualité et l'intégrité du code sont automatisées à chaque validation via deux solutions prêtes à l'emploi :

### A. Pipeline Cloud GitHub Actions ([`.github/workflows/ci.yml`](file:///C:/Projet/Projet%20synthese/.github/workflows/ci.yml))
Exécuté automatiquement à chaque `push` ou `pull request` sur GitHub :
- Configuration automatique des environnements Python 3.12 et Flutter stable.
- Vérification stricte des migrations Django (`makemigrations --check --dry-run`).
- Exécution de l'analyse statique Flutter (`flutter analyze` — 0 avertissement).
- Exécution de l'intégralité des **164 tests automatisés** avec rapport de couverture.

### B. Pipeline Local / On-Premise Jenkins ([`Jenkinsfile`](file:///C:/Projet/Projet%20synthese/Jenkinsfile))
Pour les infrastructures privées ou démonstrations locales :
1. **Environnement & Outils** : Détection des exécutables et versions (`python`, `flutter`, `git`).
2. **Backend — Validation & Tests (Django)** : Installation des dépendances, vérification stricte des migrations et exécution des tests backend.
3. **Mobile — Analyse Statique (Flutter Linter)** : Analyse rigoureuse du code Dart avec `flutter analyze` (**0 avertissement toléré**).
4. **Mobile — Tests Unitaires & Widgets (Flutter)** : Exécution de l'ensemble des tests mobiles.
5. **Mobile — Compilation de l'APK Android** : Génération automatisée du paquet d'application avec `flutter build apk --debug`.
6. **Archivage des Artefacts** : Conservation et mise à disposition directe du binaire APK compilé (`app-debug.apk`) dans Jenkins.

### Démarrage rapide de Jenkins en local :
Un environnement Jenkins prêt à l'emploi est configuré via [`docker-compose.jenkins.yml`](file:///C:/Projet/Projet%20synthese/docker-compose.jenkins.yml) :

```powershell
# Démarrer le conteneur Jenkins
docker compose -f docker-compose.jenkins.yml up -d

# Récupérer le mot de passe initial administrateur
docker exec shieldnet_jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

L'interface web est accessible à l'adresse : **[http://localhost:8080](http://localhost:8080)**.
Le pipeline exécute automatiquement les 164 tests et archive l'APK téléchargeable à chaque commit.
