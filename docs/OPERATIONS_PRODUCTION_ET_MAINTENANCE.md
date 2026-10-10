# ShieldNet — Guide des Opérations, Déploiement, Maintenance & Scalabilité

Ce document constitue la référence opérationnelle pour la mise en production, l'exploitation quotidienne, la maintenance préventive et la gestion des incidents de la plateforme **ShieldNet** (Mobile Flutter + Backend Django REST).

---

## 1. Matrice des Rôles et Responsabilités (RACI)

| Domaine d'activité | DevOps / SysAdmin | Analyste Sécurité / SOC | Développeur Backend | Développeur Mobile |
|---|:---:|:---:|:---:|:---:|
| Déploiement et orchestration serveur | **R** / **A** | C | C | I |
| Gestion des clés et secrets de production | **A** | **R** | C | C |
| Surveillance de la réputation & modération | I | **R** / **A** | I | I |
| Déblocage urgent de faux-positifs | I | **R** / **A** | C | I |
| Mises à jour de schémas & migrations BD | C | I | **R** / **A** | I |
| Publication et compatibilité mobile | I | I | C | **R** / **A** |
| Gestion de crise et reprise après incident (PRA) | **R** | **A** | C | C |

*Légende : **R** = Réalisateur (Responsible), **A** = Décideur (Accountable), **C** = Consulté (Consulted), **I** = Informé (Informed).*

---

## 2. Checklist de Déploiement en Production (Go-Live Checklist)

Avant toute bascule en production réelle, valider l'ensemble des points de contrôle suivants :

### A. Sécurité, Environnement & Variables de Production
- [ ] Créer le fichier `.env.production` à partir du template modèle `shieldnet_backend/.env.production.example` (permissions `chmod 600`).
- [ ] `DJANGO_ENV=production` et `DJANGO_DEBUG=False` impérativement configurés.
- [ ] `ALLOWED_HOSTS` configuré avec les domaines réels sans caractère générique (`*` est formellement interdit en prod et lève une exception `ImproperlyConfigured`).
- [ ] `CORS_ALLOW_ALL_ORIGINS=False` et `CORS_ALLOWED_ORIGINS` restreint aux domaines d'administration autorisés (`https://admin.shieldnet.app`).
- [ ] `CSRF_TRUSTED_ORIGINS` configuré avec le protocole HTTPS pour tous les hôtes autorisés.
- [ ] Secrets de production validés (aucun préfixe de dev tel que `dev-`, `test-`, `change-me`, `django-insecure` ; minimum 50 caractères pour `SECRET_KEY`, 32 pour `API_KEY` et `HASH_SALT`).
- [ ] TLS / HTTPS durci :
  - `SECURE_SSL_REDIRECT=True`
  - `SECURE_PROXY_SSL_HEADER=('HTTP_X_FORWARDED_PROTO', 'https')` (derrière reverse-proxy Nginx / Traefik / ALB)
  - `SECURE_HSTS_SECONDS=31536000` (1 an) avec `SECURE_HSTS_INCLUDE_SUBDOMAINS=True` et `SECURE_HSTS_PRELOAD=True`
  - `SESSION_COOKIE_SECURE=True`, `CSRF_COOKIE_SECURE=True`, `SESSION_COOKIE_HTTPONLY=True`
  - `SECURE_REFERRER_POLICY=strict-origin-when-cross-origin`
- [ ] En-tête `X-API-Version: 1.0.0` présent sur chaque réponse API.

### B. Base de Données et Cache
- [ ] PostgreSQL 16 configuré avec collation UTF-8 et extension `pg_trgm` (si requise).
- [ ] Index B-Tree validés sur les colonnes de filtrage critique (`phone_hash`, `is_blocked`, `updated_at`).
- [ ] Redis 7 provisionné avec mot de passe fort et persistance RDB/AOF activée.
- [ ] Connection Pooling configuré (ex. PgBouncer : pool de 50 connexions pour 500 clients concurrents).

### C. Application Mobile Flutter
- [ ] Fichier `.env` mobile initialisé selon le gabarit `ShieldNet/.env.production.example`.
- [ ] `API_BASE_URL` configuré sur l'URL HTTPS finale de production (ex. `https://api.shieldnet.app/api/v1`).
- [ ] `CERTIFICATE_PINNING_ENABLED=true` avec empreinte SHA-256 du certificat de production valide.
- [ ] Build release compilé sans drapeaux de debug (`flutter build apk --release` ou AAB pour Google Play).
- [ ] Obfuscation du code activée (`--obfuscate --split-debug-info=...`).
- [ ] Clé API et sel de hachage injectés via variables de compilation sécurisées (`--dart-define` ou `.env.production`).

---

## 3. Stratégie de Sauvegardes & Reprise après Incident (PRA / DRP)

### Objectifs de Continuité d'Activité
- **RTO (Recovery Time Objective) :** < 15 minutes en cas de sinistre serveur.
- **RPO (Recovery Point Objective) :** < 1 heure de perte de données maximale.

### A. Procédure de Sauvegarde Automatisée

Un script cron quotidien (`/usr/local/bin/shieldnet_backup.sh`) effectue la sauvegarde à chaud :

```bash
#!/usr/bin/env bash
set -eo pipefail

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="/var/backups/shieldnet"
DATABASE="shieldnet_prod"

mkdir -p "${BACKUP_DIR}"

# 1. Dump chiffré de la base de données PostgreSQL
pg_dump -U postgres -Fc "${DATABASE}" | openssl enc -aes-256-cbc -salt -pbkdf2 \
  -pass file:/etc/shieldnet/backup.key \
  -out "${BACKUP_DIR}/shieldnet_db_${TIMESTAMP}.dump.enc"

# 2. Synchronisation sécurisée vers un stockage hors-site (S3 / R2)
aws s3 cp "${BACKUP_DIR}/shieldnet_db_${TIMESTAMP}.dump.enc" s3://shieldnet-backups-vault/daily/

# 3. Rétention : suppression des dumps locaux de plus de 14 jours
find "${BACKUP_DIR}" -type f -name "*.dump.enc" -mtime +14 -delete
```

### B. Procédure de Restauration d'Urgence

1. **Rapatrier le dump le plus récent :**
   ```bash
   aws s3 cp s3://shieldnet-backups-vault/daily/shieldnet_db_YYYYMMDD_HHMMSS.dump.enc /tmp/
   ```

2. **Déchiffrer l'archive :**
   ```bash
   openssl enc -d -aes-256-cbc -pbkdf2 \
     -pass file:/etc/shieldnet/backup.key \
     -in /tmp/shieldnet_db_YYYYMMDD_HHMMSS.dump.enc \
     -out /tmp/shieldnet_db.dump
   ```

3. **Restaurer la base de données :**
   ```bash
   pg_restore -U postgres -d shieldnet_prod --clean --if-exists /tmp/shieldnet_db.dump
   rm -f /tmp/shieldnet_db.dump /tmp/shieldnet_db_*.dump.enc
   ```

4. **Vérifier l'intégrité :**
   ```bash
   docker compose exec web python manage.py check
   docker compose exec web python manage.py test shield_api.tests.test_api
   ```

---

## 4. Politique de Déploiement et de Rollback

### Déploiement Zero-Downtime (Rolling Updates)
1. **Migrations additives uniquement :** Ne jamais renommer ni supprimer de colonne dans la même version applicative.
   - Étape 1 : Ajouter la nouvelle colonne en `null=True`.
   - Étape 2 : Déployer le nouveau code backend qui écrit dans les deux colonnes.
   - Étape 3 : Script de remplissage des anciennes lignes.
   - Étape 4 (Version suivante) : Supprimer l'ancienne colonne.
2. **Bascule de conteneurs :** Utiliser des vérifications d'état de santé (*healthchecks*) avant de rediriger le trafic Nginx.

### Procédure de Rollback Immédiat
Si une anomalie critique ou une régression est constatée post-déploiement :

```bash
# 1. Rétablir immédiatement l'image Docker précédente
docker compose stop web
docker compose up -d web:previous-tag

# 2. Si une migration de base doit être annulée :
docker compose exec web python manage.py migrate shield_api 000X_previous_migration

# 3. Vider le cache Redis pour éliminer tout résidu incohérent
docker compose exec redis redis-cli FLUSHDB

# 4. Vérifier la reprise du service
curl -I https://api.shieldnet.app/api/v1/blacklist/
```

---

## 5. Stratégie de Scalabilité & Gestion de Charge

### A. Cache Distribué Redis
- **Endpoints à forte lecture :**
  - `/api/v1/blacklist/` (téléchargement delta ou liste globale) : mis en cache Redis avec TTL de 300 secondes (5 min).
  - Invalidation proactive lors de tout ajout par consensus ou action de modération admin (`ReputationService` ou `AdminModerateView`).
- **Limitation de débit (Rate Limiting) :**
  - Gérée dans Redis via DRF Throttling :
    - Utilisateurs anonymes : `120 requêtes/minute`.
    - Utilisateurs authentifiés : `600 requêtes/minute`.
    - Authentification / OTP : `5 à 15 requêtes/minute` pour neutraliser le brute-force.

### B. Optimisation des Requêtes Fréquentes
- **Indexation B-Tree :** Le champ `phone_hash` (64 caractères hexadécimaux HMAC-SHA256) bénéficie d'un index unique B-Tree :
  ```sql
  CREATE UNIQUE INDEX idx_blacklisted_hash ON shield_api_blacklistednumber (phone_hash);
  CREATE INDEX idx_blacklisted_updated ON shield_api_blacklistednumber (updated_at);
  ```
- **Requêtes différentielles (*Delta Sync*) :** Les applications mobiles transmettent le paramètre `?since=ISO_TIMESTAMP`, réduisant la bande passante de 98% en ne transférant que les nouveautés depuis la dernière synchronisation.
- **Vérification groupée (*Batch Check*) :** L'endpoint `/api/v1/check-batch/` permet d'inspecter jusqu'à 50 numéros en une seule requête HTTP plutôt que 50 requêtes individuelles.

---

## 6. Politique de Versioning de l'API REST

Pour préserver l'interopérabilité sans interrompre les installations mobiles sur le terrain :

1. **Préfixe d'URL explicite :** Tout endpoint est versionné selon le préfixe `/api/v1/`.
2. **En-tête de version :** Chaque réponse serveur injecte automatiquement `X-API-Version: 1.0.0`.
3. **Règle de compatibilité ascendante :**
   - L'ajout de champs dans les réponses JSON ne doit jamais constituer un changement cassant (*breaking change*).
   - Les clients mobiles ignorent automatiquement les champs non reconnus.
4. **Politique de dépréciation :**
   - Lorsqu'une version v2 est introduite, `/api/v1/` est maintenue en service pendant **au moins 12 mois**.
   - Injection des en-têtes RFC 8594 : `Sunset: <date>` et `Deprecation: @<timestamp>`.

---

## 7. Guide de Résolution d'Incidents (Playbook SOC & Ops)

### Incident 1 : Détection d'un Faux-Positif Bloquant un Numéro Essentiel
- **Symptôme :** Un numéro d'hôpital, d'école ou d'institution est bloqué par erreur.
- **Action de Remédiation (< 2 minutes) :**
  1. Ouvrir l'application mobile en compte Administrateur ou accéder au portail web `/admin/`.
  2. Aller dans l'onglet **Modération** et rechercher le numéro ou son empreinte.
  3. Cliquer sur **Réhabiliter (Liste Blanche)** :
     - Le numéro est instantanément débloqué en base centrale.
     - L'invalidation de cache Redis est déclenchée.
     - Le prochain Delta Sync mobile purgera automatiquement l'entrée de la base SQLite locale de tous les utilisateurs.
  4. En ligne de commande serveur (alternative d'urgence) :
     ```bash
     docker compose exec web python manage.py shell -c "
     from shield_api.models import BlacklistedNumber
     num = BlacklistedNumber.objects.get(phone_hash='HASH_DU_NUMERO')
     num.is_whitelisted = True
     num.is_blocked = False
     num.save()
     print('Numéro réhabilité avec succès')
     "
     ```

### Incident 2 : Pic de Latence ou Épuisement des Connexions Base de Données
- **Symptôme :** Code HTTP 504 Gateway Timeout ou erreurs de pool PostgreSQL.
- **Action de Remédiation :**
  1. Vérifier le nombre de processus actifs :
     ```bash
     docker compose exec db psql -U postgres -c "SELECT count(*), state FROM pg_stat_activity GROUP BY state;"
     ```
  2. Ajuster le nombre de workers Gunicorn et la limite de connexions PgBouncer :
     ```bash
     docker compose exec web gunicorn shieldnet_backend.wsgi:application --workers 8 --threads 4
     ```

### Incident 3 : Tentative d'Attaque par Déni de Service ou Brute-Force
- **Symptôme :** Multiplication de codes HTTP 429 et logs `[RateLimit]` dans la journalisation.
- **Action de Remédiation :**
  1. Inspecter les adresses IP sources via les logs Nginx :
     ```bash
     tail -n 1000 /var/log/nginx/access.log | awk '{print $1}' | sort | uniq -c | sort -nr | head -n 10
     ```
  2. Bloquer l'adresse IP hostile au niveau du pare-feu serveur :
     ```bash
     sudo ufw insert 1 deny from IP_SUSPECTE to any
     ```

---

## 8. Procédures de Maintenance Hebdomadaire et Mensuelle

### Tâches Hebdomadaires
- [ ] Examen du tableau de bord SOC (ratio faux-positifs, volume de signalements récents).
- [ ] Purge des signalements obsolètes ou expirés (`python manage.py purge_expired_threats`).
- [ ] Revue des logs de sécurité critiques (`shieldnet.security` niveau `WARNING` et `ERROR`).

### Tâches Mensuelles
- [ ] Test à blanc de restauration d'un dump de base de données dans un conteneur isolé.
- [ ] Exécution de `VACUUM ANALYZE` sur la base PostgreSQL pour réindexer les tables volumineuses.
- [ ] Vérification du renouvellement automatique des certificats SSL Let's Encrypt (`certbot renew --dry-run`).
- [ ] Mise à jour des dépendances de sécurité Python et Dart (`safety check`, `flutter pub outdated`).
