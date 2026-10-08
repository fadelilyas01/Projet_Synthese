from django.urls import register_converter
from django.urls import path
from .views import (
    BloomFilterDownloadView,
    RegionalThreatsView,
    SyncStatusView,
    AdminAuditLogsListView,
    BlacklistDownloadView,
    SubmitReportView,
    CheckNumberView,
    RegisterView,
    EmailLoginView,
    GoogleLoginView,
    UserProfileView,
    UpdateUserRegionView,
    AdminStatsView,
    AdminModerateView,
    AdminBlacklistManagerView,
    AdminBlacklistDetailView,
    AdminUsersListView,
    AdminReportsListView,
    AdminReportDetailView,
    AdminPurgeJunkView,
    SubmitSafeReportView,
    ConsensusStatusView,
    AdminConsensusAuditView,
    AdminSafeReportsListView,
    HealthCheckView,
    HealthLiveView,
    HealthReadyView,
    AIDiagnoseView,
    BatchCheckNumberView,
    PrometheusMetricsView,
    RegionalComplianceNormsView,
    RegionalComplianceRegionsView,
)


class HexHashConverter:
    regex = r'[0-9a-fA-F]{64}'
    def to_python(self, value):
        return value.lower()
    def to_url(self, value):
        return value.lower()

register_converter(HexHashConverter, 'hex_hash')

urlpatterns = [
    path('metrics/', PrometheusMetricsView.as_view(), name='prometheus-metrics'),
    path('ai/diagnose/', AIDiagnoseView.as_view(), name='ai-diagnose'),
    path('health/', HealthCheckView.as_view(), name='health-check'),
    path('health/live/', HealthLiveView.as_view(), name='health-live'),
    path('health/ready/', HealthReadyView.as_view(), name='health-ready'),
    path('compliance/norms/', RegionalComplianceNormsView.as_view(), name='compliance-norms'),
    path('compliance/regions/', RegionalComplianceRegionsView.as_view(), name='compliance-regions'),
    path('sync/bloom/', BloomFilterDownloadView.as_view(), name='sync-bloom'),
    path('threats/regional/', RegionalThreatsView.as_view(), name='threats-regional'),
    path('sync/status/', SyncStatusView.as_view(), name='sync-status'),
    path('blacklist/', BlacklistDownloadView.as_view(), name='blacklist-download'),
    path('reports/', SubmitReportView.as_view(), name='submit-report'),
    path('reports/safe/', SubmitSafeReportView.as_view(), name='submit-safe-report'),
    path('check/batch/', BatchCheckNumberView.as_view(), name='batch-check-number'),
    path('check/<hex_hash:phone_hash>/', CheckNumberView.as_view(), name='check-number'),
    path('consensus/<hex_hash:phone_hash>/', ConsensusStatusView.as_view(), name='consensus-status'),
    path('auth/register/', RegisterView.as_view(), name='auth-register'),
    path('auth/login/', EmailLoginView.as_view(), name='auth-login'),
    path('auth/google/', GoogleLoginView.as_view(), name='auth-google'),
    path('auth/me/', UserProfileView.as_view(), name='auth-me'),
    path('auth/region/', UpdateUserRegionView.as_view(), name='auth-region'),
    path('admin/stats/', AdminStatsView.as_view(), name='admin-stats'),
    path('admin/moderate/', AdminModerateView.as_view(), name='admin-moderate'),
    path('admin/blacklist/', AdminBlacklistManagerView.as_view(), name='admin-blacklist'),
    path('admin/blacklist/<str:phone_hash>/', AdminBlacklistDetailView.as_view(), name='admin-blacklist-detail'),
    path('admin/users/', AdminUsersListView.as_view(), name='admin-users'),
    path('admin/reports/', AdminReportsListView.as_view(), name='admin-reports'),
    path('admin/reports/<str:report_id>/', AdminReportDetailView.as_view(), name='admin-reports-detail'),
    path('admin/safe-reports/', AdminSafeReportsListView.as_view(), name='admin-safe-reports'),
    path('admin/consensus-audit/', AdminConsensusAuditView.as_view(), name='admin-consensus-audit'),
    path('admin/purge/', AdminPurgeJunkView.as_view(), name='admin-purge'),
    path('admin/audit-logs/', AdminAuditLogsListView.as_view(), name='admin-audit-logs'),
]

