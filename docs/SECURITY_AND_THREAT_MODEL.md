# Sécurité, modèle de menace et respect de la vie privée — ShieldNet

Ce document expose les principes de sécurité, l'évaluation des risques selon la méthodologie **STRIDE**, l'analyse mathématique de l'entropie des numéros téléphoniques et les mesures concrètes de conformité aux lois sur la protection des données (**Loi 25 du Québec** et **LPRPDE canadienne**).

---

## 1. Contexte réglementaire et protection de la vie privée

La majorité des applications d'identification d'appels existantes fonctionnent en téléversant l'intégralité du carnet d'adresses de leurs utilisateurs sur des serveurs distants. Cette pratique pose de sérieux problèmes de conformité avec la législation québécoise et canadienne :

* **Loi 25 du Québec** : Exige la protection des renseignements personnels dès la conception (*Privacy by Design*), la stricte minimisation de la collecte aux seules données indispensables et la transparence quant aux décisions automatisées.
* **LPRPDE (Canada)** : Impose le consentement éclairé de la personne concernée. L'envoi automatique de contacts tiers qui n'ont jamais consenti à ce traitement est directement contraire à ce principe.

### Les choix de conception de ShieldNet :
1. **Zéro accès au carnet d'adresses côté serveur** : Aucun contact n'est jamais lu, aspiré ou envoyé à un serveur.
2. **Aucun numéro stocké en clair** : Toutes les requêtes et les enregistrements en base s'effectuent sur des empreintes cryptographiques **HMAC-SHA256**.
3. **Filtrage local autonome** : L'interception et le contrôle des appels sont exécutés directement sur le téléphone via SQLite, sans requête réseau obligatoire lors de l'appel.

---

## 2. Analyse mathématique de l'espace des numéros (NANP +1)

### 2.1. Taille de l'espace combinatoire
Le plan de numérotation nord-américain (**NANP**) régit les indicatifs sous le code pays `+1` (Canada et États-Unis). 

Chaque numéro suit la structure UIT-T E.164 :
$$\text{+1 } [N_1 X_1 X_2] - [N_2 X_3 X_4] - [X_5 X_6 X_7 X_8]$$

Selon les spécifications du CRTC et de l'ATIS :
* Le premier chiffre de l'indicatif régional et du central ($N_1, N_2$) est compris entre 2 et 9 (les chiffres 0 et 1 étant réservés pour le routage d'opérateur).
* Les autres chiffres ($X_i$) varient de 0 à 9.

Le nombre maximal théorique de combinaisons possibles est de :
$$N_{\text{théorique}} = 8 \times 10^2 \times 8 \times 10^2 \times 10^4 = 6{,}4 \times 10^9 \text{ combinaisons}$$

En retirant les numéros d'urgence et de services spéciaux (911, 811, 988, etc.), les plages réservées pour les tests (555-0100 à 555-0199) ainsi que les indicatifs régionaux non attribués, l'espace réel effectif s'élève à :
$$N_{\text{effectif}} \approx 7{,}8 \times 10^8 \text{ numéros (soit environ 780 millions)}$$

### 2.2. Entropie d'information et risque d'attaque par dictionnaire
L'entropie de Shannon associée à cet espace est de :
$$H = \log_2(7{,}8 \times 10^8) \approx 29{,}54 \text{ bits}$$

Une entropie d'environ 30 bits est très faible face aux capacités des ordinateurs modernes. Une carte graphique actuelle peut calculer plus de 25 milliards d'empreintes SHA-256 par seconde.

Générer une table d'inversion (*rainbow table*) pour couvrir l'ensemble des numéros de téléphone nord-américains ne prendrait que :
$$T = \frac{7{,}8 \times 10^8}{25 \times 10^9 \text{ calculs/sec}} \approx 31 \text{ millisecondes}$$

**Conclusion technique** : Un simple hachage SHA-256 sans sel est totalement inefficace pour protéger la vie privée des utilisateurs. L'emploi d'un code d'authentification de message avec clé secrète (**HMAC-SHA256**) est obligatoire pour rendre impossible la construction de dictionnaires précalculés hors du système.

---

## 3. Justification du choix HMAC-SHA256 face à Argon2id

Dans le domaine de la sécurité des mots de passe, on recommande habituellement des fonctions à mémoire dure comme **Argon2id** ou **bcrypt**. Dans le cadre de ShieldNet, ce choix a été écarté en raison des contraintes temps réel imposées par Android :

```text
Budget temporel alloué par Android CallScreeningService :
0 ms                  0.2 ms             1.7 ms                                100 ms
|---------------------|------------------|---------------------------------------|
[Appel Détecté]       [HMAC-SHA256]      [Recherche SQLite WAL]  [Décision Télécom]
                      (~0.15 ms)         (~1.5 ms)
```

1. **Délai système maximal** : L'API `CallScreeningService` d'Android accorde un délai très court (généralement moins de 100 à 200 ms) pour qualifier l'appel. Si l'application tarde à répondre, le système lève la main et fait sonner le téléphone pour ne pas bloquer les communications légitimes.
2. **Mesures sur appareil mobile** :
   - **HMAC-SHA256** : S'exécute en **~0,15 ms**. La chaîne complète (normalisation du numéro au format E.164, calcul de l'empreinte, vérification des numéros d'urgence et requête SQLite indexée) prend **moins de 2 ms au total**.
   - **Argon2id** (avec 64 Mo de mémoire et 3 itérations) : Prend entre **350 et 800 ms** sur un smartphone de milieu de gamme. Ce temps d'attente dépasse largement le délai système et rendrait le filtrage inopérant.

L'utilisation d'HMAC-SHA256 combinée à un sel secret d'infrastructure offre ainsi le juste équilibre entre vitesse d'exécution critique et résistance aux attaques par dictionnaire.

---

## 4. Modèle de menace STRIDE et contre-mesures

L'analyse des risques a été menée selon la méthodologie STRIDE pour chaque composant du système :

| Menace STRIDE | Scénario envisagé | Contre-mesure mise en place |
|---|---|---|
| **Spoofing (Usurpation)** | Un utilisateur malveillant inonde l'API de faux signalements pour faire bloquer un numéro légitime (attaque Sybil). | **Moteur de consensus** : Seuil minimal de 3 signalements indépendants, prise en compte des contestations légitimes et pondération des utilisateurs. |
| **Tampering (Altération)** | Interception ou falsification des listes de réputation lors de leur transit réseau (attaque MitM). | **Chiffrement TLS 1.3 / HTTPS** et validation stricte du format des empreintes reçues (chaîne hexadécimale de 64 caractères). |
| **Repudiation (Répudiation)** | Un modérateur modifie ou retire un numéro de la liste sans laisser de trace. | **Journal d'audit (`AuditLog`)** traçant systématiquement l'auteur de l'action, son adresse IP, la date UTC et les valeurs modifiées. |
| **Information Disclosure (Fuite)** | Vol ou fuite de la base de données PostgreSQL exposant les numéros des utilisateurs. | **Zéro numéro en clair** : Seules des empreintes HMAC-SHA256 sont stockées en base. Masquage systématique à l'affichage (`+1 819 *** **99`). |
| **Denial of Service (DDoS)** | Tentative de saturation de l'API de consultation par des requêtes répétitives. | **Limitation du débit (Rate Limiting avec Redis)**, synchronisation différentielle (`/api/v1/sync/delta`) et consultations groupées par lots (`/api/v1/check/batch/`). |
| **Elevation of Privilege (Élévation)** | Tentative d'un utilisateur ordinaire d'accéder aux fonctions de modération ou de purge. | **Contrôle d'accès RBAC** géré par Django avec vérification des drapeaux `is_staff` et `is_superuser`, sans accès OAuth pour les comptes sensibles. |

---

## 5. Mesures de sécurité complémentaires

### 5.1. Comparaison à temps constant
Pour éviter les attaques par canal auxiliaire basées sur le temps de réponse (*timing attacks*, CWE-208), toutes les vérifications de jetons et de clés API dans le backend utilisent la fonction `hmac.compare_digest` de Python au lieu d'une comparaison standard `==`.

### 5.2. Filtre de Bloom pré-calculé
Pour accélérer les consultations côté client et réduire l'usure de la mémoire de stockage :
- Le serveur met à disposition un filtre de Bloom probabiliste généré à partir des numéros indésirables connus (`/api/v1/sync/bloom/`).
- Le client peut tester la présence d'un hash en mémoire en temps constant $O(1)$.
- Si le filtre indique que le numéro n'est pas présent (garantie mathématique sans faux négatifs), l'appel est validé immédiatement sans avoir à interroger le disque SQLite.

### 5.3. Détection des environnements altérés
L'application mobile intègre une routine de vérification au démarrage pour détecter si l'appareil est déverrouillé (*root*) ou s'il utilise des binaires super-utilisateur (`su`), afin d'informer l'utilisateur des risques pour l'intégrité de ses données locales.

### 5.4. Durcissement des configurations d'environnement et politique TLS / HSTS
Pour prémunir le backend contre les erreurs d'inattention et les fuites d'informations en production :
- **Validation d'entropie des secrets (`_validate_secrets`)** : Au démarrage du serveur Django, une inspection stricte vérifie que `SECRET_KEY`, `API_KEY` et `HASH_SALT` ne contiennent aucun préfixe par défaut de test (`dev-`, `test-`, `change-me`, `django-insecure`) et respectent une longueur minimale cryptographique (50 caractères pour Django, 32 pour les clés HMAC et API).
- **Interdiction formelle des jokers `ALLOWED_HOSTS`** : En mode production (`DJANGO_ENV=production`), la présence d'un caractère générique `*` provoque immédiatement un arrêt du serveur via `ImproperlyConfigured`.
- **Politique CORS & CSRF hermétique** : `CORS_ALLOW_ALL_ORIGINS` est forcé à `False` en production, et les origines fiables doivent être expressément déclarées sous protocole HTTPS (`CSRF_TRUSTED_ORIGINS`).
- **En-têtes TLS stricts et sécurité des cookies** : En production, `SECURE_SSL_REDIRECT=True`, `SECURE_PROXY_SSL_HEADER=('HTTP_X_FORWARDED_PROTO', 'https')`, `SECURE_HSTS_SECONDS=31536000` (HSTS actif 1 an avec sous-domaines et préchargement), `SESSION_COOKIE_SECURE=True`, `SESSION_COOKIE_HTTPONLY=True` et `CSRF_COOKIE_SECURE=True` garantissent l'inviolabilité des sessions contre les attaques par écoute et vol de cookies (CWE-614, CWE-1004).

---

## 6. Matrice de conformité avec la Loi 25 du Québec

| Exigence de la Loi 25 | Application dans ShieldNet |
|---|---|
| **Protection dès la conception (Art. 21.4)** | Utilisation exclusive d'empreintes HMAC-SHA256 non réversibles dès la saisie du numéro sur le terminal. |
| **Minimisation des données (Art. 4)** | Aucune lecture ni transfert du carnet de contacts personnels. Seules les données strictement utiles au filtrage sont manipulées. |
| **Droit à l'effacement et rétention limitée** | Commande automatisée de purge (`purge_stale_reports`) supprimant les signalements inactifs au-delà de 90 jours. |
| **Droit de rectification et contestation** | Possibilité pour tout détenteur d'un numéro légitime de soumettre une contestation citoyenne pour réhabiliter son numéro. |
| **Imputabilité et traçabilité** | Journalisation complète et inaltérable des interventions des modérateurs dans la table `AuditLog`. |