import json
from django.test import TestCase
from django.urls import reverse
from django.conf import settings
from rest_framework import status
from rest_framework.test import APITestCase, APIClient
from shield_api.models import BlacklistedNumber, SpamReport, SafeReport
from shield_api.services import ReputationService, AutomatedSpamVerifier, FalsePositiveConsensusService
class ShieldApiEndpointsTest(APITestCase):
    """
    Tests d'intégration des endpoints REST API avec authentification X-API-Key.
    """
    def setUp(self):
        self.client.credentials(HTTP_X_API_KEY=settings.API_KEY)

    def test_reject_request_without_api_key(self):
        client = self.client_class()  # Client sans en-tête
        url = reverse('blacklist-download')
        response = client.get(url)
        self.assertIn(response.status_code, [status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN])

    def test_submit_report_api(self):
        url = reverse('submit-report')
        phone_hash = "c" * 64
        data = {
            'phone_hash': phone_hash,
            'masked_number': '+1 819 *** **00',
            'category': 'phishing',
            'comment': 'Test report'
        }
        response = self.client.post(url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['phone_hash'], phone_hash)

    def test_check_number_api_spam(self):
        phone_hash = "d" * 64
        BlacklistedNumber.objects.create(
            phone_hash=phone_hash,
            category='fraud',
            risk_score=80,
            reports_count=3,
            is_blocked=True
        )
        url = reverse('check-number', kwargs={'phone_hash': phone_hash})
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['is_spam'])
        self.assertEqual(response.data['risk_score'], 80)

    def test_blacklist_download_api(self):
        BlacklistedNumber.objects.create(
            phone_hash="e" * 64,
            category='telemarketing',
            risk_score=50,
            reports_count=2,
            is_blocked=True
        )
        url = reverse('blacklist-download')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(len(response.data) >= 1)

    def test_user_registration_and_email_login(self):
        # Création d'un nouveau compte citoyen
        register_url = reverse('auth-register')
        reg_data = {
            'email': 'utilisateur@shieldnet.app',
            'password': 'Password123!',
            'name': 'Jean Dupont'
        }
        reg_resp = self.client.post(register_url, reg_data, format='json')
        self.assertEqual(reg_resp.status_code, status.HTTP_201_CREATED)
        self.assertIn('tokens', reg_resp.data)
        self.assertEqual(reg_resp.data['user']['email'], 'utilisateur@shieldnet.app')

        # Authentification par mot de passe
        login_url = reverse('auth-login')
        login_data = {
            'email': 'utilisateur@shieldnet.app',
            'password': 'Password123!'
        }
        login_resp = self.client.post(login_url, login_data, format='json')
        self.assertEqual(login_resp.status_code, status.HTTP_200_OK)
        access_token = login_resp.data['tokens']['access']
        self.assertIsNotNone(access_token)

        # Vérification du jeton JWT sur le profil connecté
        auth_client = self.client_class()
        auth_client.credentials(HTTP_AUTHORIZATION=f'Bearer {access_token}')
        me_url = reverse('auth-me')
        me_resp = auth_client.get(me_url)
        self.assertEqual(me_resp.status_code, status.HTTP_200_OK)
        self.assertEqual(me_resp.data['email'], 'utilisateur@shieldnet.app')
        self.assertFalse(me_resp.data['is_staff'])

    def test_google_login_auto_provision_and_repeat(self):
        url = reverse('auth-google')
        google_data = {
            'email': 'google.user@shieldnet.app',
            'name': 'Google Test User'
        }
        # Première authentification : auto-provisioning du compte
        resp1 = self.client.post(url, google_data, format='json')
        self.assertEqual(resp1.status_code, status.HTTP_200_OK)
        self.assertEqual(resp1.data['user']['email'], 'google.user@shieldnet.app')
        self.assertIn('tokens', resp1.data)
        self.assertIsNotNone(resp1.data['tokens']['access'])

        # Connexions ultérieures : réutilisation immédiate du profil existant
        resp2 = self.client.post(url, google_data, format='json')
        self.assertEqual(resp2.status_code, status.HTTP_200_OK)
        self.assertEqual(resp2.data['user']['email'], 'google.user@shieldnet.app')
        self.assertIn('tokens', resp2.data)

    def test_admin_stats_and_moderation(self):
        from django.contrib.auth.models import User
        # Profils de test avec et sans privilèges
        std_user = User.objects.create_user(username='std@user.com', email='std@user.com', password='password')
        admin_user = User.objects.create_user(username='admin', email='admin@shieldnet.qc.ca', password='password', is_staff=True)

        # Création d'une entrée test
        phone_hash = "f" * 64
        BlacklistedNumber.objects.create(
            phone_hash=phone_hash,
            category='fraud',
            risk_score=60,
            is_blocked=True
        )

        from rest_framework_simplejwt.tokens import RefreshToken
        std_token = str(RefreshToken.for_user(std_user).access_token)
        admin_token = str(RefreshToken.for_user(admin_user).access_token)

        # Contrôle d'accès : rejet des utilisateurs non-administrateurs (403)
        std_client = self.client_class()
        std_client.credentials(HTTP_AUTHORIZATION=f'Bearer {std_token}')
        stats_url = reverse('admin-stats')
        resp_std = std_client.get(stats_url)
        self.assertEqual(resp_std.status_code, status.HTTP_403_FORBIDDEN)

        # Accès accordé pour l'administrateur avec les métriques SOC
        admin_client = self.client_class()
        admin_client.credentials(HTTP_AUTHORIZATION=f'Bearer {admin_token}')
        resp_admin = admin_client.get(stats_url)
        self.assertEqual(resp_admin.status_code, status.HTTP_200_OK)
        self.assertIn('total_blacklisted', resp_admin.data)
        self.assertIn('total_blocked', resp_admin.data)
        self.assertIn('recent_reports', resp_admin.data)
        self.assertIn('active_users', resp_admin.data)
        self.assertIn('filtered_calls_count', resp_admin.data)
        self.assertIn('false_positives_prevented', resp_admin.data)
        self.assertIn('daily_trends', resp_admin.data)
        self.assertIn('fraud_categories', resp_admin.data)

        # Action de modération : réhabilitation explicite d'un numéro
        mod_url = reverse('admin-moderate')
        mod_resp = admin_client.post(mod_url, {'phone_hash': phone_hash, 'action': 'whitelist'}, format='json')
        self.assertEqual(mod_resp.status_code, status.HTTP_200_OK)

        num_refreshed = BlacklistedNumber.objects.get(phone_hash=phone_hash)
        self.assertTrue(num_refreshed.is_whitelisted)
        self.assertFalse(num_refreshed.is_blocked)

    def test_dedicated_admin_email_login_web_and_mobile(self):
        from django.contrib.auth.models import User
        from django.contrib.auth import authenticate

        # Compte superutilisateur configuré
        admin_email = 'admin@shieldnet.app'
        admin_pass = 'AdminPassword2026!'
        User.objects.create_superuser(
            username='admin_dedicated',
            email=admin_email,
            password=admin_pass
        )

        # Connexion Django Admin standard via courriel
        web_user = authenticate(username=admin_email, password=admin_pass)
        self.assertIsNotNone(web_user)
        self.assertEqual(web_user.email, admin_email)
        self.assertTrue(web_user.is_staff)
        self.assertTrue(web_user.is_superuser)

        # Authentification JWT via l'API mobile
        login_url = reverse('auth-login')
        resp = self.client.post(login_url, {'email': admin_email, 'password': admin_pass}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertTrue(resp.data['user']['is_staff'])
        self.assertTrue(resp.data['user']['is_superuser'])
        self.assertIn('tokens', resp.data)

    def test_admin_full_mobile_management_endpoints(self):
        from django.contrib.auth.models import User
        from rest_framework_simplejwt.tokens import RefreshToken

        # Création de l'administrateur
        admin_user = User.objects.create_superuser(
            username='admin_mobile_test',
            email='admin_mobile@shieldnet.app',
            password='AdminPassword2026!'
        )
        token = str(RefreshToken.for_user(admin_user).access_token)
        admin_client = self.client_class()
        admin_client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')

        # Ajout manuel direct d'une entrée par un administrateur
        add_url = reverse('admin-blacklist')
        add_resp = admin_client.post(add_url, {
            'phone_number': '+1 819 555 9999',
            'category': 'fraud',
            'risk_score': 90,
            'is_blocked': True,
            'is_whitelisted': False,
        }, format='json')
        self.assertEqual(add_resp.status_code, status.HTTP_201_CREATED)
        phone_hash = add_resp.data['phone_hash']

        # Consultation et pagination de la liste noire
        list_resp = admin_client.get(add_url)
        self.assertEqual(list_resp.status_code, status.HTTP_200_OK)
        self.assertTrue(len(list_resp.data) >= 1)

        # Liste des comptes utilisateurs enregistrés
        users_url = reverse('admin-users')
        users_resp = admin_client.get(users_url)
        self.assertEqual(users_resp.status_code, status.HTTP_200_OK)
        self.assertTrue(len(users_resp.data) >= 1)

        # Consultation des signalements citoyens
        reports_url = reverse('admin-reports')
        rep_resp = admin_client.get(reports_url)
        self.assertEqual(rep_resp.status_code, status.HTTP_200_OK)

        # Déclenchement de la purge de maintenance
        purge_url = reverse('admin-purge')
        purge_resp = admin_client.post(purge_url)
        self.assertEqual(purge_resp.status_code, status.HTTP_200_OK)
        self.assertIn('purged_count', purge_resp.data)

        # Suppression définitive d'un numéro
        del_url = reverse('admin-blacklist-detail', kwargs={'phone_hash': phone_hash})
        del_resp = admin_client.delete(del_url)
        self.assertEqual(del_resp.status_code, status.HTTP_200_OK)
        self.assertFalse(BlacklistedNumber.objects.filter(phone_hash=phone_hash).exists())


class HelpCenterPublicViewTests(TestCase):
    """
    Tests de la page publique Centre d'Aide & FAQ (Web + Mobile).
    """
    def test_help_center_rendering(self):
        resp = self.client.get('/help/')
        self.assertEqual(resp.status_code, 200)
        self.assertContains(resp, "Centre d'Assistance & FAQ")
        self.assertContains(resp, "CallScreeningService")
        self.assertContains(resp, "Zéro-Connaissance")

    def test_faq_alias_rendering(self):
        resp = self.client.get('/faq/')
        self.assertEqual(resp.status_code, 200)
        self.assertContains(resp, "Centre d'Assistance & FAQ")
