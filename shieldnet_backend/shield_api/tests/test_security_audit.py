"""
Tests de Validation & d'Epreuve de Robustesse de l'Audit de Securite ShieldNet
Verifie rigoureusement les contre-mesures appliquees et leur resistance aux cas limites :
1. Protection anti-Confused Deputy (Google OAuth mono et multi-client)
2. Securisation des metriques Prometheus, invalidation par signaux et mitigation DoS
3. Protection anti-bombardement de courriels (Email Bombing / CWE-307) avec neutralisation de l'evasion par points/tags Gmail
4. Anonymisation et masquage des adresses courriel (Loi 25) avec immunite contre les entrees corrompues
"""
from unittest.mock import patch, MagicMock
from django.contrib.auth.models import User
from django.core.cache import cache
from django.test import TestCase, override_settings
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase
from shield_api.models import SafeReport
from shield_api.services import mask_email, get_canonical_email
from shield_api.views import verify_google_id_token


class SecurityAuditHardeningTests(APITestCase):

    def setUp(self):
        cache.clear()
        self.staff_user = User.objects.create_user(
            username='soc_analyst',
            email='analyst@shieldnet.app',
            password='StrongPassword123!',
            is_staff=True
        )
        self.citizen_user = User.objects.create_user(
            username='citizen_user',
            email='citizen@example.com',
            password='CitizenPassword123!'
        )

    def tearDown(self):
        cache.clear()

    # --- 1. Conformite Loi 25 & Robustesse aux entrees corrompues ---
    def test_mask_email_law_25_compliance(self):
        self.assertEqual(mask_email('jean.tremblay@gouv.qc.ca'), 'j***y@gouv.qc.ca')
        self.assertEqual(mask_email('al@domain.com'), 'a***@domain.com')
        self.assertEqual(mask_email('a@b.com'), 'a***@b.com')
        self.assertEqual(mask_email(''), 'Anonyme')
        self.assertEqual(mask_email(None), 'Anonyme')
        self.assertEqual(mask_email('invalid-email'), 'Anonyme')

    def test_mask_email_corrupted_inputs_do_not_crash(self):
        # Resistance aux injections et adresses tronquees (evite 500 Internal Server Error)
        self.assertEqual(mask_email('@domain.com'), 'Anonyme')
        self.assertEqual(mask_email('user@'), 'Anonyme')
        self.assertEqual(mask_email('@'), 'Anonyme')
        self.assertEqual(mask_email('   '), 'Anonyme')
        self.assertEqual(mask_email(12345), 'Anonyme')
        self.assertEqual(mask_email({'email': 'test@test.com'}), 'Anonyme')

    # --- 2. Securite Google OAuth : Anti-Confused Deputy (CWE-287) ---
    @patch('urllib.request.urlopen')
    def test_verify_google_token_rejects_mismatched_audience(self, mock_urlopen):
        mock_resp = MagicMock()
        mock_resp.read.return_value = b'{"aud": "malicious-app-id.apps.googleusercontent.com", "email": "victim@gmail.com"}'
        mock_resp.__enter__.return_value = mock_resp
        mock_urlopen.return_value = mock_resp

        with override_settings(GOOGLE_CLIENT_ID='shieldnet-legit-client-id.apps.googleusercontent.com', IS_TESTING=False):
            result = verify_google_id_token('fake-sample-google-id-token')
            self.assertIsNone(result)

    @patch('urllib.request.urlopen')
    def test_verify_google_token_accepts_valid_matching_audience(self, mock_urlopen):
        expected_client_id = 'shieldnet-legit-client-id.apps.googleusercontent.com'
        mock_resp = MagicMock()
        mock_resp.read.return_value = f'{{"aud": "{expected_client_id}", "email": "legit@gmail.com", "email_verified": true}}'.encode('utf-8')
        mock_resp.__enter__.return_value = mock_resp
        mock_urlopen.return_value = mock_resp

        with override_settings(GOOGLE_CLIENT_ID=expected_client_id, IS_TESTING=False):
            result = verify_google_id_token('fake-sample-google-id-token')
            self.assertIsNotNone(result)
            self.assertEqual(result.get('email'), 'legit@gmail.com')

    @patch('urllib.request.urlopen')
    def test_verify_google_token_supports_multi_client_ids(self, mock_urlopen):
        web_id = 'web-client.apps.googleusercontent.com'
        android_id = 'android-client.apps.googleusercontent.com'
        mock_resp = MagicMock()
        mock_resp.read.return_value = f'{{"aud": "{android_id}", "email": "android.user@gmail.com"}}'.encode('utf-8')
        mock_resp.__enter__.return_value = mock_resp
        mock_urlopen.return_value = mock_resp

        with override_settings(GOOGLE_CLIENT_ID=f'{web_id}, {android_id}', IS_TESTING=False):
            result = verify_google_id_token('valid-android-token')
            self.assertIsNotNone(result)
            self.assertEqual(result.get('email'), 'android.user@gmail.com')

    @patch('urllib.request.urlopen')
    def test_verify_google_token_handles_google_errors_and_non_dicts(self, mock_urlopen):
        mock_resp = MagicMock()
        mock_resp.read.return_value = b'{"error": "invalid_token", "error_description": "Token expired"}'
        mock_resp.__enter__.return_value = mock_resp
        mock_urlopen.return_value = mock_resp

        with override_settings(GOOGLE_CLIENT_ID='some-id.apps.googleusercontent.com', IS_TESTING=False):
            self.assertIsNone(verify_google_id_token('expired-token'))

    # --- 3. Protection Observabilite Prometheus & Mitigation DoS ---
    def test_prometheus_metrics_rejects_when_token_configured_and_invalid(self):
        url = reverse('prometheus-metrics')
        with override_settings(PROMETHEUS_METRICS_TOKEN='secret-token-xyz'):
            resp1 = self.client.get(url)
            self.assertIn(resp1.status_code, [status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN])

            resp2 = self.client.get(url, HTTP_X_PROMETHEUS_TOKEN='wrong-token')
            self.assertIn(resp2.status_code, [status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN])

    def test_prometheus_metrics_rejects_in_production_mode_without_auth(self):
        url = reverse('prometheus-metrics')
        with override_settings(PROMETHEUS_METRICS_REQUIRE_AUTH=True, IS_TESTING=False, DEBUG=False):
            resp = self.client.get(url)
            self.assertIn(resp.status_code, [status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN])

    def test_prometheus_metrics_allows_staff_user_and_caches_result(self):
        url = reverse('prometheus-metrics')
        self.client.force_authenticate(user=self.staff_user)
        resp1 = self.client.get(url)
        self.assertEqual(resp1.status_code, status.HTTP_200_OK)
        self.assertIn("shieldnet_blacklist_active_total", resp1.content.decode('utf-8'))

        cached = cache.get('shieldnet_prometheus_metrics_cache')
        self.assertIsNotNone(cached)
        self.assertIn("shieldnet_blacklist_active_total", cached)

    def test_prometheus_metrics_allows_secret_collector_token(self):
        url = reverse('prometheus-metrics')
        collector_token = 'prom-secure-scraper-token-xyz987'
        with override_settings(PROMETHEUS_METRICS_TOKEN=collector_token):
            resp = self.client.get(url, HTTP_X_PROMETHEUS_TOKEN=collector_token)
            self.assertEqual(resp.status_code, status.HTTP_200_OK)

    def test_safe_report_signal_invalidates_metrics_cache(self):
        cache.set('shieldnet_prometheus_metrics_cache', 'stale_metrics_data', timeout=30)
        # Creation d'un avis legitime
        SafeReport.objects.create(
            phone_hash='d' * 64,
            reason='medical',
            comment='Clinique sante'
        )
        self.assertIsNone(cache.get('shieldnet_prometheus_metrics_cache'))

    # --- 4. Protection Anti-Bombardement de courriels (Email Bombing / CWE-307) ---
    def test_email_otp_enforces_cooldown_and_hourly_limit(self):
        url = reverse('auth-send-otp')
        target_email = 'target.victim@gmail.com'

        # Premier envoi : succes 200 OK
        resp1 = self.client.post(url, {'email': target_email, 'enforce_otp_ratelimit': True}, format='json')
        self.assertEqual(resp1.status_code, status.HTTP_200_OK)

        # Deuxieme envoi immediat pour la meme adresse : bloque 429 Too Many Requests
        resp2 = self.client.post(url, {'email': target_email, 'enforce_otp_ratelimit': True}, format='json')
        self.assertEqual(resp2.status_code, status.HTTP_429_TOO_MANY_REQUESTS)
        self.assertIn("patienter 60 secondes", resp2.data.get('detail', ''))

        # Simulation de depassement de quota horaire (5 par heure)
        canonical = get_canonical_email(target_email)
        cache.delete(f'otp_cooldown_{canonical}')
        cache.set(f'otp_hourly_count_{canonical}', 5, timeout=3600)

        resp3 = self.client.post(url, {'email': target_email, 'enforce_otp_ratelimit': True}, format='json')
        self.assertEqual(resp3.status_code, status.HTTP_429_TOO_MANY_REQUESTS)
        self.assertIn("Nombre maximal de tentatives", resp3.data.get('detail', ''))

    def test_email_otp_rate_limit_neutralizes_gmail_dot_and_plus_evasion(self):
        url = reverse('auth-send-otp')
        base_email = 'shieldnet.target@gmail.com'

        # Premier envoi : 200 OK
        resp1 = self.client.post(url, {'email': base_email, 'enforce_otp_ratelimit': True}, format='json')
        self.assertEqual(resp1.status_code, status.HTTP_200_OK)

        # Tentative d'evasion en inserant des points dans le compte Gmail (ex: s.h.i.e.l.d.n.e.t.target@gmail.com)
        resp_evasion_dots = self.client.post(url, {'email': 's.h.i.e.l.d.n.e.t.target@gmail.com', 'enforce_otp_ratelimit': True}, format='json')
        self.assertEqual(resp_evasion_dots.status_code, status.HTTP_429_TOO_MANY_REQUESTS)

        # Tentative d'evasion par sous-adressage (+alias) (ex: shieldnet.target+spamattack@gmail.com)
        resp_evasion_plus = self.client.post(url, {'email': 'shieldnet.target+spamattack@gmail.com', 'enforce_otp_ratelimit': True}, format='json')
        self.assertEqual(resp_evasion_plus.status_code, status.HTTP_429_TOO_MANY_REQUESTS)
