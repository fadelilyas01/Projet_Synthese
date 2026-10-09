from django.contrib import admin
from django.urls import path, include
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView
from shield_api.public_views import help_center_view, app_launch_view

from shield_api.admin_views import (
    sandbox_check_view,
    sandbox_action_view,
    export_blacklist_csv_view,
    trigger_consensus_view,
    trigger_purge_view,
    triage_action_view,
    telemetry_live_view,
    executive_report_view,
    admin_triage_dashboard_view,
    admin_sandbox_dashboard_view,
)

urlpatterns = [
    # OpÃ©rations & Outils AvancÃ©s de la Console Web SOC
    path('admin/operations/triage/', admin_triage_dashboard_view, name='admin-triage-dashboard'),
    path('admin/operations/sandbox/', admin_sandbox_dashboard_view, name='admin-sandbox-dashboard'),
    path('admin/operations/sandbox/check/', sandbox_check_view, name='admin-sandbox-check'),
    path('admin/operations/sandbox/action/', sandbox_action_view, name='admin-sandbox-action'),
    path('admin/operations/export/csv/', export_blacklist_csv_view, name='admin-export-csv'),
    path('admin/operations/consensus/', trigger_consensus_view, name='admin-trigger-consensus'),
    path('admin/operations/purge/', trigger_purge_view, name='admin-trigger-purge'),
    path('admin/operations/triage/action/', triage_action_view, name='admin-triage-action'),
    path('admin/operations/telemetry/live/', telemetry_live_view, name='admin-telemetry-live'),
    path('admin/operations/report/executive/', executive_report_view, name='admin-report-executive'),

    # Centre d'Aide & FAQ Public (Web & Mobile)
    path('', help_center_view, name='home'),
    path('help/', help_center_view, name='help-center'),
    path('faq/', help_center_view, name='faq-center'),
    path('open/', app_launch_view, name='app-open'),
    path('app/', app_launch_view, name='app-launch'),

    # Administration Django Admin
    path('admin/', admin.site.urls),

    # Endpoints REST API v1
    path('api/v1/', include('shield_api.urls')),

    # Authentification JWT
    path('api/v1/auth/token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/v1/auth/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),

    # Documentation Swagger OpenAPI 3.0
    path('api/v1/schema/', SpectacularAPIView.as_view(), name='schema'),
    path('api/v1/docs/', SpectacularSwaggerView.as_view(url_name='schema'), name='swagger-ui'),
]

from django.conf import settings
from django.contrib.staticfiles.urls import staticfiles_urlpatterns

if settings.DEBUG:
    urlpatterns += staticfiles_urlpatterns()

