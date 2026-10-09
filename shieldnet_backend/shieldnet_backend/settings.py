import os
from pathlib import Path
from datetime import timedelta
from dotenv import load_dotenv
from django.core.exceptions import ImproperlyConfigured

BASE_DIR = Path(__file__).resolve().parent.parent

# Chargement du fichier d'environnement .env
load_dotenv(BASE_DIR / '.env')

DEBUG = os.environ.get('DJANGO_DEBUG', 'False').lower() in ('true', '1', 'yes')

SECRET_KEY = os.environ.get('SECRET_KEY')
if not SECRET_KEY:
    if DEBUG:
        import secrets
        SECRET_KEY = 'dev-ephemeral-' + secrets.token_hex(24)
    else:
        raise ImproperlyConfigured("Variable d'environnement SECRET_KEY obligatoire en production.")

ALLOWED_HOSTS = ['*'] if DEBUG else ['api.shieldnet.app', 'localhost', '127.0.0.1', '10.0.2.2']

# Sécurité Clé API pour l'application mobile et sel de hachage
API_KEY = os.environ.get('API_KEY')
if not API_KEY:
    if DEBUG:
        API_KEY = 'dev-local-api-key-test-do-not-use-in-prod'
    else:
        raise ImproperlyConfigured("Variable d'environnement API_KEY obligatoire en production.")

HASH_SALT = os.environ.get('HASH_SALT')
if not HASH_SALT:
    if DEBUG:
        HASH_SALT = 'dev-local-hash-salt-test-do-not-use-in-prod'
    else:
        raise ImproperlyConfigured("Variable d'environnement HASH_SALT obligatoire en production.")

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

# Configuration CORS pour autoriser l'application mobile Flutter et les tests locaux
CORS_ALLOW_ALL_ORIGINS = DEBUG
if not CORS_ALLOW_ALL_ORIGINS:
    CORS_ALLOWED_ORIGINS = ['https://admin.shieldnet.app']

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

# Durcissement des En-têtes de Sécurité HTTP en Production
if not DEBUG:
    SECURE_BROWSER_XSS_FILTER = True
    SECURE_CONTENT_TYPE_NOSNIFF = True
    X_FRAME_OPTIONS = 'DENY'
    SECURE_HSTS_SECONDS = 31536000  # 1 an
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True


# Middleware d'en-tête de versioning et d'observabilité
class APIVersionHeaderMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)
        response['X-API-Version'] = '1.0.0'
        return response


# Validation stricte de longueur minimale des secrets cryptographiques
def _validate_secrets():
    if not DEBUG:
        if len(SECRET_KEY) < 32:
            raise ImproperlyConfigured("SECRET_KEY trop courte en production (minimum 32 caractères).")
        if len(API_KEY) < 16:
            raise ImproperlyConfigured("API_KEY trop courte en production (minimum 16 caractères).")
        if len(HASH_SALT) < 16:
            raise ImproperlyConfigured("HASH_SALT trop court en production (minimum 16 caractères).")

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
DEFAULT_FROM_EMAIL = os.environ.get('DEFAULT_FROM_EMAIL') or (f'ShieldNet Security <{EMAIL_HOST_USER}>' if EMAIL_HOST_USER else 'ShieldNet Security <no-reply@shieldnet.app>')
