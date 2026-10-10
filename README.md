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

Le projet est divisé en deux grandes composantes complémentaires :

```text
Projet synthese/
├── ShieldNet/                # Application mobile client (Flutter & Kotlin natif)
│   ├── android/              # Service natif d'interception (CallScreeningService) & Gradle 8.13+
│   ├── lib/                  # Code source Flutter (Clean Architecture, Riverpod)
│   ├── l10n/                 # Fichiers de localisation bilingues (français / anglais)
│   └── test/                 # 52 tests automatisés (unitaires, services et sécurité)
│
├── shieldnet_backend/        # Serveur d'API REST et console de modération (Django)
│   ├── shield_api/           # API REST, modèles, services de modération, OTP et consensus
│   ├── shieldnet_backend/    # Configuration générale et routage Django
│   ├── templates/            # Gabarits HTML de la console d'administration
│   └── test/                 # 74 tests automatisés du backend
│
├── docs/                     # Documentation technique détaillée
│   ├── ARCHITECTURE_ET_CONCEPTION.md
│   ├── DEPLOIEMENT_ET_CI_CD.md
│   ├── OPERATIONS_PRODUCTION_ET_MAINTENANCE.md # Guide des opérations, PRA, scalabilité et versioning
│   └── SECURITY_AND_THREAT_MODEL.md
│
├── start-dev.ps1             # Script de démarrage de l'environnement de développement
└── test-all.ps1              # Script pour exécuter l'ensemble des 136 tests
```

---

## 3. Guide de démarrage rapide

### Prérequis
- **Python 3.10 ou supérieur** (testé avec Python 3.12)
- **Flutter SDK 3.27 ou supérieur**
- **Android Studio** avec un émulateur configuré (API 29+) ou un appareil Android en mode débogage

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
- **Console d'administration** : [http://127.0.0.1:8000/admin/](http://127.0.0.1:8000/admin/)
  - Accès sécurisé : comptes configurés via les variables d'environnement (`ADMIN_EMAIL`, `ADMIN_PASSWORD` dans `.env`) ou créés avec `python manage.py createsuperuser`
- **Documentation Swagger** : [http://127.0.0.1:8000/api/v1/docs/](http://127.0.0.1:8000/api/v1/docs/)
- **Sonde de santé** : [http://127.0.0.1:8000/api/v1/health/](http://127.0.0.1:8000/api/v1/health/)

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

*Note : si vous utilisez l'émulateur standard Android, l'adresse de votre machine hôte est automatiquement configurée sur `10.0.2.2:8000`.*

---

## 4. Tests automatisés et qualité du code

Le projet comprend **136 tests automatisés (100% passants)** qui valident le bon fonctionnement de l'ensemble de la solution :

- **74 tests côté backend (Django)** : couvrent l'API REST, l'authentification JWT, les codes OTP, les calculs de consensus citoyen, le filtrage régional, les métriques SOC et la modération.
- **62 tests côté mobile (Flutter)** : valident le filtrage d'appels, l'IA prédictive, le hachage HMAC-SHA256, la gestion de session (timeout 5 min avec empreinte), l'observabilité utilisateur, le mode démo jury, le stockage sécurisé et la résilience réseau (retry & backoff).

Pour exécuter tous les tests d'un seul coup :
```powershell
.\test-all.ps1
```
