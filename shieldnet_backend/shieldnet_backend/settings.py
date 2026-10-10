import os
import sys
from pathlib import Path
from datetime import timedelta
from dotenv import load_dotenv
from django.core.exceptions import ImproperlyConfigured

BASE_DIR = Path(__file__).resolve().parent.parent

# 1. Détection de l'environnement (séparation stricte dev / staging / prod / test)
IS_TESTING = 'test' in sys.argv or any('test' in arg for arg in sys.argv)
ENVIRONMENT = os.environ.get('DJANGO_ENV', os.environ.get('ENVIRONMENT', 'development')).strip().lower()
IS_PRODUCTION = ENVIRONMENT == 'production'

# Chargement hiérarchique des fichiers d'environnement :
# - En production : charge .env.production en priorité si présent, sinon .env
# - En développement / test : charge .env
env_file_production = BASE_DIR / '.env.production'
env_file_default = BASE_DIR / '.env'
if IS_PRODUCTION and env_file_production.exists():
    load_dotenv(env_file_production)
elif env_file_default.exists():
    load_dotenv(env_file_default)

# 2. Mode Débogage (DEBUG) : Strictement False en production par défaut
if IS_PRODUCTION:
    DEBUG = os.environ.get('DJANGO_DEBUG', 'False').lower() in ('true', '1', 'yes')
    if DEBUG and not IS_TESTING:
        import warnings
        warnings.warn("AVERTISSEMENT SÉCURITÉ CRITIQUE : DJANGO_DEBUG=True en environnement de production !")
else:
    DEBUG = os.environ.get('DJANGO_DEBUG', 'True').lower() in ('true', '1', 'yes')

# 3. SECRETS : Résolution et validation préalable
SECRET_KEY = os.environ.get('SECRET_KEY')
if not SECRET_KEY:
    if DEBUG or IS_TESTING:
        import secrets
        SECRET_KEY = 'dev-ephemeral-' + secrets.token_hex(24)
    else:
        raise ImproperlyConfigured("Variable d'environnement SECRET_KEY obligatoire en production.")

# Sécurité Clé API pour l'application mobile et sel de hachage
API_KEY = os.environ.get('API_KEY')
if not API_KEY:
    if DEBUG or IS_TESTING:
        API_KEY = 'dev-local-api-key-test-do-not-use-in-prod'
    else:
        raise ImproperlyConfigured("Variable d'environnement API_KEY obligatoire en production.")

HASH_SALT = os.environ.get('HASH_SALT')
if not HASH_SALT:
    if DEBUG or IS_TESTING:
        HASH_SALT = 'dev-local-hash-salt-test-do-not-use-in-prod'
    else:
        raise ImproperlyConfigured("Variable d'environnement HASH_SALT obligatoire en production.")

# 4. ALLOWED_HOSTS : Parsing de variable d'environnement & interdiction de '*' en production
raw_hosts = os.environ.get('ALLOWED_HOSTS', '')
if raw_hosts:
    ALLOWED_HOSTS = [h.strip() for h in raw_hosts.split(',') if h.strip()]
elif DEBUG:
    ALLOWED_HOSTS = ['*']
else:
    ALLOWED_HOSTS = ['api.shieldnet.app', 'admin.shieldnet.app', 'localhost', '127.0.0.1']

if not DEBUG and not IS_TESTING:
    if '*' in ALLOWED_HOSTS:
        raise ImproperlyConfigured("ALLOWED_HOSTS ne peut pas contenir le joker '*' en production.")
    if not ALLOWED_HOSTS:
        raise ImproperlyConfigured("ALLOWED_HOSTS obligatoire en production.")

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',

    # Applications tierces
    'rest_framework',
    'corsheaders',
    'drf_spectacular',

    # Applications locales
    'shield_api',
]

MIDDLEWARE = [
    'shieldnet_backend.settings.APIVersionHeaderMiddleware',
    'django.middleware.gzip.GZipMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'shieldnet_backend.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'shieldnet_backend.wsgi.application'

if os.environ.get('POSTGRES_DB'):
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.postgresql',
            'NAME': os.environ.get('POSTGRES_DB', 'shieldnet_db'),
            'USER': os.environ.get('POSTGRES_USER', 'shieldnet_user'),
            'PASSWORD': os.environ.get('POSTGRES_PASSWORD', ''),
            'HOST': os.environ.get('POSTGRES_HOST', 'localhost'),
            'PORT': os.environ.get('POSTGRES_PORT', '5432'),
        }
    }
else:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.sqlite3',
            'NAME': BASE_DIR / 'db.sqlite3',
        }
    }

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

AUTHENTICATION_BACKENDS = [
    'shield_api.backends.EmailOrUsernameModelBackend',
    'django.contrib.auth.backends.ModelBackend',
]

LANGUAGE_CODE = 'fr-ca'
TIME_ZONE = 'America/Toronto'
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

LOGIN_REDIRECT_URL = '/admin/'
LOGIN_URL = '/admin/login/'

# Configuration CORS et CSRF durcie pour la production
if DEBUG:
    cors_raw = os.environ.get('CORS_ALLOWED_ORIGINS', '')
    if cors_raw:
        CORS_ALLOWED_ORIGINS = [o.strip() for o in cors_raw.split(',') if o.strip()]
        CORS_ALLOW_ALL_ORIGINS = False
    else:
        CORS_ALLOW_ALL_ORIGINS = True
else:
    # En production : interdiction absolue de CORS_ALLOW_ALL_ORIGINS
    CORS_ALLOW_ALL_ORIGINS = False
    cors_raw = os.environ.get('CORS_ALLOWED_ORIGINS', '')
    if cors_raw:
        CORS_ALLOWED_ORIGINS = [o.strip() for o in cors_raw.split(',') if o.strip()]
    else:
        CORS_ALLOWED_ORIGINS = [
            'https://admin.shieldnet.app',
            'https://shieldnet.app',
        ]

# Origines de confiance CSRF (obligatoires sous HTTPS pour l'accès web & admin en Django 4+)
csrf_raw = os.environ.get('CSRF_TRUSTED_ORIGINS', '')
if csrf_raw:
    CSRF_TRUSTED_ORIGINS = [o.strip() for o in csrf_raw.split(',') if o.strip()]
elif not DEBUG:
    derived_origins = set(CORS_ALLOWED_ORIGINS)
    for host in ALLOWED_HOSTS:
        if host not in ('*', '127.0.0.1', 'localhost', '10.0.2.2'):
            derived_origins.add(f'https://{host}')
    CSRF_TRUSTED_ORIGINS = sorted(list(derived_origins))
else:
    CSRF_TRUSTED_ORIGINS = ['http://localhost:8000', 'http://127.0.0.1:8000']

# Configuration Django REST Framework, Sécurité & Rate Limiting (Throttling)
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
        'rest_framework.authentication.SessionAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'shield_api.permissions.HasAPIKeyOrAuthenticated',
    ),
    'DEFAULT_THROTTLE_CLASSES': [
        'rest_framework.throttling.AnonRateThrottle',
        'rest_framework.throttling.UserRateThrottle',
    ],
    'DEFAULT_THROTTLE_RATES': {
        'anon': '120/minute',  # Protection contre les attaques DoS / Brute-force
        'user': '600/minute',
    },
    'DEFAULT_SCHEMA_CLASS': 'drf_spectacular.openapi.AutoSchema',
    'EXCEPTION_HANDLER': 'shield_api.exceptions.shieldnet_exception_handler',
}

SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(days=7),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=30),
    'ROTATE_REFRESH_TOKENS': True,
}

SPECTACULAR_SETTINGS = {
    'TITLE': 'ShieldNet API',
    'DESCRIPTION': 'API REST Collaborative pour le filtrage anti-spam d\'appels et SMS',
    'VERSION': '1.0.0',
    'SERVE_INCLUDE_SCHEMA': False,
}


# Caching Configuration (Redis en Production avec Fallback LocMem en Développement)
REDIS_URL = os.environ.get('REDIS_URL', os.environ.get('REDIS_CACHE_URL'))
if REDIS_URL:
    CACHES = {
        'default': {
            'BACKEND': 'django.core.cache.backends.redis.RedisCache',
            'LOCATION': REDIS_URL,
            'KEY_PREFIX': 'shieldnet',
            'TIMEOUT': 300,
        }
    }
else:
    CACHES = {
        'default': {
            'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
            'LOCATION': 'shieldnet-local-cache',
            'TIMEOUT': 300,
        }
    }

# Durcissement TLS / HTTPS et En-têtes de Sécurité HTTP en Production
if not DEBUG:
    # Redirection HTTPS et support des reverse-proxies (Nginx / ALB / Traefik)
    SECURE_SSL_REDIRECT = os.environ.get('SECURE_SSL_REDIRECT', 'True').lower() in ('true', '1', 'yes')
    SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')

    # Protection contre le détournement de clic (Clickjacking) et reniflage MIME
    X_FRAME_OPTIONS = 'DENY'
    SECURE_CONTENT_TYPE_NOSNIFF = True
    SECURE_BROWSER_XSS_FILTER = True
    SECURE_REFERRER_POLICY = 'strict-origin-when-cross-origin'

    # HSTS (HTTP Strict Transport Security) - 1 an minimum + sous-domaines + préchargement
    SECURE_HSTS_SECONDS = int(os.environ.get('SECURE_HSTS_SECONDS', '31536000'))
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True

    # Sécurisation des cookies de session et CSRF
    SESSION_COOKIE_SECURE = True
    SESSION_COOKIE_HTTPONLY = True
    CSRF_COOKIE_SECURE = True
    CSRF_COOKIE_HTTPONLY = False


# Middleware d'en-tête de versioning et d'observabilité
class APIVersionHeaderMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)
        response['X-API-Version'] = '1.0.0'
        return response


# Validation stricte des secrets cryptographiques en production
def _validate_secrets():
    if not DEBUG and not IS_TESTING:
        if len(SECRET_KEY) < 32:
            raise ImproperlyConfigured("SECRET_KEY trop courte en production (minimum 32 caractères).")
        if any(SECRET_KEY.startswith(p) or p in SECRET_KEY for p in ('dev-', 'change-me', 'django-insecure', 'test-')):
            raise ImproperlyConfigured("SECRET_KEY de développement ou insecure détectée en production. Générez une clé aléatoire forte.")
        if len(API_KEY) < 16:
            raise ImproperlyConfigured("API_KEY trop courte en production (minimum 16 caractères).")
        if API_KEY == 'dev-local-api-key-test-do-not-use-in-prod' or 'change-me' in API_KEY:
            raise ImproperlyConfigured("API_KEY de développement par défaut détectée en production.")
        if len(HASH_SALT) < 16:
            raise ImproperlyConfigured("HASH_SALT trop court en production (minimum 16 caractères).")
        if HASH_SALT == 'dev-local-hash-salt-test-do-not-use-in-prod' or 'change-me' in HASH_SALT:
            raise ImproperlyConfigured("HASH_SALT de développement par défaut détecté en production.")

_validate_secrets()

# Configuration de l'envoi de courriels (Courriels de bienvenue et sécurité)
EMAIL_HOST_USER = os.environ.get('EMAIL_HOST_USER', '')
EMAIL_HOST_PASSWORD = os.environ.get('EMAIL_HOST_PASSWORD', '')
if EMAIL_HOST_USER and EMAIL_HOST_PASSWORD:
    EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
else:
    EMAIL_BACKEND = os.environ.get(
        'EMAIL_BACKEND',
        'django.core.mail.backends.console.EmailBackend' if DEBUG else 'django.core.mail.backends.smtp.EmailBackend'
    )
EMAIL_HOST = os.environ.get('EMAIL_HOST', 'smtp.gmail.com')
EMAIL_PORT = int(os.environ.get('EMAIL_PORT', 587))
EMAIL_USE_TLS = os.environ.get('EMAIL_USE_TLS', 'True').lower() in ('true', '1', 'yes')
DEFAULT_FROM_EMAIL = os.environ.get('DEFAULT_FROM_EMAIL') or (f'ShieldNet <{EMAIL_HOST_USER}>' if EMAIL_HOST_USER else 'ShieldNet <no-reply@shieldnet.app>')

# Configuration de Journalisation Centralisée et Observabilité Sécurité (Pillar 8)
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '[{asctime}] [{levelname}] [{name}:{lineno}] {message}',
            'style': '{',
        },
        'simple': {
            'format': '[{levelname}] {message}',
            'style': '{',
        },
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'verbose',
        },
    },
    'loggers': {
        'django': {
            'handlers': ['console'],
            'level': 'INFO',
            'propagate': False,
        },
        'django.security': {
            'handlers': ['console'],
            'level': 'WARNING',
            'propagate': False,
        },
        'shieldnet.security': {
            'handlers': ['console'],
            'level': 'INFO',
            'propagate': False,
        },
        'shield_api': {
            'handlers': ['console'],
            'level': 'INFO',
            'propagate': False,
        },
    },
}
