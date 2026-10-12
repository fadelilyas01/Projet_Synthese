import json
from django.test import TestCase
from django.urls import reverse
from django.conf import settings
from rest_framework import status
from rest_framework.test import APITestCase, APIClient
from shield_api.models import BlacklistedNumber, SpamReport, SafeReport
from shield_api.services import ReputationService, AutomatedSpamVerifier, FalsePositiveConsensusService
class ReputationServiceTest(TestCase):
    """
    Tests unitaires de l'algorithme de réputation et de modération.
    """
    def test_process_new_report_creation(self):
        phone_hash = "a" * 64
        report = ReputationService.process_new_report(
            phone_hash=phone_hash,
            category='fraud',
            masked_number='+1 819 *** **67'
        )
        self.assertIsNotNone(report)
        self.assertEqual(report.phone_hash, phone_hash)
        
        number_obj = BlacklistedNumber.objects.get(phone_hash=phone_hash)
        self.assertEqual(number_obj.reports_count, 1)
        self.assertTrue(number_obj.risk_score >= 35)

    def test_repetition_increases_risk_score(self):
        phone_hash = "b" * 64
        ReputationService.process_new_report(phone_hash=phone_hash, category='fraud')
        ReputationService.process_new_report(phone_hash=phone_hash, category='fraud')
        
        number_obj = BlacklistedNumber.objects.get(phone_hash=phone_hash)
        self.assertEqual(number_obj.reports_count, 2)
        self.assertTrue(number_obj.risk_score > 35)

    def test_whitelisted_number_stays_unblocked(self):
        phone_hash = "w" * 64
        # L'admin crée ou blanchit le numéro
        number_obj = BlacklistedNumber.objects.create(
            phone_hash=phone_hash,
            category='telemarketing',
            risk_score=0,
            is_blocked=False,
            is_whitelisted=True
        )
        # Un utilisateur tente de le signaler à nouveau
        ReputationService.process_new_report(phone_hash=phone_hash, category='fraud')
        
        number_obj.refresh_from_db()
        self.assertTrue(number_obj.is_whitelisted)
        self.assertFalse(number_obj.is_blocked)
        self.assertEqual(number_obj.risk_score, 0)


class ConsensusFalsePositiveServiceTest(APITestCase):
    """
    Tests exhaustifs du moteur algorithmique de détection automatique des faux positifs par consensualité.
    """
    def setUp(self):
        self.client.credentials(HTTP_X_API_KEY=settings.API_KEY)

    def test_single_safe_report_does_not_reach_quorum(self):
        phone_hash = "1" * 64
        # 1 signalement spam initial
        ReputationService.process_new_report(phone_hash=phone_hash, category='telemarketing')
        
        # 1 seul avis légitime soumis
        report, auto_whitelisted = FalsePositiveConsensusService.register_safe_feedback(
            phone_hash=phone_hash,
            reason='service',
            comment='Numéro officiel d\'un commerce'
        )
        self.assertFalse(auto_whitelisted)
        
        num_obj = BlacklistedNumber.objects.get(phone_hash=phone_hash)
        self.assertFalse(num_obj.is_whitelisted)
        self.assertEqual(num_obj.safe_reports_count, 1)

    def test_automatic_false_positive_detection_by_consensus(self):
        phone_hash = "2" * 64
        # Numéro injustement signalé par 1 personne (ex: livreur ou cabinet médical)
        ReputationService.process_new_report(phone_hash=phone_hash, category='telemarketing', masked_number='+1 819 555 1234')
        num_before = BlacklistedNumber.objects.get(phone_hash=phone_hash)
        self.assertFalse(num_before.is_whitelisted)

        from django.contrib.auth.models import User
        user1 = User.objects.create_user(username='u1@test.com', email='u1@test.com')
        user2 = User.objects.create_user(username='u2@test.com', email='u2@test.com')

        # Premier avis légitime
        FalsePositiveConsensusService.register_safe_feedback(
            phone_hash=phone_hash,
            reason='medical',
            comment='Cabinet médical régional',
            user=user1,
        )

        # Deuxième avis légitime : Quorum atteint et consensus validé
        _, auto_whitelisted = FalsePositiveConsensusService.register_safe_feedback(
            phone_hash=phone_hash,
            reason='service',
            comment='Numéro officiel confirmé',
            user=user2,
        )

        self.assertTrue(auto_whitelisted)
        num_after = BlacklistedNumber.objects.get(phone_hash=phone_hash)
        self.assertTrue(num_after.is_whitelisted)
        self.assertFalse(num_after.is_blocked)
        self.assertEqual(num_after.risk_score, 0)
        self.assertEqual(num_after.whitelist_reason, 'auto_consensus')
        self.assertGreaterEqual(num_after.consensus_score, 0.55)

    def test_admin_safe_feedback_triggers_immediate_consensus(self):
        phone_hash = "3" * 64
        ReputationService.process_new_report(phone_hash=phone_hash, category='fraud')
        
        from django.contrib.auth.models import User
        admin_u = User.objects.create_superuser(username='superadmin_fp', email='superadmin_fp@test.com', password='pwd')

        # Avis d'un administrateur -> Quorum immédiat
        _, auto_whitelisted = FalsePositiveConsensusService.register_safe_feedback(
            phone_hash=phone_hash,
            reason='delivery',
            user=admin_u,
        )
        self.assertTrue(auto_whitelisted)
        num_obj = BlacklistedNumber.objects.get(phone_hash=phone_hash)
        self.assertTrue(num_obj.is_whitelisted)
        self.assertEqual(num_obj.whitelist_reason, 'auto_consensus')

    def test_anti_sybil_duplicate_user_vote_prevention(self):
        phone_hash = "4" * 64
        ReputationService.process_new_report(phone_hash=phone_hash, category='fraud')

        from django.contrib.auth.models import User
        user = User.objects.create_user(username='sybil@test.com', email='sybil@test.com')

        # Même utilisateur tente de voter 5 fois pour gonfler artificiellement le consensus
        for _ in range(5):
            FalsePositiveConsensusService.register_safe_feedback(
                phone_hash=phone_hash,
                reason='service',
                user=user
            )

        # Le nombre d'avis réels dans la BDD pour ce hash doit rester 1
        safe_count = SafeReport.objects.filter(phone_hash=phone_hash).count()
        self.assertEqual(safe_count, 1)

    def test_dynamic_revocation_on_massive_spam_surge(self):
        phone_hash = "5" * 64
        # Initialement réhabilité par consensus
        from django.contrib.auth.models import User
        u1 = User.objects.create_user(username='v1@test.com', email='v1@test.com')
        u2 = User.objects.create_user(username='v2@test.com', email='v2@test.com')

        ReputationService.process_new_report(phone_hash=phone_hash, category='other')
        FalsePositiveConsensusService.register_safe_feedback(phone_hash=phone_hash, reason='personal', user=u1)
        FalsePositiveConsensusService.register_safe_feedback(phone_hash=phone_hash, reason='personal', user=u2)

        num_obj = BlacklistedNumber.objects.get(phone_hash=phone_hash)
        self.assertTrue(num_obj.is_whitelisted)
        self.assertEqual(num_obj.whitelist_reason, 'auto_consensus')

        # Vague massive de nouveaux signalements réels de fraude
        for i in range(10):
            spammer = User.objects.create_user(username=f'victim_{i}@test.com', email=f'victim_{i}@test.com')
            ReputationService.process_new_report(phone_hash=phone_hash, category='financial_scam', user=spammer)

        num_obj.refresh_from_db()
        # Le consensus s'est effondré : le numéro doit être ré-enclenché en liste noire
        self.assertFalse(num_obj.is_whitelisted)
        self.assertTrue(num_obj.is_blocked)
        self.assertNotEqual(num_obj.whitelist_reason, 'auto_consensus')

    def test_submit_safe_report_api(self):
        url = reverse('submit-safe-report')
        phone_hash = "6" * 64
        # Création du numéro dans la base
        ReputationService.process_new_report(phone_hash=phone_hash, category='telemarketing')

        # 1er avis API
        resp1 = self.client.post(url, {
            'phone_hash': phone_hash,
            'reason': 'medical',
            'comment': 'Hôpital local'
        }, format='json')
        self.assertEqual(resp1.status_code, status.HTTP_201_CREATED)
        self.assertFalse(resp1.data['auto_whitelisted'])

        # 2e avis API avec autre adresse IP / utilisateur
        client2 = self.client_class()
        client2.credentials(HTTP_X_API_KEY=settings.API_KEY)
        resp2 = client2.post(url, {
            'phone_hash': phone_hash,
            'reason': 'service',
            'comment': 'Confirmation service public'
        }, format='json', REMOTE_ADDR='198.51.100.2')
        self.assertEqual(resp2.status_code, status.HTTP_201_CREATED)
        self.assertTrue(resp2.data['auto_whitelisted'])
        self.assertTrue(resp2.data['is_whitelisted'])

    def test_consensus_status_and_check_endpoints(self):
        phone_hash = "7" * 64
        ReputationService.process_new_report(phone_hash=phone_hash, category='fraud')

        # GET /api/v1/consensus/<hash>/
        consensus_url = reverse('consensus-status', kwargs={'phone_hash': phone_hash})
        resp = self.client.get(consensus_url)
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertIn('consensus_ratio', resp.data)
        self.assertIn('quorum_met', resp.data)
        self.assertFalse(resp.data['is_false_positive'])

        # GET /api/v1/check/<hash>/
        check_url = reverse('check-number', kwargs={'phone_hash': phone_hash})
        check_resp = self.client.get(check_url)
        self.assertEqual(check_resp.status_code, status.HTTP_200_OK)
        self.assertIn('safe_reports_count', check_resp.data)
        self.assertIn('consensus_score', check_resp.data)

    def test_admin_consensus_audit_api(self):
        from django.contrib.auth.models import User
        from rest_framework_simplejwt.tokens import RefreshToken

        admin_user = User.objects.create_superuser(username='audit_admin', email='audit@test.com', password='pwd')
        token = str(RefreshToken.for_user(admin_user).access_token)
        admin_client = self.client_class()
        admin_client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')

        audit_url = reverse('admin-consensus-audit')
        resp = admin_client.post(audit_url)
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertIn('candidates_audited', resp.data)
        self.assertIn('auto_whitelisted_count', resp.data)

    def test_health_check_endpoint(self):
        url = reverse('health-check')
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(resp.data['status'], 'healthy')
        self.assertEqual(resp.data['components']['database']['status'], 'up')
        self.assertIn('metrics', resp.data['components'])
        self.assertIn('active_blacklist_count', resp.data['components']['metrics'])

    def test_delta_sync_with_since_parameter(self):
        from django.utils import timezone
        now = timezone.now()
        
        # Numéro actif
        BlacklistedNumber.objects.create(
            phone_hash="delta_active" + "0" * 52,
            category='fraud',
            risk_score=80,
            is_blocked=True,
            is_whitelisted=False,
            updated_at=now
        )
        # Faux positif blanchi
        BlacklistedNumber.objects.create(
            phone_hash="delta_removed" + "0" * 51,
            category='service',
            risk_score=0,
            is_blocked=False,
            is_whitelisted=True,
            whitelist_reason='auto_consensus',
            updated_at=now
        )

        url = reverse('blacklist-download')
        past_iso = (now - timezone.timedelta(minutes=5)).isoformat()
        resp = self.client.get(f"{url}?since={past_iso}")
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertIn('active', resp.data)
        self.assertIn('removed', resp.data)
        self.assertIn('sync_timestamp', resp.data)
        self.assertTrue(resp.data['is_delta'])
        self.assertTrue(len(resp.data['active']) >= 1)
        self.assertIn("delta_removed" + "0" * 51, resp.data['removed'])

    def test_audit_logs_recorded_and_listed(self):
        from django.contrib.auth.models import User
        from rest_framework_simplejwt.tokens import RefreshToken
        from shield_api.models import AuditLog

        admin_user = User.objects.create_superuser(username='audit_verifier', email='verifier@test.com', password='pwd')
        token = str(RefreshToken.for_user(admin_user).access_token)
        admin_client = self.client_class()
        admin_client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')

        # Modération d'un numéro
        phone_hash = "audit_hash" + "0" * 54
        BlacklistedNumber.objects.create(phone_hash=phone_hash, category='fraud', risk_score=70)

        mod_url = reverse('admin-moderate')
        mod_resp = admin_client.post(mod_url, {'phone_hash': phone_hash, 'action': 'whitelist'}, format='json')
        self.assertEqual(mod_resp.status_code, status.HTTP_200_OK)

        # Vérification qu'un AuditLog a été créé
        log = AuditLog.objects.filter(target_hash=phone_hash).first()
        self.assertIsNotNone(log)
        self.assertEqual(log.user, admin_user)

        # Consultation de la liste des logs d'audit
        logs_url = reverse('admin-audit-logs')
        logs_resp = admin_client.get(logs_url)
        self.assertEqual(logs_resp.status_code, status.HTTP_200_OK)
        self.assertIn('results', logs_resp.data)
        self.assertGreaterEqual(logs_resp.data['total'], 1)

    def test_sha256_hex_validator_rejects_invalid_hash(self):
        """
        Validation stricte du format hexadécimal SHA-256 (64 caractères).
        Rejette les empreintes trop courtes, trop longues ou contenant des caractères invalides.
        """
        from django.core.exceptions import ValidationError
        from shield_api.models import sha256_validator

        # Empreinte SHA-256 valide (64 caractères hexadécimaux)
        valid_hash = "a" * 64
        sha256_validator(valid_hash)  # Ne doit lever aucune exception

        # Empreintes invalides : longueur incorrecte ou caractères non hexadécimaux
        with self.assertRaises(ValidationError):
            sha256_validator("trop_court")
        with self.assertRaises(ValidationError):
            sha256_validator("g" * 64)  # 'g' n'est pas un caractère hexadécimal
        with self.assertRaises(ValidationError):
            sha256_validator("a" * 65)

    def test_composite_indexes_present_on_models(self):
        """
        Vérifie la présence et la configuration des index composites pour accélérer les requêtes SQL.
        """
        # Index sur la liste noire globale
        bl_indexes = [idx.name for idx in BlacklistedNumber._meta.indexes]
        self.assertIn('idx_bl_active_filter', bl_indexes)
        self.assertIn('idx_bl_updated_at', bl_indexes)
        self.assertIn('idx_bl_hash_blocked', bl_indexes)

        # Index sur les avis de légitimité
        safe_indexes = [idx.name for idx in SafeReport._meta.indexes]
        self.assertIn('idx_safe_hash_created', safe_indexes)

        # Index sur les signalements de spam
        spam_indexes = [idx.name for idx in SpamReport._meta.indexes]
        self.assertIn('idx_spam_hash_created', spam_indexes)


class BloomFilterAndThreatIntelligenceTests(TestCase):
    def setUp(self):
        from shield_api.models import BlacklistedNumber, CategoryChoices
        BlacklistedNumber.objects.create(
            phone_hash='a' * 64,
            masked_number='+1 819 *** **12',
            category=CategoryChoices.FRAUD,
            risk_score=95,
            reports_count=10,
            is_blocked=True,
            is_whitelisted=False,
        )
        BlacklistedNumber.objects.create(
            phone_hash='b' * 64,
            masked_number='+1 514 *** **34',
            category=CategoryChoices.FINANCIAL_SCAM,
            risk_score=75,
            reports_count=5,
            is_blocked=True,
            is_whitelisted=False,
        )
        self.client = APIClient()

    def test_bloom_filter_generation_and_api(self):
        from shield_api.services import BloomFilterService
        payload = BloomFilterService.generate_filter_payload(size_bits=1024, hash_count=3)
        self.assertEqual(payload['format'], 'bloom_filter_v1')
        self.assertEqual(payload['size_bits'], 1024)
        self.assertGreater(payload['entries_count'], 0)
        self.assertTrue(len(payload['bit_array_base64']) > 0)

        response = self.client.get('/api/v1/sync/bloom/')
        self.assertEqual(response.status_code, 200)
        self.assertIn('bit_array_base64', response.data)

    def test_regional_threat_intelligence_service_and_api(self):
        from shield_api.services import RegionalThreatIntelligenceService
        
        # Ajouter un numéro d'Ontario et un numéro de New York
        BlacklistedNumber.objects.create(
            phone_hash="toronto_" + "1" * 56,
            masked_number="+1 416 *** **99",
            category='telemarketing',
            risk_score=75,
            reports_count=12,
            is_blocked=True,
            is_whitelisted=False
        )
        BlacklistedNumber.objects.create(
            phone_hash="newyork_" + "2" * 56,
            masked_number="+1 212 *** **88",
            category='fraud',
            risk_score=90,
            reports_count=25,
            is_blocked=True,
            is_whitelisted=False
        )

        # 1. Sans filtre (toutes les régions)
        report_all = RegionalThreatIntelligenceService.get_regional_threat_report()
        self.assertIn('regions', report_all)
        self.assertGreater(report_all['total_regions_tracked'], 0)
        codes_all = [r['area_code'] for r in report_all['regions']]
        self.assertIn('819', codes_all)
        self.assertIn('416', codes_all)
        self.assertIn('212', codes_all)

        # 2. Avec filtre province='QC' : Uniquement les indicatifs et villes du Québec
        report_qc = RegionalThreatIntelligenceService.get_regional_threat_report(province='QC')
        codes_qc = [r['area_code'] for r in report_qc['regions']]
        self.assertIn('819', codes_qc)
        self.assertNotIn('416', codes_qc)
        self.assertNotIn('212', codes_qc)
        for r in report_qc['regions']:
            self.assertTrue(
                r['area_code'] in RegionalThreatIntelligenceService.QUEBEC_AREA_CODES
                or '(QC)' in r['region_name']
            )

        # 3. Via API GET ?province=QC
        response_qc = self.client.get('/api/v1/threats/regional/?province=QC')
        self.assertEqual(response_qc.status_code, 200)
        resp_codes = [r['area_code'] for r in response_qc.data['regions']]
        self.assertIn('819', resp_codes)
        self.assertNotIn('416', resp_codes)
        self.assertNotIn('212', resp_codes)

        # 4. Via API avec utilisateur authentifié du Québec
        from django.contrib.auth.models import User
        from rest_framework_simplejwt.tokens import RefreshToken
        user_qc = User.objects.create_user('radar_user_qc', 'radar_qc@test.ca', 'pwd')
        user_qc.profile.province_or_state = 'QC'
        user_qc.profile.save()
        token = str(RefreshToken.for_user(user_qc).access_token)
        
        from rest_framework.test import APIClient
        qc_client = APIClient()
        qc_client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')
        res_auth_qc = qc_client.get('/api/v1/threats/regional/')
        self.assertEqual(res_auth_qc.status_code, 200)
        auth_codes = [r['area_code'] for r in res_auth_qc.data['regions']]
        self.assertIn('819', auth_codes)
        self.assertNotIn('416', auth_codes)
        self.assertNotIn('212', auth_codes)


class RegionalComplianceSystemTests(TestCase):
    """
    Tests de validation du système de conformité régionale et des réglementations
    territoriales applicables (Canada / Loi 25 QC / PIPEDA et USA / TCPA / CCPA).
    """

    def setUp(self):
        from django.contrib.auth.models import User
        self.client = APIClient()
        self.admin = User.objects.create_superuser('admin_compliance', 'admin@shieldnet.qc.ca', 'Password123!')
        self.user_qc = User.objects.create_user('user_qc', 'qc@shieldnet.qc.ca', 'Password123!')
        self.user_qc.profile.country = 'CA'
        self.user_qc.profile.province_or_state = 'QC'
        self.user_qc.profile.save()

        self.user_on = User.objects.create_user('user_on', 'on@shieldnet.ca', 'Password123!')
        self.user_on.profile.country = 'CA'
        self.user_on.profile.province_or_state = 'ON'
        self.user_on.profile.save()

        self.user_california = User.objects.create_user('user_cal', 'cal@shieldnet.us', 'Password123!')
        self.user_california.profile.country = 'US'
        self.user_california.profile.province_or_state = 'CA'
        self.user_california.profile.save()

    def test_regional_compliance_service_rules(self):
        from shield_api.services import RegionalComplianceService

        # Test Québec (Loi 25)
        qc_norm = RegionalComplianceService.get_compliance_for_region('CA', 'QC')
        self.assertEqual(qc_norm['norm_key'], 'LOI_25_QC')
        self.assertEqual(qc_norm['data_retention_days'], 30)
        self.assertTrue(qc_norm['strict_consent_required'])
        self.assertIn('Commission d\'accès à l\'information', qc_norm['regulator'])
        numbers_qc = [n['number'] for n in qc_norm['emergency_numbers']]
        self.assertIn('911', numbers_qc)
        self.assertIn('811', numbers_qc)

        # Test Ontario (PIPEDA)
        on_norm = RegionalComplianceService.get_compliance_for_region('CA', 'ON')
        self.assertEqual(on_norm['norm_key'], 'PIPEDA_CASL_CRTC')
        self.assertEqual(on_norm['data_retention_days'], 60)

        # Test Californie (CCPA / TCPA)
        cal_norm = RegionalComplianceService.get_compliance_for_region('US', 'CA')
        self.assertEqual(cal_norm['norm_key'], 'TCPA_CCPA_CALIFORNIA')
        self.assertEqual(cal_norm['data_retention_days'], 45)

        # Test New York (TCPA / TRACED Act)
        ny_norm = RegionalComplianceService.get_compliance_for_region('US', 'NY')
        self.assertEqual(ny_norm['norm_key'], 'TCPA_TRACED_FCC')
        self.assertEqual(ny_norm['data_retention_days'], 60)

    def test_get_available_regions_structure(self):
        from shield_api.services import RegionalComplianceService
        regions = RegionalComplianceService.get_available_regions()
        self.assertIn('countries', regions)
        country_codes = [c['code'] for c in regions['countries']]
        self.assertIn('CA', country_codes)
        self.assertIn('US', country_codes)

        ca_entry = next(c for c in regions['countries'] if c['code'] == 'CA')
        prov_codes = [p['code'] for p in ca_entry['provinces']]
        self.assertIn('QC', prov_codes)
        self.assertIn('ON', prov_codes)

    def test_compliance_api_endpoints(self):
        # GET /api/v1/compliance/norms/?country=CA&province=QC
        res_qc = self.client.get('/api/v1/compliance/norms/?country=CA&province=QC')
        self.assertEqual(res_qc.status_code, 200)
        self.assertEqual(res_qc.data['norm_key'], 'LOI_25_QC')

        # GET /api/v1/compliance/regions/
        res_reg = self.client.get('/api/v1/compliance/regions/')
        self.assertEqual(res_reg.status_code, 200)
        self.assertIn('countries', res_reg.data)

    def test_admin_users_list_and_stats_with_region(self):
        self.client.force_authenticate(user=self.admin)

        # Liste des utilisateurs pour l'admin
        res_users = self.client.get('/api/v1/admin/users/')
        self.assertEqual(res_users.status_code, 200)
        self.assertGreaterEqual(len(res_users.data), 4)

        qc_entry = next(u for u in res_users.data if u['username'] == 'user_qc')
        self.assertEqual(qc_entry['country'], 'CA')
        self.assertEqual(qc_entry['province_or_state'], 'QC')
        self.assertEqual(qc_entry['country_flag'], '🇨🇦')
        self.assertEqual(qc_entry['compliance_norm']['norm_key'], 'LOI_25_QC')

        # Test filtrage par pays
        res_filter_ca = self.client.get('/api/v1/admin/users/?country=CA')
        self.assertEqual(res_filter_ca.status_code, 200)
        for u in res_filter_ca.data:
            self.assertEqual(u['country'], 'CA')

        # Test stats géographiques
        res_stats = self.client.get('/api/v1/admin/stats/')
        self.assertEqual(res_stats.status_code, 200)
        self.assertIn('users_by_country', res_stats.data)
        self.assertIn('users_by_province', res_stats.data)
        self.assertGreater(res_stats.data['users_by_country']['CA'], 0)


