import logging
from rest_framework.views import exception_handler
from rest_framework.response import Response
from django.utils import timezone
from django.conf import settings

logger = logging.getLogger('shieldnet.security')

def shieldnet_exception_handler(exc, context):
    response = exception_handler(exc, context)
    request = context.get('request')
    path = request.path if request else ''

    if response is not None:
        status_code = response.status_code
        detail = response.data.get('detail', str(response.data)) if isinstance(response.data, dict) else str(response.data)
        code_str = getattr(exc, 'default_code', 'error')
        if status_code == 401:
            code_str = 'unauthorized'
        elif status_code == 403:
            code_str = 'permission_denied'
        elif status_code == 404:
            code_str = 'not_found'
        elif status_code == 429:
            code_str = 'rate_limited'
            logger.warning(f"[RateLimit] Débit excessif détecté sur {path}")

        response.data = {
            'error': str(detail),
            'code': str(code_str),
            'detail': str(detail),
            'timestamp': timezone.now().isoformat(),
            'path': path
        }
    else:
        # Journalisation des incidents critiques (500)
        logger.error(f"[Critical 500] Erreur non gérée sur {path}: {exc}", exc_info=True)
        if not getattr(settings, 'DEBUG', False):
            response = Response({
                'error': 'Une erreur interne temporaire est survenue.',
                'code': 'internal_server_error',
                'detail': 'Erreur interne du serveur.',
                'timestamp': timezone.now().isoformat(),
                'path': path
            }, status=500)
    return response
