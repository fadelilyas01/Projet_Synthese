# ShieldNet Backend — API REST & Console d'Administration (Django)

Serveur central de la solution **ShieldNet**, fournissant l'API REST utilisée par l'application mobile, le moteur de modération des signalements pour éviter les faux positifs et l'interface web pour l'équipe de supervision.

Développé avec **Python 3.12**, **Django 5.x** et **Django REST Framework (DRF)**.

---

## 1. Rôle du serveur dans l'architecture

Le serveur assure quatre fonctions principales :

1. **Synchronisation incrémentale de la liste de blocage** : Permet à l'application mobile de ne télécharger que les modifications récentes (nouveaux numéros bloqués ou numéros réhabilités), réduisant au minimum la consommation de données et de batterie.
2. **Collecte anonymisée des signalements** : Réception des signalements sous forme d'empreintes cryptographiques HMAC-SHA256. Aucun numéro de téléphone en clair n'est stocké dans la base de données.
3. **Moteur d'arbitrage et consensus citoyen** : Analyse les contestations pour identifier les faux positifs (numéros de livreurs, cliniques, services essentiels signalés par erreur) et réhabiliter automatiquement les correspondants légitimes.
4. **Authentification, Sessions & Récupération sécurisée** : Authentification par email/mot de passe, Google Sign-In, codes de vérification OTP par courriel pour réinitialisation de mot de passe, et jetons JWT (access & refresh).
5. **Console d'administration et de modération** : Interface web claire permettant aux gestionnaires d'examiner les signalements en attente, de vérifier les métriques du système et de gérer les listes de blocage.

---

## 2. Principaux points d'accès de l'API (`/api/v1/`)

Toutes les requêtes de l'application cliente sont sécurisées par clé d'API (`X-API-Key`) ou par jeton d'authentification JWT :

### Authentification & Gestion de compte
| Méthode | URL | Rôle |
|---|---|---|
| `POST` | `/api/v1/auth/register/` | Inscription d'un nouvel utilisateur (Email, mot de passe, région) |
| `POST` | `/api/v1/auth/login/` | Connexion par courriel et mot de passe (retourne JWT tokens + profil) |
| `POST` | `/api/v1/auth/email/send-otp/` | Envoi d'un code de vérification OTP à 6 chiffres par courriel |
| `POST` | `/api/v1/auth/email/verify-otp/` | Vérification de l'OTP et réinitialisation de mot de passe / reconnexion |
| `POST` | `/api/v1/auth/google/` | Authentification via jeton Google ID Token |
| `GET` | `/api/v1/auth/me/` | Récupération du profil courant et validation de session active |
| `POST` | `/api/v1/auth/region/` | Mise à jour de la juridiction (Loi 25 QC, LPRPDE CA, TCPA US) |
| `POST` | `/api/v1/auth/token/refresh/` | Rafraîchissement du jeton d'accès JWT |

### Endpoints pour l'application mobile
| Méthode | URL | Rôle |
|---|---|---|
| `GET` | `/api/v1/blacklist/?since=...` | Téléchargement incrémental ou complet de la liste |
| `GET` | `/api/v1/sync/status/` | Statut global de synchronisation et version du filtre Bloom |
| `POST` | `/api/v1/reports/` | Envoi d'un signalement de numéro indésirable |
| `POST` | `/api/v1/reports/safe/` | Envoi d'une contestation pour un numéro légitime |
| `GET` | `/api/v1/check/<hash>/` | Vérification unitaire du statut d'un numéro |
| `POST` | `/api/v1/check/batch/` | Vérification groupée de plusieurs numéros récents |
| `GET` | `/api/v1/ai/diagnose/?phone_number=...` | Analyse et explications claires sur un numéro |
| `GET` | `/api/v1/compliance/norms/` | Règles réglementaires applicables par région |
| `GET` | `/api/v1/health/` | Sonde de bon fonctionnement du serveur et de la base |

### Endpoints pour la gestion et la modération
| Méthode | URL | Rôle |
|---|---|---|
| `GET` | `/api/v1/admin/stats/` | Statistiques globales (numéros bloqués, signalements, utilisateurs) |
| `GET` | `/api/v1/admin/reports/` | Liste des signalements nécessitant une vérification |
| `POST` | `/api/v1/admin/moderate/` | Blanchiment ou blocage direct d'un numéro par empreinte |
| `POST` | `/api/v1/admin/consensus-audit/` | Déclenchement de la réévaluation des faux positifs |
| `POST` | `/api/v1/admin/purge/` | Purge des anciens signalements expirés |
| `GET` | `/api/v1/admin/audit-logs/` | Consultation du journal des actions des modérateurs |

---

## 3. Installation et exécution en local

### Prérequis
- Python 3.10 ou plus récent
- Git

### 1. Installation de l'environnement virtuel

```powershell
cd shieldnet_backend

# Créer et activer l'environnement virtuel
python -m venv venv
.\venv\Scripts\Activate.ps1

# Installer les dépendances
pip install -r requirements.txt
```

### 2. Initialisation de la base de données

```powershell
# Appliquer les migrations
python manage.py migrate

# Initialiser le compte administrateur
# (Identifiants configurés dans votre fichier .env : ADMIN_EMAIL, ADMIN_PASSWORD)
python manage.py ensure_admin
```

Pour créer un compte interactif personnalisé avec votre propre mot de passe :
```powershell
python manage.py createsuperuser
```

### 3. Exécution des tests automatisés (74 tests)

```powershell
# Exécution de la suite officielle de tests du backend
python manage.py test shield_api
```

*La suite de tests (74/74 validés dans le pipeline Jenkins) vérifie le bon fonctionnement des modèles, de l'authentification JWT & Google OAuth2, des codes OTP, des calculs de consensus citoyen, des règles régionales, du rate-limiting anti-brute force et de la console d'administration SOC.*

### 4. Démarrage du serveur

```powershell
python manage.py runserver 0.0.0.0:8000
```

Accès aux interfaces :
- **Console d'administration SOC** : [http://127.0.0.1:8000/admin/](http://127.0.0.1:8000/admin/)
- **Documentation Swagger / OpenAPI** : [http://127.0.0.1:8000/api/v1/docs/](http://127.0.0.1:8000/api/v1/docs/)
- **Sonde de santé de l'API** : [http://127.0.0.1:8000/api/v1/health/](http://127.0.0.1:8000/api/v1/health/)
- **Journal de sécurité centralisé** : consultable dans `logs/shieldnet_security.log`
