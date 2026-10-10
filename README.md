# ShieldNet — Filtrage d'appels indésirables et respect de la vie privée

ShieldNet est un projet de synthèse en génie logiciel dédié à la protection des citoyens contre les appels indésirables, les tentatives de fraude téléphonique et le démarchage automatisé (*robocalls*), principalement sur le plan de numérotation nord-américain (+1, Québec, Canada et États-Unis).

Contrairement à la majorité des applications commerciales qui aspirent le carnet de contacts vers des serveurs distants, ShieldNet a été conçu selon le principe de **protection de la vie privée dès la conception** (*Privacy by Design*). Les décisions de blocage sont prises localement sur le téléphone et aucune donnée personnelle en clair n'est transmise ou stockée sur le serveur, en stricte conformité avec la **Loi 25 du Québec**, la **LPRPDE** canadienne et la **TCPA** américaine.

---

## 1. Principes de fonctionnement

1. **Aucune collecte de carnet d'adresses** : Les contacts personnels restent strictement dans la mémoire du téléphone. Aucun contact n'est extrait, transmis ou indexé sur un serveur distant.
2. **Données anonymisées par empreinte (HMAC-SHA256)** : Les numéros signalés ne transitent jamais en clair. Ils sont convertis en empreintes cryptographiques avec un sel d'infrastructure avant tout échange réseau.
3. **Interception locale instantanée (< 2 ms)** : Sur Android, le filtrage s'appuie sur le service système `CallScreeningService` et une base SQLite locale en mode WAL (*Write-Ahead Logging*). La vérification prend moins de 2 millisecondes, permettant de bloquer l'appel avant même la première sonnerie.
4. **Sécurité de session et contrôle d'accès renforcé** : Verrouillage automatique de session après **5 minutes d'inactivité ou de mise en arrière-plan**, déverrouillage biométrique prioritaire (Face ID / Empreinte digitale) et récupération de mot de passe par code OTP à 6 chiffres par courriel.
5. **Prévention des faux positifs & Consensus citoyen** : Pour éviter de bloquer des numéros légitimes (hôpitaux, cliniques médicales, pharmacies, livreurs), le système combine les avis favorables de la communauté et les attestations télécom STIR/SHAKEN.
6. **Immunité absolue des urgences** : Les numéros d'urgence (911, 811, 988, etc.) ainsi que les contacts favoris de l'utilisateur sont protégés et ne peuvent jamais être filtrés.

---

## 2. Structure du projet

Le projet est divisé en deux grandes composantes complémentaires avec une infrastructure CI/CD complète :

```text
Projet synthese/
├── ShieldNet/                # Application mobile client (Flutter & Kotlin natif)
│   ├── android/              # Service natif d'interception (CallScreeningService) & Gradle 8.13+
│   ├── lib/                  # Code source Flutter (Clean Architecture, Riverpod)
│   ├── l10n/                 # Fichiers de localisation bilingues (français / anglais)
│   └── test/                 # 62 tests automatisés (unitaires, services, observabilité et sécurité)
│
├── shieldnet_backend/        # Serveur d'API REST et console de modération (Django)
│   ├── shield_api/           # API REST, modèles, services de modération, OTP et consensus
│   │   └── tests/            # 74 tests automatisés du backend (API, consensus, RBAC et modération)
│   ├── shieldnet_backend/    # Configuration générale et routage Django
│   └── templates/            # Gabarits HTML de la console d'administration SOC
│
├── docs/                     # Documentation technique détaillée
│   ├── ARCHITECTURE_ET_CONCEPTION.md
│   ├── DEPLOIEMENT_ET_CI_CD.md
│   ├── OPERATIONS_PRODUCTION_ET_MAINTENANCE.md # Guide des opérations, PRA, scalabilité et versioning
│   └── SECURITY_AND_THREAT_MODEL.md
│
├── Jenkinsfile               # Pipeline d'intégration continue CI/CD (136 tests, linting, build APK)
├── docker-compose.jenkins.yml# Déploiement local du serveur Jenkins LTS conteneurisé
├── start-dev.ps1             # Script de démarrage de l'environnement de développement
└── test-all.ps1              # Script pour exécuter l'ensemble des 136 tests automatisés
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

Le projet comprend **136 tests automatisés (100% au vert)** validant le bon fonctionnement de l'ensemble de la solution :

- **74 tests côté backend (Django)** : couvrent l'API REST, l'authentification JWT, les codes OTP, les calculs de consensus citoyen, le filtrage régional, les métriques SOC, la modération et la résilience aux pannes.
- **62 tests côté mobile (Flutter)** : valident le filtrage d'appels, l'IA prédictive, le hachage HMAC-SHA256, la gestion de session (timeout 5 min avec reverrouillage biométrique), l'observabilité utilisateur, le mode démo jury, le stockage sécurisé et la résilience réseau (retry exponentiel & backoff).

Pour exécuter la suite complète des 136 tests d'un seul coup :
```powershell
.\test-all.ps1
```

---

## 5. Pipeline d'Intégration Continue (CI/CD) avec Jenkins

La qualité et l'intégrité du code sont automatisées à chaque validation via le fichier [`Jenkinsfile`](file:///C:/Projet/Projet%20synthese/Jenkinsfile).

### Étapes du pipeline Jenkins (136 tests validés) :
1. **Environnement & Outils** : Détection des exécutables et versions (`python`, `flutter`, `git`).
2. **Backend — Validation & Tests (Django)** : Installation des dépendances, vérification stricte des migrations (`makemigrations --check --dry-run`) et exécution des **74 tests unitaires** (`python manage.py test shield_api`).
3. **Mobile — Analyse Statique (Flutter Linter)** : Analyse rigoureuse du code Dart avec `flutter analyze` (**0 avertissement bloquant toléré**).
4. **Mobile — Tests Unitaires & Widgets (Flutter)** : Exécution des **62 tests automatisés** avec `flutter test`.
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
Le pipeline exécute automatiquement les 136 tests et archive l'APK téléchargeable à chaque commit.
