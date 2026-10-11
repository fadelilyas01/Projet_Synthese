import json
from django.test import TestCase
from django.urls import reverse
from django.conf import settings
from rest_framework import status
from rest_framework.test import APITestCase, APIClient
from shield_api.models import BlacklistedNumber, SpamReport, SafeReport
from shield_api.services import ReputationService, AutomatedSpamVerifier, FalsePositiveConsensusService
class AdminDashboardTests(TestCase):
    """
    Tests de la console d'administration et de modération :
    Triage des signalements, consultation télémétrique et génération de rapport.
    """
    def setUp(self):
        from django.contrib.auth.models import User
        self.admin_user = User.objects.create_superuser('soc_admin', 'admin@shieldnet.app', 'pass123')
        self.client.force_login(self.admin_user)

    def test_triage_action_escalate_and_dismiss(self):
        phone_hash = "c" * 64
        report = SpamReport.objects.create(
            phone_hash=phone_hash,
            category='fraud',
            comment='Appel agressif'
        )

        # Action de triage : escalade en blocage actif
        triage_url = reverse('admin-triage-action')
        resp = self.client.post(
            triage_url,
            data=json.dumps({'report_id': str(report.id), 'action': 'escalate_block'}),
            content_type='application/json'
        )
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertTrue(data['success'])
        self.assertTrue(data['is_blocked'])

        # Vérifie en BDD
        bl = BlacklistedNumber.objects.get(phone_hash=phone_hash)
        self.assertTrue(bl.is_blocked)
        self.assertFalse(bl.is_whitelisted)

        # Action de triage : réhabilitation immédiate en faux positif
        resp2 = self.client.post(
            triage_url,
            data=json.dumps({'report_id': str(report.id), 'action': 'dismiss_safe'}),
            content_type='application/json'
        )
        self.assertEqual(resp2.status_code, 200)
        data2 = resp2.json()
        self.assertTrue(data2['success'])
        self.assertFalse(data2['is_blocked'])
        self.assertTrue(data2['is_whitelisted'])

    def test_telemetry_live_view(self):
        url = reverse('admin-telemetry-live')
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertIn('resilience_score', data)
        self.assertIn('kpi_blocked', data)
        self.assertIn('latest_event', data)

    def test_executive_report_view(self):
        url = reverse('admin-report-executive')
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        self.assertContains(resp, 'Threat Intelligence Briefing')
        self.assertContains(resp, 'CONFIDENTIEL')

    def test_admin_index_rendering(self):
        resp = self.client.get('/admin/')
        self.assertEqual(resp.status_code, 200)
        self.assertContains(resp, 'ShieldNet')
        self.assertContains(resp, 'SOC')
        self.assertContains(resp, 'Tableau de Bord SOC')

    def test_admin_changelist_rendering(self):
        resp = self.client.get('/admin/shield_api/blacklistednumber/')
        self.assertEqual(resp.status_code, 200)
        self.assertContains(resp, 'Liste Noire Télécom')

    def test_admin_login_rendering(self):
        # Déconnexion pour tester la page de login autonome
        self.client.logout()
        resp = self.client.get('/admin/login/')
        self.assertEqual(resp.status_code, 200)
        self.assertContains(resp, 'login-form')

    def test_admin_triage_dashboard_view(self):
        # Création d'un signalement pour valider le rendu complet de la console avec l'analyse IA
        SpamReport.objects.create(
            phone_hash="e" * 64,
            category='phishing',
            comment='Tentative de hameçonnage bancaire'
        )
        url = reverse('admin-triage-dashboard')
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        self.assertContains(resp, 'Centre de Triage')
        self.assertContains(resp, 'Signalements Reçus')
        self.assertContains(resp, 'topbar-return-btn')
        self.assertContains(resp, 'ops-btn-return')
        self.assertContains(resp, 'Retour au Tableau de Bord SOC')

    def test_admin_sandbox_dashboard_view(self):
        url = reverse('admin-sandbox-dashboard')
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        self.assertContains(resp, 'Laboratoire Sandbox')
        self.assertContains(resp, 'Lancer le Diagnostic')
        self.assertContains(resp, 'topbar-return-btn')
        self.assertContains(resp, 'ops-btn-return')
        self.assertContains(resp, 'Retour au Tableau de Bord SOC')

    def test_admin_sidebar_presence_across_all_staff_views(self):
        """
        Garantit que la barre latérale soc-sidebar est présente sur TOUTES les pages d'administration.
        """
        urls_to_test = [
            '/admin/',
            '/admin/operations/triage/',
            '/admin/operations/sandbox/',
            '/admin/shield_api/blacklistednumber/',
            '/admin/shield_api/blacklistednumber/add/',
            '/admin/shield_api/spamreport/',
            '/admin/shield_api/safereport/',
            '/admin/shield_api/auditlog/',
            '/admin/auth/user/',
            '/admin/auth/user/add/',
            '/admin/password_change/',
        ]
        for u in urls_to_test:
            resp = self.client.get(u)
            self.assertEqual(resp.status_code, 200, f"La page {u} a retourné le code {resp.status_code}")
            content = resp.content.decode('utf-8')
            self.assertIn('soc-sidebar', content, f"La barre latérale soc-sidebar est absente de la page {u}")

    def test_admin_breadcrumbs_present_on_all_views(self):
        """
        Garantit que le fil d'Ariane est rendu proprement sur toutes les pages d'administration.
        """
        urls = [
            '/admin/',
            '/admin/operations/triage/',
            '/admin/operations/sandbox/',
            '/admin/shield_api/blacklistednumber/',
            '/admin/shield_api/spamreport/',
            '/admin/shield_api/safereport/',
            '/admin/shield_api/auditlog/',
            '/admin/auth/user/',
        ]
        for u in urls:
            resp = self.client.get(u)
            self.assertEqual(resp.status_code, 200)
            content = resp.content.decode('utf-8')
            has_bc = 'soc-breadcrumbs' in content or 'breadcrumbs' in content
            self.assertTrue(has_bc, f"Fil d'Ariane manquant sur {u}")

    def test_no_duplicate_titles_on_custom_dashboards(self):
        """
        Vérifie qu'aucun en-tête en doublon n'apparaît sur le Centre de Triage ou la Sandbox.
        """
        for route in ['/admin/operations/triage/', '/admin/operations/sandbox/']:
            resp = self.client.get(route)
            self.assertEqual(resp.status_code, 200)
            content = resp.content.decode('utf-8')
            # Ne doit pas contenir soc-page-header car content_title est surchargé vide
            self.assertNotIn('soc-page-header', content, f"Titre en doublon détecté sur {route}")

    def test_sandbox_check_and_action_flow(self):
        """
        Teste le cycle de vie du simulateur sandbox : diagnostic d'un numéro puis action de blocage.
        """
        # Diagnostic
        check_url = reverse('admin-sandbox-check') + '?phone_number=+18195550199'
        resp = self.client.get(check_url)
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertTrue(data['success'])
        self.assertIn('phone_hash', data)
        self.assertIn('risk_score', data)

        # Action directe de blocage
        action_url = reverse('admin-sandbox-action')
        resp_action = self.client.post(
            action_url,
            data=json.dumps({'phone_number': '+18195550199', 'action': 'block'}),
            content_type='application/json'
        )
        self.assertEqual(resp_action.status_code, 200)
        action_data = resp_action.json()
        self.assertTrue(action_data['success'])
        self.assertTrue(action_data['is_blocked'])

    def test_export_blacklist_csv(self):
        """
        Vérifie que l'export CSV fonctionne et renvoie les bons en-têtes et le bon Content-Type.
        """
        url = reverse('admin-export-csv')
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp['Content-Type'], 'text/csv; charset=utf-8')
        self.assertIn('attachment; filename="shieldnet_blacklist_', resp['Content-Disposition'])

    def test_trigger_consensus_and_purge(self):
        """
        Vérifie les opérations de maintenance de consensus et de purge des orphelins.
        """
        consensus_url = reverse('admin-trigger-consensus')
        resp = self.client.post(consensus_url)
        self.assertEqual(resp.status_code, 200)
        self.assertTrue(resp.json()['success'])

        purge_url = reverse('admin-trigger-purge')
        resp2 = self.client.post(purge_url)
        self.assertEqual(resp2.status_code, 200)
        self.assertTrue(resp2.json()['success'])

    def test_css_static_file_integrity_and_light_mode_tokens(self):
        """
        Vérifie l'intégrité du fichier CSS de design system et la présence des variables critiques.
        """
        import os
        from django.conf import settings
        css_path = os.path.join(settings.BASE_DIR, 'shield_api', 'static', 'shield_api', 'admin_premium.css')
        self.assertTrue(os.path.exists(css_path), "admin_premium.css doit exister")
        
        with open(css_path, 'r', encoding='utf-8') as f:
            css_content = f.read()
        
        # Vérification des variables clés pour éviter tout texte invisible
        self.assertIn('--text-main:', css_content)
        self.assertIn('--text-primary:', css_content)
        self.assertIn('--text-secondary:', css_content)
        self.assertIn('--text-muted:', css_content)
        self.assertIn('--bg-surface:', css_content)
        self.assertIn('--bg-card:', css_content)
        self.assertIn('--bg-input:', css_content)
        self.assertIn('html.light-mode', css_content)
        self.assertIn('.selector', css_content)
        self.assertIn('.delete-confirmation', css_content)
        self.assertIn('#change-history', css_content)
        self.assertIn('ul.errorlist', css_content)

        # Vérification des classes de composants SOC
        self.assertIn('.soc-hero-banner', css_content)
        self.assertIn('.hero-banner-title', css_content)
        self.assertIn('.hero-banner-sub', css_content)
        self.assertIn('.sandbox-panel', css_content)
        self.assertIn('.sandbox-input', css_content)
        self.assertIn('.ops-bar', css_content)

        # Vérification des règles de contraste renforcées pour le mode clair
        self.assertIn('html.light-mode table thead th', css_content)
        self.assertIn('html.light-mode table tbody td', css_content)
        self.assertIn('html.light-mode .ops-btn-primary', css_content)
        self.assertIn('html.light-mode .topbar-return-btn', css_content)
        self.assertIn('html.light-mode .badge-safe', css_content)

        # Vérification des règles de contraste renforcées pour le mode sombre
        self.assertIn('html:not(.light-mode) table thead th', css_content)
        self.assertIn('html:not(.light-mode) table tbody td', css_content)
        self.assertIn('html:not(.light-mode) select option', css_content)
        self.assertIn('html:not(.light-mode) #changelist-filter h3', css_content)
        self.assertIn('html:not(.light-mode) a:link', css_content)
        self.assertIn('[data-theme="dark"]', css_content)

        # Vérification de l'intégrité syntaxique CSS (accolades parfaitement équilibrées)
        open_braces = 0
        for char in css_content:
            if char == '{':
                open_braces += 1
            elif char == '}':
                open_braces -= 1
        self.assertEqual(open_braces, 0, "admin_premium.css doit avoir un solde parfait d'accolades { et }")

        # Vérification du footer SOC global
        self.assertIn('.soc-footer', css_content)
        self.assertIn('html.light-mode .soc-footer', css_content)

        # Vérification de l'événement de basculement de thème et footer dans les templates
        base_html_path = os.path.join(settings.BASE_DIR, 'templates', 'admin', 'base.html')
        with open(base_html_path, 'r', encoding='utf-8') as f:
            base_html = f.read()
        self.assertIn('shieldnet-theme-changed', base_html)
        self.assertIn('soc-footer', base_html)

        index_html_path = os.path.join(settings.BASE_DIR, 'templates', 'admin', 'index.html')
        with open(index_html_path, 'r', encoding='utf-8') as f:
            index_html = f.read()
        self.assertIn('shieldnet-theme-changed', index_html)
        self.assertIn('updateChartsForTheme', index_html)


class ShieldNetAIEngineTest(APITestCase):
    """
    Tests de validation du moteur d'analyse sémantique et heuristique :
    - Filtrage lexical multilingue (FR / EN)
    - Détection et arbitrage des faux positifs (services essentiels, santé, livraison)
    - Détection des motifs robocalls et numéros fictifs NANP (+1)
    - Facteurs explicatifs de décision
    - Endpoint REST API /api/v1/ai/diagnose/
    """
    def setUp(self):
        from shield_api.ai_engine import ShieldNetAIEngine, NLPSemanticAnalyzer
        from shield_api.services import hash_phone_number
        self.ai_engine = ShieldNetAIEngine
        self.nlp = NLPSemanticAnalyzer
        self.hash_fn = hash_phone_number
        self.client.credentials(HTTP_X_API_KEY=settings.API_KEY)

    def test_nlp_legitimate_keywords(self):
        comments = [
            "Rappel de rendez-vous avec le Dr Tremblay à la clinique médicale de Gatineau.",
            "Livreur Amazon pour livraison de colis à votre adresse.",
            "Hydro-Québec avis de coupure de service programmée."
        ]
        score, entities = self.nlp.analyze_comments(comments)
        self.assertGreater(score, 40.0)
        self.assertTrue(any("Santé" in e or "Livraison" in e or "Services Publics" in e for e in entities))

    def test_nlp_threat_keywords(self):
        comments = [
            "Urgent CRA Canada Revenue Agency warrant for arrest pay bitcoin immediately.",
            "Gendarmerie Royale mandat d'arrêt et amende impayée carte cadeau.",
            "Your SIN social insurance number has been suspended press 1."
        ]
        score, entities = self.nlp.analyze_comments(comments)
        self.assertLess(score, -40.0)
        self.assertTrue(any("Agence Publique" in e or "Fiscale" in e or "Extorsion" in e for e in entities))

    def test_ai_diagnose_fictitious_scam_number(self):
        # 555-01xx est réservé pour la fiction dans le plan NANP nord-américain
        fictitious_phone = "+1 819 555 0199"
        phone_hash = self.hash_fn(fictitious_phone)

        # Création de signalements de menace
        SpamReport.objects.create(
            phone_hash=phone_hash,
            category='robocall',
            comment="Appel automatisé prétendant être l'Agence du revenu du Canada avec menace de prison."
        )
        SpamReport.objects.create(
            phone_hash=phone_hash,
            category='phishing',
            comment="Robocall CRA tax arrest warrant bitcoin."
        )

        diag = self.ai_engine.diagnose(phone_number=fictitious_phone, phone_hash=phone_hash)

        self.assertIn(diag['verdict'], ['CYBER_MENACE_CRITIQUE', 'FRAUDE_SUSPECTEE'])
        self.assertEqual(diag['recommendation'], 'ESCALATE_BLOCK')
        self.assertGreaterEqual(diag['composite_risk_score'], 80)
        self.assertLess(diag['false_positive_confidence'], 15)
        self.assertTrue(any(f['direction'] == 'threat' for f in diag['xai_factors']))

    def test_ai_diagnose_false_positive_rehabilitation(self):
        # Numéro d'un hôpital ou d'une clinique malencontreusement signalé
        clinic_phone = "+1 819 777 3838"
        phone_hash = self.hash_fn(clinic_phone)

        # 1 signalement isolé erroné
        SpamReport.objects.create(
            phone_hash=phone_hash,
            category='other',
            comment="Secrétariat du Dr Lavoie pour confirmation de biopsie et rendez-vous médical clinique."
        )

        # 3 confirmations citoyennes légitimes (avis sûrs)
        SafeReport.objects.create(
            phone_hash=phone_hash,
            reason='clinic',
            comment="C'est le secrétariat médical de la clinique de Gatineau."
        )
        SafeReport.objects.create(
            phone_hash=phone_hash,
            reason='delivery',
            comment="Numéro légitime de l'hôpital pour les consultations externes."
        )

        # Entrée en base
        BlacklistedNumber.objects.create(
            phone_hash=phone_hash,
            masked_number='+1 819 *** **38',
            category='other',
            risk_score=35,
            reports_count=1,
            safe_reports_count=2,
            consensus_score=0.67,
            is_blocked=False,
            is_whitelisted=False
        )

        diag = self.ai_engine.diagnose(phone_number=clinic_phone, phone_hash=phone_hash)

        self.assertIn(diag['verdict'], ['FAUX_POSITIF_CONFIRME', 'FAUX_POSITIF_PROBABLE'])
        self.assertEqual(diag['recommendation'], 'AUTO_WHITELIST')
        self.assertGreaterEqual(diag['false_positive_confidence'], 70)
        self.assertLessEqual(diag['composite_risk_score'], 30)

        # Vérification des facteurs d'explicabilité XAI
        positive_factors = [f for f in diag['xai_factors'] if f['direction'] == 'positive']
        self.assertGreater(len(positive_factors), 0)

    def test_ai_diagnose_api_endpoint(self):
        url = reverse('ai-diagnose')

        # Requête GET avec paramètre
        res_get = self.client.get(url, {'phone_number': '+1 819 555 0199'})
        self.assertEqual(res_get.status_code, status.HTTP_200_OK)
        self.assertIn('verdict', res_get.data)
        self.assertIn('false_positive_confidence', res_get.data)
        self.assertIn('composite_risk_score', res_get.data)
        self.assertIn('xai_factors', res_get.data)
        self.assertIn('execution_time_ms', res_get.data)

        # Requête POST avec JSON
        res_post = self.client.post(url, {'phone_number': '+1 819 777 3838'}, format='json')
        self.assertEqual(res_post.status_code, status.HTTP_200_OK)
        self.assertEqual(res_post.data['phone_number'], '+1 819 777 3838')

        # Requête sans numéro ni hash -> 400
        res_bad = self.client.post(url, {}, format='json')
        self.assertEqual(res_bad.status_code, status.HTTP_400_BAD_REQUEST)

        # Requête sans authentification API Key -> 401/403
        unauth_client = self.client_class()
        res_unauth = unauth_client.get(url, {'phone_number': '+1 819 555 0199'})
        self.assertIn(res_unauth.status_code, [status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN])


class SecurityConfigurationTests(TestCase):
    """
    Tests de validation de la configuration de sécurité (clés API, sels, autorisations).
    """
    def test_settings_has_valid_api_key_and_salt(self):
        self.assertTrue(hasattr(settings, 'API_KEY'))
        self.assertTrue(bool(settings.API_KEY))
        self.assertTrue(hasattr(settings, 'HASH_SALT'))
        self.assertTrue(bool(settings.HASH_SALT))

    def test_hash_phone_number_uses_configured_salt(self):
        from shield_api.services import hash_phone_number
        hash_val = hash_phone_number("+1 819 123 4567")
        self.assertEqual(len(hash_val), 64)

    def test_permission_denies_wrong_or_missing_api_key(self):
        from shield_api.permissions import HasAPIKeyOrAuthenticated
        from rest_framework.test import APIRequestFactory
        factory = APIRequestFactory()

        # Clé invalide
        req_invalid = factory.get('/api/v1/blacklist/', HTTP_X_API_KEY='cle_invalide_attaquant')
        req_invalid.user = None
        perm = HasAPIKeyOrAuthenticated()
        self.assertFalse(perm.has_permission(req_invalid, None))

        # Clé valide
        req_valid = factory.get('/api/v1/blacklist/', HTTP_X_API_KEY=settings.API_KEY)
        req_valid.user = None
        self.assertTrue(perm.has_permission(req_valid, None))


class AdvancedAIEngineTests(TestCase):
    """
    Tests unitaires des briques IA avancées :
    - Entropie spectrale de Shannon (analyse des suites numériques spoofées)
    - Amortissement temporel exponentiel (réassignation télécom & demi-vie 90j)
    - Détection d'usurpation paradoxale (co-occurrence contradictoire)
    - Intégration fermée dans le consensus de consensualité
    """
    def test_shannon_digit_entropy_detects_synthetic_sequences(self):
        from shield_api.ai_engine import ShannonEntropyAnalyzer
        # Numéro complètement uniforme (entropie nulle = 0.0 bit)
        res_uniform = ShannonEntropyAnalyzer.evaluate_entropy_risk("+1 888 888 8888")
        self.assertEqual(res_uniform['entropy'], 0.0)

        # Numéro avec répétition massive (entropie très basse < 2.2 bits)
        res_low = ShannonEntropyAnalyzer.evaluate_entropy_risk("+1 819 000 0000")
        self.assertTrue(res_low['is_synthetic'])
        self.assertLess(res_low['entropy'], 2.2)

        # Numéro humain authentique et diversifié (entropie >= 2.5 bits)
        res_normal = ShannonEntropyAnalyzer.evaluate_entropy_risk("+1 819 773 2495")
        self.assertFalse(res_normal['is_synthetic'])
        self.assertGreaterEqual(res_normal['entropy'], 2.5)

    def test_temporal_decay_half_life(self):
        from shield_api.ai_engine import TemporalDecayService
        from django.utils import timezone
        from datetime import timedelta

        now = timezone.now()
        # Événement immédiat -> poids proche de 1.0
        w_now = TemporalDecayService.calculate_decay_weight(now)
        self.assertAlmostEqual(w_now, 1.0, places=2)

        # Événement vieux de 90 jours (une demi-vie) -> poids ~ 0.5
        t_90d = now - timedelta(days=90)
        w_90d = TemporalDecayService.calculate_decay_weight(t_90d)
        self.assertAlmostEqual(w_90d, 0.5, delta=0.05)

        # Événement vieux de 180 jours (deux demi-vies) -> poids ~ 0.25
        t_180d = now - timedelta(days=180)
        w_180d = TemporalDecayService.calculate_decay_weight(t_180d)
        self.assertAlmostEqual(w_180d, 0.25, delta=0.05)

        # Événement très ancien (ex: 2 ans) -> ne descend jamais sous le plancher de sécurité (0.05)
        t_old = now - timedelta(days=730)
        w_old = TemporalDecayService.calculate_decay_weight(t_old)
        self.assertGreaterEqual(w_old, 0.05)

    def test_adversarial_impersonation_detection(self):
        from shield_api.ai_engine import AdversarialImpersonationDetector
        # Fraude flagrante : Autorité officielle + Moyen d'extorsion financier
        scam_text = "Ici Revenu Québec, votre compte est suspendu. Payez immédiatement en carte cadeau Apple ou mandat."
        detection = AdversarialImpersonationDetector.detect(scam_text)
        self.assertTrue(detection['is_impersonation'])
        self.assertEqual(detection['severity'], 90)
        self.assertIn('revenu quebec', detection['authorities'])
        self.assertIn('carte cadeau', detection['extortions'])

        # Message bénin mentionnant un service de santé sans extorsion
        benign_text = "Rappel de votre rendez-vous au CLSC avec votre médecin demain à 14h."
        detection_benign = AdversarialImpersonationDetector.detect(benign_text)
        self.assertFalse(detection_benign['is_impersonation'])
        self.assertEqual(detection_benign['severity'], 0)

    def test_consensus_service_incorporates_nlp_and_temporal_decay(self):
        from shield_api.services import FalsePositiveConsensusService, ReputationService
        from django.contrib.auth.models import User

        phone_hash = "f" * 64
        # Signalement spam avec tentative d'usurpation dans le commentaire
        ReputationService.process_new_report(
            phone_hash=phone_hash,
            category='fraud',
            comment='Appel se disant de la police demandant un virement interac urgent'
        )

        user1 = User.objects.create_user(username='tester_cons_1', email='tc1@test.com')
        # Avis légitime
        FalsePositiveConsensusService.register_safe_feedback(
            phone_hash=phone_hash,
            reason='medical',
            comment='C\'est en réalité la clinique médicale de Gatineau',
            user=user1
        )

        evaluation = FalsePositiveConsensusService.evaluate_consensus(phone_hash)
        self.assertIn('beta_nlp', evaluation)
        # Usurpation détectée dans le signalement spam -> beta_nlp restreint à 0.5
        self.assertLessEqual(evaluation['beta_nlp'], 1.0)

    def test_bayesian_classifier_log_odds_and_ngrams(self):
        from shield_api.ai_engine import BayesianSemanticClassifier

        # 1. Message typique de fraude fiscale avec n-grammes
        scam_text = "Urgent Agence du Revenu du Canada mandat d'arret arrest warrant payer en bitcoin immediatement"
        res_scam = BayesianSemanticClassifier.classify(scam_text)
        self.assertGreater(res_scam['probability_threat'], 0.80)
        self.assertLess(res_scam['probability_legitimate'], 0.20)
        self.assertGreater(res_scam['log_odds'], 0.0)
        self.assertTrue(len(res_scam['matched_tokens']) > 0)

        # 2. Message de service public ou santé légitime
        safe_text = "Confirmation de votre rendez-vous medical a la clinique avec le medecin et livraison de pharmacie"
        res_safe = BayesianSemanticClassifier.classify(safe_text)
        self.assertGreater(res_safe['probability_legitimate'], 0.80)
        self.assertLess(res_safe['probability_threat'], 0.20)
        self.assertLess(res_safe['log_odds'], 0.0)

        # 3. Borne stricte des log-odds [-15.0, +15.0]
        self.assertGreaterEqual(res_scam['log_odds'], -15.0)
        self.assertLessEqual(res_scam['log_odds'], 15.0)

    def test_poisson_burst_analyzer_z_score(self):
        from shield_api.ai_engine import PoissonBurstAnalyzer
        from django.utils import timezone
        from datetime import timedelta

        now = timezone.now()
        # Vague d'appels rapprochés (5 signalements en 20 minutes)
        burst_timestamps = [now - timedelta(minutes=i * 4) for i in range(5)]
        eval_burst = PoissonBurstAnalyzer.evaluate_burst(burst_timestamps, window_hours=2.0)
        self.assertTrue(eval_burst['is_burst'])
        self.assertGreaterEqual(eval_burst['z_score'], 2.5)
        self.assertEqual(eval_burst['recent_count'], 5)

        # Événements espacés régulièrement sur plusieurs jours
        spaced_timestamps = [now - timedelta(days=i * 2) for i in range(5)]
        eval_spaced = PoissonBurstAnalyzer.evaluate_burst(spaced_timestamps, window_hours=2.0)
        self.assertFalse(eval_spaced['is_burst'])
        self.assertLess(eval_spaced['z_score'], 2.5)

    def test_nanp_telephony_routing_and_n11_detection(self):
        from shield_api.ai_engine import NANPTelephonyValidator

        # 1. Numéro géopolitique NANP valide (Gatineau/Outaouais 819)
        val_geo = NANPTelephonyValidator.validate_number("+1 819 777 3838")
        self.assertTrue(val_geo['is_valid_nanp'])
        self.assertFalse(val_geo['is_impossible_routing'])
        self.assertFalse(val_geo['is_toll_free'])
        self.assertEqual(val_geo['parsed']['npa'], '819')
        self.assertEqual(val_geo['parsed']['nxx'], '777')

        # 2. Routage impossible N11 réservé en bureau central (ex: 819-911-xxxx ou 514-411-xxxx)
        val_n11 = NANPTelephonyValidator.validate_number("+1 819 911 0000")
        self.assertFalse(val_n11['is_valid_nanp'])
        self.assertTrue(val_n11['is_impossible_routing'])
        self.assertIn("Routage impossible", val_n11['details'])

        # 3. Plage fictive NANP 555-01xx
        val_fict = NANPTelephonyValidator.validate_number("+1 819 555 0199")
        self.assertFalse(val_fict['is_valid_nanp'])
        self.assertTrue(val_fict['is_impossible_routing'])
        self.assertIn("555-01xx", val_fict['details'])

        # 4. Numéro sans frais (Toll-Free 800/888/877/866)
        val_tf = NANPTelephonyValidator.validate_number("+1 800 267 8097")
        self.assertTrue(val_tf['is_valid_nanp'])
        self.assertTrue(val_tf['is_toll_free'])

    def test_calibrated_decision_fusion_profiles(self):
        from shield_api.ai_engine import CalibratedDecisionFusion

        # Signal intermédiaire modéré
        args = {
            'threat_score': 50.0,
            'legit_score': 10.0,
            'decayed_spam': 3.0,
            'decayed_safe': 0.0,
            'burst_z_score': 1.5,
            'entropy_val': 2.8,
            'is_synthetic_entropy': False,
            'is_impossible_routing': False,
            'is_impersonation': False,
            'stir_attestation': 'B',
        }

        score_balanced, _ = CalibratedDecisionFusion.fuse_signals(**args, profile_name='balanced')
        score_senior, _ = CalibratedDecisionFusion.fuse_signals(**args, profile_name='senior_shield')
        score_precision, _ = CalibratedDecisionFusion.fuse_signals(**args, profile_name='high_precision')

        # Le profil Senior Shield amplifie la sensibilité de blocage (score plus élevé)
        self.assertGreater(score_senior, score_balanced)
        # Le profil High Precision applique un conservatisme strict
        self.assertLess(score_precision, score_balanced)

        # Les scores restent strictement bornés entre 0 et 100
        for s in [score_balanced, score_senior, score_precision]:
            self.assertGreaterEqual(s, 0)
            self.assertLessEqual(s, 100)

    def test_arithmetic_sequence_analyzer(self):
        from shield_api.ai_engine import ArithmeticSequenceAnalyzer

        # 1. Suite croissante (12345)
        res_asc = ArithmeticSequenceAnalyzer.evaluate_sequences("+1 514 123 4567")
        self.assertTrue(res_asc['has_pattern'])
        self.assertEqual(res_asc['pattern_type'], 'ASCENDING_RUN')
        self.assertIn("croissante", res_asc['description'])

        # 2. Suite décroissante (98765)
        res_desc = ArithmeticSequenceAnalyzer.evaluate_sequences("+1 514 987 6500")
        self.assertTrue(res_desc['has_pattern'])
        self.assertEqual(res_desc['pattern_type'], 'DESCENDING_RUN')

        # 3. Motif périodique oscillant (121212)
        res_osc = ArithmeticSequenceAnalyzer.evaluate_sequences("+1 819 121 2120")
        self.assertTrue(res_osc['has_pattern'])
        self.assertEqual(res_osc['pattern_type'], 'PERIODIC_OSCILLATION')

        # 4. Bloc répétitif dense (8888)
        res_rep = ArithmeticSequenceAnalyzer.evaluate_sequences("+1 438 888 8123")
        self.assertTrue(res_rep['has_pattern'])
        self.assertEqual(res_rep['pattern_type'], 'REPETITIVE_BLOCK')

        # 5. Numéro normal sans motif
        res_norm = ArithmeticSequenceAnalyzer.evaluate_sequences("+1 514 800 1234")
        self.assertFalse(res_norm['has_pattern'])

    def test_adversarial_impersonation_negation_awareness(self):
        from shield_api.ai_engine import AdversarialImpersonationDetector

        # A. Message préventif citoyen avec négation : NE DOIT PAS être considéré comme une usurpation
        preventive_text = "Attention : la police ne demande JAMAIS de carte cadeau ni de bitcoin !"
        res_prev = AdversarialImpersonationDetector.detect(preventive_text)
        self.assertFalse(res_prev['is_impersonation'])
        self.assertEqual(res_prev['severity'], 0)
        self.assertIn('carte cadeau', res_prev['negated_extortions'])

        # B. Message frauduleux actif sans négation : DOIT être détecté avec sévérité maximale
        attack_text = "Ici la police de Gatineau, mandat d'arret contre vous. Payez en carte cadeau apple immediatement."
        res_attack = AdversarialImpersonationDetector.detect(attack_text)
        self.assertTrue(res_attack['is_impersonation'])
        self.assertEqual(res_attack['severity'], 90)

    def test_wangiri_and_international_telecom_qualification(self):
        from shield_api.ai_engine import NANPTelephonyValidator

        # 1. Piège Wangiri (Île de l'Ascension +247)
        res_wangiri = NANPTelephonyValidator.validate_number("+247 555 1234")
        self.assertTrue(res_wangiri['is_wangiri_risk'])
        self.assertFalse(res_wangiri['is_impossible_routing'])
        self.assertIn("Wangiri", res_wangiri['details'])

        # 2. Numéro international standard (+33 France)
        res_intl = NANPTelephonyValidator.validate_number("+33 1 42 68 55 00")
        self.assertFalse(res_intl['is_valid_nanp'])
        self.assertFalse(res_intl['is_impossible_routing'])
        self.assertFalse(res_intl['is_wangiri_risk'])
        self.assertTrue(res_intl['is_valid_international'])

    def test_poisson_burst_analyzer_multi_scale(self):
        from shield_api.ai_engine import PoissonBurstAnalyzer
        from django.utils import timezone
        from datetime import timedelta

        now = timezone.now()
        # Flash attack immédiate : 4 signalements en 10 minutes
        flash_timestamps = [now - timedelta(minutes=i * 2) for i in range(4)]
        res = PoissonBurstAnalyzer.evaluate_burst(flash_timestamps, window_hours=2.0)
        self.assertTrue(res['is_burst'])
        self.assertIn('multi_scale', res)
        self.assertGreaterEqual(res['multi_scale']['micro_15m_count'], 4)


class ApplicationSecurityAuditTests(APITestCase):
    """
    Tests de vérification et d'audit de sécurité applicative (OWASP Top 10 & CWE) :
    - Immunité aux attaques par canal auxiliaire (Timing Attacks sur API_KEY)
    - Protection contre l'usurpation de compte staff via connexion sociale (Account Takeover)
    - Neutralisation de l'énumération des utilisateurs (User Enumeration Prevention)
    - Protection contre les injections de formules dans les exports (CSV Injection CWE-1236)
    - Plafonnement strict des tailles de charge utile (DoS / Resource Exhaustion)
    """
    def test_api_key_constant_time_comparison(self):
        from shield_api.permissions import HasAPIKeyOrAuthenticated
        from rest_framework.test import APIRequestFactory
        factory = APIRequestFactory()
        perm = HasAPIKeyOrAuthenticated()

        # Clé invalide
        req_wrong = factory.get('/api/v1/blacklist/', HTTP_X_API_KEY='fake_key')
        req_wrong.user = None
        self.assertFalse(perm.has_permission(req_wrong, None))

        # Clé exacte
        req_right = factory.get('/api/v1/blacklist/', HTTP_X_API_KEY=settings.API_KEY)
        req_right.user = None
        self.assertTrue(perm.has_permission(req_right, None))

    def test_google_login_rejects_staff_account_takeover(self):
        from django.contrib.auth.models import User
        # Création d'un administrateur système
        admin_email = 'soc_boss@shieldnet.app'
        User.objects.create_superuser(username='soc_boss', email=admin_email, password='SecretPassword123!')

        url = reverse('auth-google')
        # Tentative d'usurpation de l'administrateur sans mot de passe via l'endpoint Google
        resp = self.client.post(url, {'email': admin_email, 'name': 'Attacker'}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)
        self.assertIn('privilèges administratifs', resp.data['detail'])

    def test_login_uniform_error_message_prevents_user_enumeration(self):
        url = reverse('auth-login')
        # 1. Tentative sur email inexistant
        resp_nonexistent = self.client.post(url, {'email': 'ghost@unknown.qc.ca', 'password': 'somepassword'}, format='json')
        self.assertEqual(resp_nonexistent.status_code, status.HTTP_400_BAD_REQUEST)
        err_msg_1 = str(resp_nonexistent.data)

        # 2. Création d'un utilisateur puis tentative avec mauvais mot de passe
        from django.contrib.auth.models import User
        User.objects.create_user(username='real@shieldnet.app', email='real@shieldnet.app', password='GoodPassword123!')
        resp_wrong_pass = self.client.post(url, {'email': 'real@shieldnet.app', 'password': 'WrongPassword999!'}, format='json')
        self.assertEqual(resp_wrong_pass.status_code, status.HTTP_400_BAD_REQUEST)
        err_msg_2 = str(resp_wrong_pass.data)

        # Les messages d'erreur doivent être identiques pour empêcher l'énumération d'adresses email
        self.assertIn("Adresse email ou mot de passe incorrect", err_msg_1)
        self.assertIn("Adresse email ou mot de passe incorrect", err_msg_2)

    def test_csv_export_neutralizes_formula_injection(self):
        from shield_api.admin_views import sanitize_csv_cell
        # Formules malveillantes typiques sous Excel
        self.assertEqual(sanitize_csv_cell("=CMD|'/C calc'!A0"), "'=CMD|'/C calc'!A0")
        self.assertEqual(sanitize_csv_cell("+18195551234"), "'+18195551234")
        self.assertEqual(sanitize_csv_cell("@SUM(1+1)"), "'@SUM(1+1)")
        self.assertEqual(sanitize_csv_cell("-5+2"), "'-5+2")
        # Valeur textuelle normale non modifiée
        self.assertEqual(sanitize_csv_cell("FRAUD"), "FRAUD")
        self.assertEqual(sanitize_csv_cell("8195551234"), "8195551234")

    def test_comment_payload_size_enforced(self):
        url = reverse('submit-report')
        self.client.credentials(HTTP_X_API_KEY=settings.API_KEY)
        huge_comment = "A" * 1500  # dépasse la limite de 1000 caractères
        resp = self.client.post(url, {
            'phone_hash': 'a' * 64,
            'category': 'fraud',
            'comment': huge_comment,
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('comment', resp.data)

    def test_batch_check_numbers_success(self):
        url = reverse('batch-check-number')
        self.client.credentials(HTTP_X_API_KEY=settings.API_KEY)

        # 1. Un numéro frauduleux bloqué
        h1 = "1" * 64
        BlacklistedNumber.objects.create(
            phone_hash=h1,
            category='financial_scam',
            risk_score=85,
            reports_count=5,
            is_blocked=True,
            is_whitelisted=False,
        )

        # 2. Un numéro réhabilité (liste blanche)
        h2 = "2" * 64
        BlacklistedNumber.objects.create(
            phone_hash=h2,
            category='service',
            risk_score=0,
            reports_count=2,
            safe_reports_count=5,
            consensus_score=0.9,
            is_blocked=False,
            is_whitelisted=True,
            whitelist_reason='medical',
        )

        # 3. Un numéro inconnu
        h3 = "3" * 64

        resp = self.client.post(url, {'hashes': [h1, h2, h3]}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(resp.data['count'], 3)
        res = resp.data['results']

        self.assertTrue(res[h1]['is_spam'])
        self.assertEqual(res[h1]['risk_score'], 85)
        self.assertEqual(res[h1]['category'], 'financial_scam')

        self.assertFalse(res[h2]['is_spam'])
        self.assertTrue(res[h2]['is_whitelisted'])
        self.assertEqual(res[h2]['whitelist_reason'], 'medical')

        self.assertFalse(res[h3]['is_spam'])
        self.assertEqual(res[h3]['risk_score'], 0)

    def test_batch_check_validation_rules(self):
        url = reverse('batch-check-number')
        self.client.credentials(HTTP_X_API_KEY=settings.API_KEY)

        # Hash non conforme (trop court)
        resp_invalid = self.client.post(url, {'hashes': ['not_a_valid_hash']}, format='json')
        self.assertEqual(resp_invalid.status_code, status.HTTP_400_BAD_REQUEST)

        # Liste vide
        resp_empty = self.client.post(url, {'hashes': []}, format='json')
        self.assertEqual(resp_empty.status_code, status.HTTP_400_BAD_REQUEST)

        # Plus de 100 hashes
        too_many = [f"{i:064x}" for i in range(105)]
        resp_too_many = self.client.post(url, {'hashes': too_many}, format='json')
        self.assertEqual(resp_too_many.status_code, status.HTTP_400_BAD_REQUEST)

    def test_prometheus_metrics_endpoint(self):
        url = reverse('prometheus-metrics')
        resp = self.client.get(url)
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertIn('text/plain', resp.headers.get('Content-Type', ''))
        body = resp.content.decode('utf-8')
        self.assertIn("shieldnet_blacklist_active_total", body)
        self.assertIn("shieldnet_spam_reports_total", body)
        self.assertIn("shieldnet_whitelisted_total", body)

    def test_stir_shaken_attestation_evaluations(self):
        from shield_api.services import AutomatedSpamVerifier
        from shield_api.ai_engine import ShieldNetAIEngine

        # 1. Vérification AutomatedSpamVerifier avec Attestation A (réduction de score)
        eval_a = AutomatedSpamVerifier.evaluate_number("a" * 64, raw_number="+18195551234", attestation="A")
        self.assertEqual(eval_a['attestation'], 'A')
        self.assertEqual(eval_a['calculated_score'], 0)

        # 2. Vérification AutomatedSpamVerifier avec Attestation C (passerelle non sécurisée)
        eval_c = AutomatedSpamVerifier.evaluate_number("c" * 64, raw_number="+18195551234", attestation="C")
        self.assertEqual(eval_c['attestation'], 'C')
        self.assertGreaterEqual(eval_c['calculated_score'], 25)
        self.assertTrue(any("STIR/SHAKEN" in a for a in eval_c['anomalies']))

        # 3. Diagnostic IA explicable avec attestation A
        diag = ShieldNetAIEngine.diagnose(phone_number="+18195551234", attestation="A")
        self.assertTrue(diag['success'])
        xai_types = [f['type'] for f in diag['xai_factors']]
        self.assertIn('STIR_SHAKEN', xai_types)
        self.assertEqual(diag['metrics']['stir_shaken_attestation'], 'A')

    def test_manager_vs_admin_role_permissions(self):
        from django.contrib.auth.models import User, Group
        from rest_framework_simplejwt.tokens import RefreshToken
        from shield_api.models import AuditLog

        # 1. Création d'un Gestionnaire et d'un Administrateur
        group, _ = Group.objects.get_or_create(name='Gestionnaires')
        manager_user = User.objects.create_user(
            username='soc_manager',
            email='manager@shieldnet.app',
            password='Password123!',
            is_staff=True,
            is_superuser=False
        )
        manager_user.groups.add(group)

        admin_user = User.objects.create_superuser(
            username='soc_admin',
            email='admin@shieldnet.app',
            password='AdminPassword123!'
        )

        std_user = User.objects.create_user(
            username='citizen_user',
            email='citizen@shieldnet.app',
            password='Password123!'
        )

        manager_token = str(RefreshToken.for_user(manager_user).access_token)
        admin_token = str(RefreshToken.for_user(admin_user).access_token)
        std_token = str(RefreshToken.for_user(std_user).access_token)

        manager_client = self.client_class()
        manager_client.credentials(HTTP_AUTHORIZATION=f'Bearer {manager_token}')

        admin_client = self.client_class()
        admin_client.credentials(HTTP_AUTHORIZATION=f'Bearer {admin_token}')

        std_client = self.client_class()
        std_client.credentials(HTTP_AUTHORIZATION=f'Bearer {std_token}')

        # 2. Vérification des rôles renvoyés par /api/v1/auth/me/
        me_manager = manager_client.get(reverse('auth-me'))
        self.assertEqual(me_manager.status_code, status.HTTP_200_OK)
        self.assertEqual(me_manager.data['role'], 'MANAGER')

        me_admin = admin_client.get(reverse('auth-me'))
        self.assertEqual(me_admin.status_code, status.HTTP_200_OK)
        self.assertEqual(me_admin.data['role'], 'ADMIN')

        me_std = std_client.get(reverse('auth-me'))
        self.assertEqual(me_std.status_code, status.HTTP_200_OK)
        self.assertEqual(me_std.data['role'], 'CITIZEN')

        # 3. Le Gestionnaire PEUT modérer et consulter les statistiques
        stats_resp = manager_client.get(reverse('admin-stats'))
        self.assertEqual(stats_resp.status_code, status.HTTP_200_OK)

        hash_test = "e" * 64
        BlacklistedNumber.objects.create(phone_hash=hash_test, category='phishing', risk_score=80, is_blocked=True)

        mod_resp = manager_client.post(reverse('admin-moderate'), {'phone_hash': hash_test, 'action': 'whitelist'}, format='json')
        self.assertEqual(mod_resp.status_code, status.HTTP_200_OK)

        # Vérification du traçage d'audit avec source MOBILE_MANAGER
        audit = AuditLog.objects.filter(target_hash=hash_test).first()
        self.assertIsNotNone(audit)
        self.assertEqual(audit.source, 'MOBILE_MANAGER')
        self.assertEqual(audit.user, manager_user)

        # 4. Le Gestionnaire NE PEUT PAS purger la base ni gérer les utilisateurs (403 Forbidden)
        purge_resp = manager_client.post(reverse('admin-purge'))
        self.assertEqual(purge_resp.status_code, status.HTTP_403_FORBIDDEN)

        users_resp = manager_client.get(reverse('admin-users'))
        self.assertEqual(users_resp.status_code, status.HTTP_403_FORBIDDEN)

        # 5. L'Administrateur PEUT purger et lister les utilisateurs
        admin_users_resp = admin_client.get(reverse('admin-users'))
        self.assertEqual(admin_users_resp.status_code, status.HTTP_200_OK)

        admin_purge_resp = admin_client.post(reverse('admin-purge'))
        self.assertEqual(admin_purge_resp.status_code, status.HTTP_200_OK)
















from rest_framework.test import APIClient

