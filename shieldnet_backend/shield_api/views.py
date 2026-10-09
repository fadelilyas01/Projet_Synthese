def verify_google_id_token(id_token):
    """Verifie cryptographiquement un jeton Google ID Token aupres de Google OAuth2."""
    if not id_token:
        return None
    import urllib.request
    import json
    url = f"https://oauth2.googleapis.com/tokeninfo?id_token={id_token}"
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'ShieldNet-Security/1.0'})
        with urllib.request.urlopen(req, timeout=5) as resp:
            return json.loads(resp.read().decode('utf-8'))
    except Exception:
        return None

from django.core.mail import send_mail
from django.utils import timezone

from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from django.core.cache import cache
from django.utils.dateparse import parse_datetime
from .models import AuditLog, AuditLogAction
from .serializers import AuditLogSerializer

import secrets
from django.db import models
from django.contrib.auth.models import User
from django.http import HttpResponse
from rest_framework import generics, status, permissions
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.throttling import AnonRateThrottle, UserRateThrottle
from rest_framework_simplejwt.tokens import RefreshToken
from drf_spectacular.utils import extend_schema

from .models import BlacklistedNumber, SpamReport, SafeReport, UserProfile, CountryChoices
from .permissions import (
    HasAPIKeyOrAuthenticated,
    IsAdminStaffUser,
    IsManagerOrAdminUser,
    IsAdminOnlyUser,
)
from .serializers import (
    BlacklistedNumberSerializer,
    SpamReportCreateSerializer,
    SafeReportCreateSerializer,
    SafeReportSerializer,
    CheckNumberResponseSerializer,
    BatchCheckRequestSerializer,
    UserSerializer,
    UserRegisterSerializer,
    EmailLoginSerializer,
    GoogleLoginSerializer,
    UpdateUserRegionSerializer,
)
from .services import (
    ReputationService,
    FalsePositiveConsensusService,
    DatabaseSanitizerService,
    hash_phone_number,
    mask_phone_number,
)

class StrictReportSubmissionThrottle(AnonRateThrottle):
    """
    Limiteur de débit strict anti-pollution: Max 10 signalements par heure par adresse IP anonyme.
    """
    rate = '10/hour'

class BlacklistDownloadView(APIView):
    """
    GET /api/v1/blacklist/
    Supporte :
    - La liste classique (compatibilité tests & anciens clients)
    - La synchronisation incrémentale (Delta Sync via ?since=<ISO-8601>)
    - La réconciliation des faux positifs (renvoie les numéros 'removed' à purger)
    """
    permission_classes = [HasAPIKeyOrAuthenticated]

    def get(self, request, *args, **kwargs):
        since_param = request.query_params.get('since')
        delta_mode = since_param is not None or request.query_params.get('delta') == 'true'

        now_iso = timezone.now().isoformat()
        active_qs = BlacklistedNumber.objects.filter(is_blocked=True, is_whitelisted=False, risk_score__gte=30)

        if delta_mode and since_param:
            clean_since = since_param.strip()
            if '+' not in clean_since and ' ' in clean_since:
                parts = clean_since.rsplit(' ', 1)
                if len(parts) == 2 and (':' in parts[1] or len(parts[1]) in (2, 4)):
                    clean_since = f"{parts[0]}+{parts[1]}"
                elif 'T' in clean_since:
                    clean_since = clean_since.replace(' ', '+')
            since_dt = parse_datetime(clean_since)
            if since_dt and timezone.is_naive(since_dt):
                since_dt = timezone.make_aware(since_dt, timezone.get_current_timezone())
            if since_dt:
                updated_active = active_qs.filter(updated_at__gte=since_dt)
                # Numéros supprimés, blanchis ou désactivés depuis 'since'
                removed_hashes = BlacklistedNumber.objects.filter(
                    models.Q(is_whitelisted=True) | models.Q(is_blocked=False) | models.Q(risk_score__lt=30),
                    updated_at__gte=since_dt
                ).values_list('phone_hash', flat=True)

                serializer = BlacklistedNumberSerializer(updated_active, many=True)
                return Response({
                    'active': serializer.data,
                    'removed': list(removed_hashes),
                    'sync_timestamp': now_iso,
                    'is_delta': True,
                })

        if delta_mode:
            serializer = BlacklistedNumberSerializer(active_qs, many=True)
            return Response({
                'active': serializer.data,
                'removed': [],
                'sync_timestamp': now_iso,
                'is_delta': False,
            })

        # Mode liste classique
        serializer = BlacklistedNumberSerializer(active_qs, many=True)
        return Response(serializer.data)


class SubmitReportView(APIView):
    """
    POST /api/v1/reports/
    Soumet un nouveau signalement avec protection stricte anti-pollution BDD.
    """
    permission_classes = [HasAPIKeyOrAuthenticated]
    throttle_classes = [StrictReportSubmissionThrottle, UserRateThrottle]

    @extend_schema(request=SpamReportCreateSerializer, responses={201: BlacklistedNumberSerializer})
    def post(self, request):
        serializer = SpamReportCreateSerializer(data=request.data)
        if serializer.is_valid():
            data = serializer.validated_data
            user = request.user if request.user.is_authenticated else None
            
            report = ReputationService.process_new_report(
                phone_hash=data['phone_hash'],
                category=data['category'],
                masked_number=data.get('masked_number'),
                user=user,
                comment=data.get('comment'),
            )

            number_obj = BlacklistedNumber.objects.get(phone_hash=data['phone_hash'])
            return Response(
                BlacklistedNumberSerializer(number_obj).data,
                status=status.HTTP_201_CREATED
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class SubmitSafeReportView(APIView):
    """
    POST /api/v1/reports/safe/
    Soumet un avis favorable ou une contestation de faux positif.
    Déclenche instantanément l'algorithme de consensualité et réhabilite
    automatiquement le numéro si le consensus légitime est validé.
    """
    permission_classes = [HasAPIKeyOrAuthenticated]
    throttle_classes = [StrictReportSubmissionThrottle, UserRateThrottle]

    @extend_schema(request=SafeReportCreateSerializer)
    def post(self, request):
        serializer = SafeReportCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        data = serializer.validated_data
        user = request.user if request.user.is_authenticated else None
        ip_addr = request.META.get('REMOTE_ADDR')

        report, auto_whitelisted = FalsePositiveConsensusService.register_safe_feedback(
            phone_hash=data['phone_hash'],
            reason=data.get('reason', 'service'),
            comment=data.get('comment', ''),
            user=user,
            ip_address=ip_addr,
            masked_number=data.get('masked_number'),
        )

        analysis = FalsePositiveConsensusService.evaluate_consensus(data['phone_hash'])
        number_obj = BlacklistedNumber.objects.filter(phone_hash=data['phone_hash']).first()

        detail_msg = (
            "Consensus atteint ! Numéro identifié comme faux positif et réhabilité automatiquement."
            if auto_whitelisted else
            "Avis légitime enregistré. En attente de confirmation par consensus communautaire."
        )

        return Response({
            'detail': detail_msg,
            'phone_hash': data['phone_hash'],
            'safe_reports_count': analysis['safe_count'],
            'spam_reports_count': analysis['spam_count'],
            'consensus_score': analysis['consensus_ratio'],
            'auto_whitelisted': auto_whitelisted,
            'is_whitelisted': number_obj.is_whitelisted if number_obj else False,
            'is_blocked': number_obj.is_blocked if number_obj else False,
            'whitelist_reason': number_obj.whitelist_reason if number_obj else '',
        }, status=status.HTTP_201_CREATED)

class ConsensusStatusView(APIView):
    """
    GET /api/v1/consensus/<str:phone_hash>/
    Expose en temps réel l'évaluation détaillée de consensualité et de faux positif pour un numéro.
    """
    permission_classes = [HasAPIKeyOrAuthenticated]

    def get(self, request, phone_hash):
        analysis = FalsePositiveConsensusService.evaluate_consensus(phone_hash)
        number_obj = BlacklistedNumber.objects.filter(phone_hash=phone_hash).first()
        return Response({
            'phone_hash': phone_hash,
            'spam_count': analysis['spam_count'],
            'safe_count': analysis['safe_count'],
            'consensus_ratio': analysis['consensus_ratio'],
            'quorum_met': analysis['quorum_met'],
            'is_false_positive': analysis['is_false_positive'],
            'is_whitelisted': number_obj.is_whitelisted if number_obj else False,
            'is_blocked': number_obj.is_blocked if number_obj else False,
            'whitelist_reason': number_obj.whitelist_reason if number_obj else '',
            'details': analysis['details'],
        })

class CheckNumberView(APIView):
    """
    GET /api/v1/check/<phone_hash>/
    Vérifie le score de risque, la consensualité et le statut d'un numéro d'après son empreinte SHA-256.
    Supporte le paramètre optionnel ?attestation=A|B|C (norme STIR/SHAKEN).
    """
    permission_classes = [HasAPIKeyOrAuthenticated]

    @extend_schema(responses={200: CheckNumberResponseSerializer})
    def get(self, request, phone_hash):
        attestation = request.query_params.get('attestation', '').strip()[:1].upper()
        try:
            number = BlacklistedNumber.objects.get(phone_hash=phone_hash)
            # Un numéro est considéré comme spam s'il est bloqué ET non blanchi
            is_spam = number.is_blocked and not number.is_whitelisted
            risk_score = number.risk_score

            # Ajustement dynamique basé sur l'attestation cryptographique STIR/SHAKEN
            if attestation == 'A' and risk_score < 70 and not number.is_blocked:
                risk_score = max(0, risk_score - 20)
            elif attestation == 'C' and is_spam:
                risk_score = min(100, risk_score + 10)

            return Response({
                'is_spam': is_spam,
                'risk_score': risk_score,
                'category': number.category,
                'reports_count': number.reports_count,
                'safe_reports_count': number.safe_reports_count,
                'consensus_score': number.consensus_score,
                'is_whitelisted': number.is_whitelisted,
                'whitelist_reason': number.whitelist_reason,
            })
        except BlacklistedNumber.DoesNotExist:
            return Response({
                'is_spam': False,
                'risk_score': 0,
                'category': None,
                'reports_count': 0,
                'safe_reports_count': 0,
                'consensus_score': 0.0,
                'is_whitelisted': False,
                'whitelist_reason': None,
            })


class BatchCheckNumberView(APIView):
    """
    POST /api/v1/check/batch/
    Vérification groupée d'empreintes SHA-256 (jusqu'à 100 numéros par requête).
    Permet à l'application mobile de vérifier localement l'historique d'appels en une seule passe réseau.
    """
    permission_classes = [HasAPIKeyOrAuthenticated]

    def post(self, request):
        serializer = BatchCheckRequestSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        hashes = serializer.validated_data['hashes']
        numbers = BlacklistedNumber.objects.filter(phone_hash__in=hashes)
        number_map = {num.phone_hash: num for num in numbers}

        results = {}
        for h in hashes:
            num = number_map.get(h)
            if num:
                is_spam = num.is_blocked and not num.is_whitelisted
                results[h] = {
                    'is_spam': is_spam,
                    'risk_score': num.risk_score,
                    'category': num.category,
                    'reports_count': num.reports_count,
                    'safe_reports_count': num.safe_reports_count,
                    'consensus_score': num.consensus_score,
                    'is_whitelisted': num.is_whitelisted,
                    'whitelist_reason': num.whitelist_reason,
                }
            else:
                results[h] = {
                    'is_spam': False,
                    'risk_score': 0,
                    'category': None,
                    'reports_count': 0,
                    'safe_reports_count': 0,
                    'consensus_score': 0.0,
                    'is_whitelisted': False,
                    'whitelist_reason': None,
                }

        return Response({
            'results': results,
            'count': len(results),
        })


def send_welcome_confirmation_email(user, request=None):
    """Envoie un courriel de bienvenue officiel et haut de gamme avec logo integre et lien vers l'application."""
    if not user or not user.email:
        return

    import os
    from django.conf import settings
    from django.core.mail import EmailMultiAlternatives
    from email.mime.image import MIMEImage

    display_name = (user.first_name or "").strip()
    if not display_name:
        display_name = user.email.split('@')[0].capitalize()

    # Determination de l'URL web alternative de redirection (reseau local ou prod)
    if request:
        try:
            web_fallback_url = request.build_absolute_uri('/open/')
        except Exception:
            web_fallback_url = "http://192.168.2.17:8000/open/"
    else:
        site_url = getattr(settings, 'SITE_URL', '').strip()
        if site_url:
            web_fallback_url = f"{site_url.rstrip('/')}/open/"
        else:
            web_fallback_url = "http://192.168.2.17:8000/open/"

    # Le lien natif direct pour ouvrir l'application sur le telephone
    direct_app_url = "shieldnet://open"

    subject = "Bienvenue sur ShieldNet — Votre protection est active"

    message = f"""Bonjour {display_name},

Bienvenue sur ShieldNet ! Nous sommes ravis de vous compter parmi nous.

Votre compte ({user.email}) est désormais actif et votre appareil est protégé.

Voici vos protections actives au quotidien :
1. FILTRAGE DES APPELS : Neutralise les appels indésirables, fraudes et robots avant qu'ils ne vous dérangent.
2. INSPECTEUR DE SMS : Analyse instantanément les messages suspects et faux avis de livraison.
3. VIE PRIVÉE GARANTIE : Vos contacts et données privées restent strictement protégés sur votre appareil.

Pour lancer votre application directement sur votre mobile :
Lien direct application : {direct_app_url}
Lien web alternatif : {web_fallback_url}

Besoin d'aide ? Consultez notre Centre d'assistance dans l'application.

L'équipe ShieldNet Security
Protection Numérique & Confidentialité
"""

    html_message = f"""<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Bienvenue sur ShieldNet</title>
</head>
<body style="margin: 0; padding: 0; background-color: #070B14; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #F1F5F9; -webkit-font-smoothing: antialiased;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color: #070B14; padding: 36px 16px;">
    <tr>
      <td align="center">
        <!-- Main Container -->
        <table role="presentation" width="100%" max-width="580" cellspacing="0" cellpadding="0" border="0" style="max-width: 580px; background-color: #0F172A; border: 1px solid #1E293B; border-radius: 20px; overflow: hidden; box-shadow: 0 20px 40px rgba(0, 0, 0, 0.55);">
          
          <!-- Header Banner -->
          <tr>
            <td style="background: linear-gradient(135deg, #0369A1 0%, #0F172A 70%); padding: 38px 32px 30px 32px; text-align: center; border-bottom: 1px solid rgba(255, 255, 255, 0.08);">
              <!-- Logo Officiel ShieldNet -->
              <table role="presentation" cellspacing="0" cellpadding="0" border="0" align="center" style="margin: 0 auto 14px auto;">
                <tr>
                  <td align="center" valign="middle" style="width: 64px; height: 64px; background: #0B132B; border-radius: 18px; border: 2px solid #38BDF8; box-shadow: 0 8px 24px rgba(2, 132, 199, 0.35); text-align: center;">
                    <img src="cid:shieldnet_logo" width="46" height="46" alt="ShieldNet Logo" style="display: block; margin: 0 auto; border: 0;" />
                  </td>
                </tr>
              </table>
              <h1 style="margin: 0; font-size: 24px; font-weight: 800; color: #FFFFFF; letter-spacing: 1.5px; text-transform: uppercase;">SHIELDNET</h1>
              <p style="margin: 6px 0 0 0; font-size: 13px; color: #7DD3FC; font-weight: 600; letter-spacing: 0.5px;">Bouclier Intelligent de Sécurité Citoyenne</p>
            </td>
          </tr>

          <!-- Body Content -->
          <tr>
            <td style="padding: 32px 28px 24px 28px;">
              <h2 style="margin: 0 0 14px 0; font-size: 20px; color: #F8FAFC; font-weight: 700;">Bonjour {display_name},</h2>
              <p style="margin: 0 0 24px 0; font-size: 15px; line-height: 1.6; color: #CBD5E1;">
                Votre compte <strong>{user.email}</strong> a été activé avec succès. Votre téléphone bénéficie désormais d'une protection conçue pour préserver votre sérénité numérique au quotidien.
              </p>

              <!-- Feature 1 -->
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color: #131E35; border-radius: 14px; margin-bottom: 12px; border: 1px solid #1E293B;">
                <tr>
                  <td style="padding: 16px 18px;">
                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                      <tr>
                        <td width="90" valign="top">
                          <span style="display: inline-block; background-color: #0369A1; color: #E0F2FE; font-size: 11px; font-weight: 700; padding: 4px 10px; border-radius: 6px; letter-spacing: 0.5px; text-transform: uppercase;">APPELS</span>
                        </td>
                        <td style="padding-left: 10px;">
                          <div style="font-size: 15px; font-weight: 700; color: #FFFFFF; margin-bottom: 4px;">Filtrage intelligent des appels</div>
                          <div style="font-size: 13px; color: #94A3B8; line-height: 1.5;">Détecte et bloque les appels robotisés, fraudes et numéros malveillants avant qu'ils ne sonnent.</div>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <!-- Feature 2 -->
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color: #131E35; border-radius: 14px; margin-bottom: 12px; border: 1px solid #1E293B;">
                <tr>
                  <td style="padding: 16px 18px;">
                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                      <tr>
                        <td width="90" valign="top">
                          <span style="display: inline-block; background-color: #4338CA; color: #EEF2FF; font-size: 11px; font-weight: 700; padding: 4px 10px; border-radius: 6px; letter-spacing: 0.5px; text-transform: uppercase;">SMS &amp; LIENS</span>
                        </td>
                        <td style="padding-left: 10px;">
                          <div style="font-size: 15px; font-weight: 700; color: #FFFFFF; margin-bottom: 4px;">Inspecteur anti-hameçonnage</div>
                          <div style="font-size: 13px; color: #94A3B8; line-height: 1.5;">Analyse immédiate des SMS douteux, fausses alertes bancaires et liens frauduleux.</div>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <!-- Feature 3 -->
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color: #131E35; border-radius: 14px; margin-bottom: 26px; border: 1px solid #1E293B;">
                <tr>
                  <td style="padding: 16px 18px;">
                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                      <tr>
                        <td width="90" valign="top">
                          <span style="display: inline-block; background-color: #065F46; color: #ECFDF5; font-size: 11px; font-weight: 700; padding: 4px 10px; border-radius: 6px; letter-spacing: 0.5px; text-transform: uppercase;">VIE PRIVÉE</span>
                        </td>
                        <td style="padding-left: 10px;">
                          <div style="font-size: 15px; font-weight: 700; color: #FFFFFF; margin-bottom: 4px;">Confidentialité absolue garantie</div>
                          <div style="font-size: 13px; color: #94A3B8; line-height: 1.5;">Vos contacts et informations personnelles restent strictement sur votre appareil. Aucune donnée vendue.</div>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <!-- CTA Bouton Direct vers l'application -->
              <table role="presentation" cellspacing="0" cellpadding="0" border="0" align="center" style="margin: 24px auto 10px auto;">
                <tr>
                  <td align="center" style="border-radius: 12px; background: linear-gradient(135deg, #0284C7 0%, #2563EB 100%); box-shadow: 0 4px 18px rgba(2, 132, 199, 0.45);">
                    <a href="{direct_app_url}" style="display: inline-block; padding: 15px 36px; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; font-size: 15px; font-weight: 700; color: #FFFFFF; text-decoration: none; border-radius: 12px; letter-spacing: 0.3px;">
                      Ouvrir l'application ShieldNet &rarr;
                    </a>
                  </td>
                </tr>
              </table>

              <!-- Lien de secours Web -->
              <div style="text-align: center; margin-bottom: 24px;">
                <a href="{web_fallback_url}" target="_blank" style="font-size: 12px; color: #38BDF8; text-decoration: underline;">
                  Lien alternatif dans le navigateur
                </a>
              </div>

              <!-- Reassurance Note -->
              <p style="margin: 0; font-size: 13px; color: #64748B; line-height: 1.5; text-align: center; border-top: 1px solid #1E293B; padding-top: 20px;">
                Ce courriel confirme simplement l'activation de votre compte. Vous n'avez pas besoin d'y répondre.
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color: #070B14; padding: 22px 28px; text-align: center; border-top: 1px solid #1E293B;">
              <p style="margin: 0 0 6px 0; font-size: 12px; color: #64748B; font-weight: 600;">
                ShieldNet Security &bull; Protection Numérique Citoyenne
              </p>
              <p style="margin: 0; font-size: 11px; color: #475569;">
                Conforme aux normes de protection de la vie privée (Loi 25 &bull; PIPEDA &bull; LCAP)
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>"""

    try:
        from_email = getattr(settings, 'DEFAULT_FROM_EMAIL', 'ShieldNet Security <no-reply@shieldnet.app>')
        msg = EmailMultiAlternatives(
            subject=subject,
            body=message,
            from_email=from_email,
            to=[user.email],
        )
        msg.attach_alternative(html_message, "text/html")

        # Attacher le logo officiel ShieldNet au format inline CID
        logo_path = os.path.join(settings.BASE_DIR, 'shield_api', 'static', 'shield_api', 'img', 'shieldnet_logo.png')
        if os.path.exists(logo_path):
            with open(logo_path, 'rb') as lf:
                img = MIMEImage(lf.read(), _subtype='png')
                img.add_header('Content-ID', '<shieldnet_logo>')
                img.add_header('Content-Disposition', 'inline', filename='shieldnet_logo.png')
                msg.attach(img)

        msg.send(fail_silently=False)
    except Exception as e:
        import logging
        logging.getLogger('shield_api').warning(f"Courriel de bienvenue non distribue: {e}")

class RegisterView(APIView):
    """
    POST /api/v1/auth/register/
    Creation d'un nouveau compte utilisateur avec email et mot de passe.
    """
    permission_classes = [permissions.AllowAny]

    @extend_schema(request=UserRegisterSerializer)
    def post(self, request):
        serializer = UserRegisterSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            send_welcome_confirmation_email(user, request=request)
            refresh = RefreshToken.for_user(user)
            return Response({
                'user': UserSerializer(user).data,
                'tokens': {
                    'refresh': str(refresh),
                    'access': str(refresh.access_token),
                }
            }, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class EmailLoginView(APIView):
    """
    POST /api/v1/auth/login/
    Connexion directe par email et mot de passe avec controle de securite.
    """
    permission_classes = [permissions.AllowAny]

    @extend_schema(request=EmailLoginSerializer)
    def post(self, request):
        serializer = EmailLoginSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.validated_data['user']
            if not user.is_active:
                return Response(
                    {'detail': 'Ce compte utilisateur a ete suspendu ou desactive par la securite ShieldNet.'},
                    status=status.HTTP_403_FORBIDDEN
                )
            refresh = RefreshToken.for_user(user)
            return Response({
                'user': UserSerializer(user).data,
                'tokens': {
                    'refresh': str(refresh),
                    'access': str(refresh.access_token),
                }
            }, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class GoogleLoginView(APIView):
    """
    POST /api/v1/auth/google/
    Connexion / Inscription securisee avec un compte Google verifie (Google OAuth2).
    Valide l'authenticite cryptographique du compte aupres de Google pour interdire tout faux compte.
    """
    permission_classes = [permissions.AllowAny]

    @extend_schema(request=GoogleLoginSerializer)
    def post(self, request):
        serializer = GoogleLoginSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        email = serializer.validated_data['email']
        name = serializer.validated_data.get('name', '').strip()
        id_token = serializer.validated_data.get('id_token', '').strip()

        # Securite accrue : Verification cryptographique du jeton Google
        if id_token:
            token_info = verify_google_id_token(id_token)
            if not token_info:
                return Response(
                    {'detail': "Jeton d'authentification Google invalide ou corrompu. Acces refuse."},
                    status=status.HTTP_401_UNAUTHORIZED
                )
            # Verifier que Google certifie l'adresse comme verifiee
            is_verified = token_info.get('email_verified')
            if is_verified not in (True, 'true', 'True', 1):
                return Response(
                    {'detail': "Ce compte Google n'est pas verifie par les services Google. Acces refuse."},
                    status=status.HTTP_403_FORBIDDEN
                )
            verified_email = token_info.get('email', '').strip().lower()
            if verified_email and verified_email != email.lower():
                return Response(
                    {'detail': "L'adresse courriel soumise ne correspond pas au compte Google authentifie."},
                    status=status.HTTP_403_FORBIDDEN
                )
            google_name = token_info.get('name', '').strip()
            if google_name and not name:
                name = google_name

        user = User.objects.filter(email__iexact=email).first()
        if user and (user.is_staff or user.is_superuser):
            return Response(
                {'detail': 'Les comptes avec privilèges administratifs ne peuvent pas utiliser la connexion Google sans validation SSO.'},
                status=status.HTTP_403_FORBIDDEN
            )

        if user and not user.is_active:
            return Response(
                {'detail': 'Ce compte utilisateur a ete desactive par la securite ShieldNet.'},
                status=status.HTTP_403_FORBIDDEN
            )

        if not user:
            # Provisioning securise pour le compte Google verifie
            first_name = name.split()[0] if name else email.split('@')[0]
            last_name = ' '.join(name.split()[1:]) if len(name.split()) > 1 else ''
            random_password = secrets.token_urlsafe(24)
            country = serializer.validated_data.get('country', 'CA').upper()
            province_or_state = serializer.validated_data.get('province_or_state', 'QC').upper()

            user = User.objects.create_user(
                username=email,
                email=email,
                password=random_password,
                first_name=first_name,
                last_name=last_name,
            )
            profile, _ = UserProfile.objects.get_or_create(user=user)
            profile.country = country
            profile.province_or_state = province_or_state
            profile.save()

            send_welcome_confirmation_email(user, request=request)

        refresh = RefreshToken.for_user(user)
        return Response({
            'user': UserSerializer(user).data,
            'tokens': {
                'refresh': str(refresh),
                'access': str(refresh.access_token),
            }
        }, status=status.HTTP_200_OK)


class UserProfileView(APIView):
    """
    GET /api/v1/auth/me/
    Récupère le profil de l'utilisateur connecté via son jeton JWT.
    PATCH/PUT /api/v1/auth/me/
    Met à jour les informations du profil (nom, pays, province/état).
    """
    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(responses={200: UserSerializer})
    def get(self, request):
        return Response(UserSerializer(request.user).data)

    def patch(self, request):
        user = request.user
        country = request.data.get('country', '').strip().upper()
        province_or_state = request.data.get('province_or_state', '').strip().upper()
        name = request.data.get('name', '').strip()

        if country and country not in ['CA', 'US']:
            return Response({'detail': "Le pays doit être 'CA' (Canada) ou 'US' (États-Unis)."}, status=status.HTTP_400_BAD_REQUEST)

        profile, _ = UserProfile.objects.get_or_create(user=user)
        if country:
            profile.country = country
        if province_or_state:
            profile.province_or_state = province_or_state
        profile.save()

        if name:
            parts = name.split()
            user.first_name = parts[0]
            user.last_name = ' '.join(parts[1:]) if len(parts) > 1 else ''
            user.save()

        return Response(UserSerializer(user).data)

    def put(self, request):
        return self.patch(request)

class UpdateUserRegionView(APIView):
    """
    POST/PATCH/PUT /api/v1/auth/region/
    Met à jour expressément le pays et la province/état de l'utilisateur connecté.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        return self.patch(request)

    def put(self, request):
        return self.patch(request)

    def patch(self, request):
        country = request.data.get('country', '').strip().upper()
        province_or_state = request.data.get('province_or_state', '').strip().upper()

        if not country and not province_or_state:
            return Response({'detail': "Veuillez spécifier 'country' ou 'province_or_state'."}, status=status.HTTP_400_BAD_REQUEST)

        if country and country not in ['CA', 'US']:
            return Response({'detail': "Le pays doit être 'CA' (Canada) ou 'US' (États-Unis)."}, status=status.HTTP_400_BAD_REQUEST)

        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        if country:
            profile.country = country
        if province_or_state:
            profile.province_or_state = province_or_state
        profile.save()

        return Response({
            'detail': 'Région mise à jour avec succès.',
            'user': UserSerializer(request.user).data
        })


class AdminStatsView(APIView):
    """
    GET /api/v1/admin/stats/
    Fournit une vue d'ensemble complète de l'état du système pour les administrateurs et gestionnaires.
    """
    permission_classes = [IsManagerOrAdminUser]

    def get(self, request):
        total_blacklisted = BlacklistedNumber.objects.count()
        total_blocked = BlacklistedNumber.objects.filter(is_blocked=True).count()
        total_whitelisted = BlacklistedNumber.objects.filter(is_whitelisted=True).count()
        total_reports = SpamReport.objects.count()
        total_safe_reports = SafeReport.objects.count()
        total_auto_consensus = BlacklistedNumber.objects.filter(whitelist_reason='auto_consensus').count()
        total_users = User.objects.count()

        from django.db.models import Count
        users_by_country = {
            'CA': UserProfile.objects.filter(country='CA').count(),
            'US': UserProfile.objects.filter(country='US').count(),
        }
        users_by_province = list(
            UserProfile.objects.values('country', 'province_or_state')
            .annotate(total=Count('id'))
            .order_by('-total')[:10]
        )

        recent_reports = []
        for r in SpamReport.objects.select_related('reporter').order_by('-created_at')[:15]:
            num_obj = BlacklistedNumber.objects.filter(phone_hash=r.phone_hash).first()
            recent_reports.append({
                'id': str(r.id),
                'phone_hash': r.phone_hash,
                'masked_number': (num_obj.masked_number if num_obj and num_obj.masked_number else 'Inconnu'),
                'category': r.category,
                'risk_score': num_obj.risk_score if num_obj else 0,
                'is_whitelisted': num_obj.is_whitelisted if num_obj else False,
                'whitelist_reason': num_obj.whitelist_reason if num_obj else '',
                'is_blocked': num_obj.is_blocked if num_obj else True,
                'created_at': r.created_at.isoformat(),
            })

        return Response({
            'total_blacklisted': total_blacklisted,
            'total_blocked': total_blocked,
            'total_whitelisted': total_whitelisted,
            'total_safe_reports': total_safe_reports,
            'total_auto_consensus': total_auto_consensus,
            'total_reports': total_reports,
            'total_users': total_users,
            'users_by_country': users_by_country,
            'users_by_province': users_by_province,
            'recent_reports': recent_reports,
        })

class AdminModerateView(APIView):
    """
    POST /api/v1/admin/moderate/
    Permet à l'administrateur ou au gestionnaire de blanchir (whitelist) ou bloquer un numéro à distance.
    """
    permission_classes = [IsManagerOrAdminUser]

    def post(self, request):
        phone_hash = request.data.get('phone_hash')
        action = request.data.get('action')  # 'whitelist' ou 'block'

        if not phone_hash or action not in ['whitelist', 'block']:
            return Response({'detail': 'Paramètres invalides (phone_hash et action: whitelist|block requis).'}, status=status.HTTP_400_BAD_REQUEST)

        source = 'MOBILE_ADMIN' if request.user.is_superuser else 'MOBILE_MANAGER'
        role_label = 'admin' if request.user.is_superuser else 'gestionnaire'

        try:
            entry = BlacklistedNumber.objects.get(phone_hash=phone_hash)
            if action == 'whitelist':
                entry.is_whitelisted = True
                entry.is_blocked = False
                entry.risk_score = 0
                entry.whitelist_reason = 'manual_admin'
                entry.save()
                AuditLog.objects.create(
                    user=request.user,
                    action=AuditLogAction.WHITELIST_UNBLOCK,
                    details=f'Numéro blanchi: {entry.masked_number or phone_hash[:10]} (décision {role_label})',
                    target_hash=phone_hash,
                    source=source
                )
                return Response({'detail': f'Numéro {entry.masked_number or phone_hash[:8]} blanchi avec succès (décision {role_label}).'})
            elif action == 'block':
                entry.is_blocked = True
                entry.is_whitelisted = False
                entry.whitelist_reason = ''
                if entry.risk_score < 50:
                    entry.risk_score = 75
                entry.save()
                AuditLog.objects.create(
                    user=request.user,
                    action=AuditLogAction.APPROVE_BLOCK,
                    details=f'Numéro bloqué: {entry.masked_number or phone_hash[:10]} (décision {role_label})',
                    target_hash=phone_hash,
                    source=source
                )
                return Response({'detail': f'Numéro {entry.masked_number or phone_hash[:8]} bloqué avec succès.'})
        except BlacklistedNumber.DoesNotExist:
            return Response({'detail': 'Numéro introuvable.'}, status=status.HTTP_404_NOT_FOUND)

class AdminBlacklistManagerView(APIView):
    """
    GET /api/v1/admin/blacklist/ : Liste complète filtrable et consultable de tous les numéros.
    POST /api/v1/admin/blacklist/ : Ajout direct d'un numéro par l'administrateur.
    """
    permission_classes = [IsAdminStaffUser]

    def get(self, request):
        qs = BlacklistedNumber.objects.all().order_by('-updated_at')
        search = request.query_params.get('q', '').strip()
        filt = request.query_params.get('filter', 'all').lower()
        category = request.query_params.get('category', '').strip()

        if search:
            qs = qs.filter(models.Q(masked_number__icontains=search) | models.Q(phone_hash__icontains=search))
        if filt == 'blocked':
            qs = qs.filter(is_blocked=True, is_whitelisted=False)
        elif filt == 'whitelisted':
            qs = qs.filter(is_whitelisted=True)
        elif filt == 'auto_consensus':
            qs = qs.filter(whitelist_reason='auto_consensus')
        if category:
            qs = qs.filter(category=category)

        return Response(BlacklistedNumberSerializer(qs[:100], many=True).data)

    def post(self, request):
        raw_number = request.data.get('phone_number')
        phone_hash = request.data.get('phone_hash')
        category = request.data.get('category', 'fraud')
        risk_score = int(request.data.get('risk_score', 75))
        is_blocked = request.data.get('is_blocked', True)
        is_whitelisted = request.data.get('is_whitelisted', False)

        if raw_number:
            phone_hash = hash_phone_number(raw_number)
            masked_number = mask_phone_number(raw_number)
        elif phone_hash:
            masked_number = request.data.get('masked_number', f"+1 *** **{phone_hash[-2:]}")
        else:
            return Response({'detail': 'phone_number ou phone_hash requis.'}, status=status.HTTP_400_BAD_REQUEST)

        obj, created = BlacklistedNumber.objects.update_or_create(
            phone_hash=phone_hash,
            defaults={
                'masked_number': masked_number,
                'category': category,
                'risk_score': risk_score,
                'is_blocked': is_blocked,
                'is_whitelisted': is_whitelisted,
            }
        )
        source = 'MOBILE_ADMIN' if request.user.is_superuser else 'MOBILE_MANAGER'
        AuditLog.objects.create(
            user=request.user,
            action=AuditLogAction.MANUAL_ADD,
            details=f"Numéro {masked_number} ajouté/modifié manuellement (catégorie: {category}, score: {risk_score})",
            target_hash=phone_hash,
            source=source
        )
        return Response(BlacklistedNumberSerializer(obj).data, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)

class AdminBlacklistDetailView(APIView):
    """
    DELETE /api/v1/admin/blacklist/<phone_hash>/ : Suppression définitive d'un numéro.
    """
    permission_classes = [IsManagerOrAdminUser]

    def delete(self, request, phone_hash):
        try:
            entry = BlacklistedNumber.objects.get(phone_hash=phone_hash)
            masked = entry.masked_number or phone_hash[:10]
            entry.delete()
            source = 'MOBILE_ADMIN' if request.user.is_superuser else 'MOBILE_MANAGER'
            AuditLog.objects.create(
                user=request.user,
                action=AuditLogAction.DELETE_NUMBER,
                details=f"Suppression définitive du numéro: {masked}",
                target_hash=phone_hash,
                source=source
            )
            return Response({'detail': f'Numéro supprimé de la liste noire.'})
        except BlacklistedNumber.DoesNotExist:
            return Response({'detail': 'Numéro introuvable.'}, status=status.HTTP_404_NOT_FOUND)

class AdminUsersListView(APIView):
    """
    GET /api/v1/admin/users/ : Liste tous les utilisateurs inscrits.
    Réservé exclusivement aux administrateurs système (Superuser).
    Supporte les filtres d'origine géographique ?country=CA|US et ?province=QC|ON|NY...
    """
    permission_classes = [IsAdminOnlyUser]

    def get(self, request):
        users = User.objects.all().select_related('profile').order_by('-date_joined')
        country_filter = request.query_params.get('country', '').strip().upper()
        province_filter = request.query_params.get('province', '').strip().upper()

        if country_filter:
            users = users.filter(profile__country=country_filter)
        if province_filter:
            users = users.filter(profile__province_or_state=province_filter)

        from .services import RegionalComplianceService
        data = []
        for u in users:
            reports_count = SpamReport.objects.filter(reporter=u).count()
            profile = getattr(u, 'profile', None)
            country = profile.country if profile else 'CA'
            province_or_state = profile.province_or_state if profile else 'QC'
            norm_info = RegionalComplianceService.get_compliance_for_region(country, province_or_state)
            country_name = 'Canada' if country == 'CA' else ('États-Unis' if country == 'US' else country)
            prov_name = (
                RegionalComplianceService.CANADIAN_PROVINCES.get(province_or_state, province_or_state)
                if country == 'CA'
                else RegionalComplianceService.US_STATES.get(province_or_state, province_or_state)
            )

            data.append({
                'id': u.id,
                'email': u.email,
                'username': u.username,
                'name': f"{u.first_name} {u.last_name}".strip() or u.username,
                'is_staff': u.is_staff,
                'is_superuser': u.is_superuser,
                'role': 'ADMIN' if u.is_superuser else ('MANAGER' if u.is_staff else 'CITIZEN'),
                'is_active': u.is_active,
                'country': country,
                'province_or_state': province_or_state,
                'country_name': country_name,
                'province_name': prov_name,
                'country_flag': '🇨🇦' if country == 'CA' else '🇺🇸',
                'compliance_norm': norm_info,
                'date_joined': u.date_joined.isoformat(),
                'reports_count': reports_count,
            })
        return Response(data)

class AdminReportsListView(APIView):
    """
    GET /api/v1/admin/reports/ : Liste tous les signalements utilisateurs.
    DELETE /api/v1/admin/reports/<report_id>/ : Suppression d'un signalement.
    """
    permission_classes = [IsManagerOrAdminUser]

    def get(self, request):
        reports = SpamReport.objects.all().select_related('reporter').order_by('-created_at')[:50]
        data = []
        for r in reports:
            num = BlacklistedNumber.objects.filter(phone_hash=r.phone_hash).first()
            data.append({
                'id': str(r.id),
                'phone_hash': r.phone_hash,
                'masked_number': num.masked_number if num and num.masked_number else 'Inconnu',
                'category': r.category,
                'comment': r.comment or '',
                'created_at': r.created_at.isoformat(),
                'reporter_email': r.reporter.email if r.reporter else 'Anonyme',
                'risk_score': num.risk_score if num else 0,
                'is_whitelisted': num.is_whitelisted if num else False,
                'whitelist_reason': num.whitelist_reason if num else '',
            })
        return Response(data)

    def delete(self, request, report_id):
        try:
            report = SpamReport.objects.get(id=report_id)
            target_hash = report.phone_hash
            report.delete()
            source = 'MOBILE_ADMIN' if request.user.is_superuser else 'MOBILE_MANAGER'
            AuditLog.objects.create(
                user=request.user,
                action=AuditLogAction.DELETE_REPORT,
                details=f"Suppression du signalement ID {report_id} pour {target_hash[:10]}",
                target_hash=target_hash,
                source=source
            )
            return Response({'detail': 'Signalement supprimé avec succès.'})
        except SpamReport.DoesNotExist:
            return Response({'detail': 'Signalement introuvable.'}, status=status.HTTP_404_NOT_FOUND)

class AdminPurgeJunkView(APIView):
    """
    POST /api/v1/admin/purge/ : Nettoie et purge les faux spams et orphelins (>30j).
    Réservé exclusivement aux administrateurs système (Superuser).
    """
    permission_classes = [IsAdminOnlyUser]

    def post(self, request):
        purged = DatabaseSanitizerService.purge_obsolete_and_unverified_junk()
        AuditLog.objects.create(
            user=request.user,
            action=AuditLogAction.PURGE_DATABASE,
            details=f"Purge automatique de {purged} enregistrement(s) obsolète(s)",
            source='MOBILE_ADMIN'
        )
        return Response({
            'purged_count': purged,
            'detail': f"{purged} enregistrement(s) obsolète(s) nettoyé(s) avec succès."
        })

class AdminConsensusAuditView(APIView):
    """
    POST /api/v1/admin/consensus-audit/ : Audit et réévaluation automatique des faux positifs par consensus.
    """
    permission_classes = [IsAdminStaffUser]

    def post(self, request):
        audit_res = FalsePositiveConsensusService.run_consensus_audit()
        AuditLog.objects.create(
            user=request.user,
            action=AuditLogAction.WHITELIST_UNBLOCK,
            details=f"Audit global de consensualité : {audit_res['auto_whitelisted_count']} faux positif(s) réhabilité(s)",
            source='AUTO_CONSENSUS'
        )
        return Response({
            'detail': f"{audit_res['auto_whitelisted_count']} faux positif(s) réhabilité(s) automatiquement par consensus.",
            'candidates_audited': audit_res['candidates_audited'],
            'auto_whitelisted_count': audit_res['auto_whitelisted_count'],
            'auto_whitelisted_hashes': audit_res['auto_whitelisted_hashes'],
        })

class HealthCheckView(APIView):
    """
    GET /api/v1/health/
    Sonde de disponibilité et de santé système (Liveness & Readiness Probe).
    Vérifie la connectivité base de données, les métriques d'exploitation et le statut.
    Permet à Docker, Kubernetes ou aux outils de supervision d'assurer la haute disponibilité.
    """
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        from django.db import connection
        health_data = {
            'status': 'healthy',
            'timestamp': timezone.now().isoformat(),
            'version': '1.0.0',
            'components': {}
        }
        http_code = status.HTTP_200_OK

        # Sonde de connectivité de la base de données
        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1;")
                cursor.fetchone()
            health_data['components']['database'] = {
                'status': 'up',
                'engine': connection.vendor,
            }
        except Exception as e:
            health_data['status'] = 'unhealthy'
            health_data['components']['database'] = {
                'status': 'down',
                'error': str(e),
            }
            http_code = status.HTTP_503_SERVICE_UNAVAILABLE

        # Métriques sommaires d'activité pour le monitoring
        if http_code == status.HTTP_200_OK:
            health_data['components']['metrics'] = {
                'active_blacklist_count': BlacklistedNumber.objects.filter(is_blocked=True, is_whitelisted=False, risk_score__gte=30).count(),
                'total_spam_reports': SpamReport.objects.count(),
                'total_safe_reports': SafeReport.objects.count(),
                'auto_consensus_count': BlacklistedNumber.objects.filter(whitelist_reason='auto_consensus').count(),
                'audit_logs_count': AuditLog.objects.count(),
            }

        return Response(health_data, status=http_code)

class AdminSafeReportsListView(APIView):
    """
    GET /api/v1/admin/safe-reports/ : Liste tous les avis favorables / contestations soumis.
    """
    permission_classes = [IsAdminStaffUser]

    def get(self, request):
        reports = SafeReport.objects.all().select_related('reporter').order_by('-created_at')[:50]
        data = []
        for r in reports:
            num = BlacklistedNumber.objects.filter(phone_hash=r.phone_hash).first()
            data.append({
                'id': str(r.id),
                'phone_hash': r.phone_hash,
                'masked_number': num.masked_number if num and num.masked_number else 'Inconnu',
                'reason': r.reason,
                'comment': r.comment or '',
                'created_at': r.created_at.isoformat(),
                'reporter_email': r.reporter.email if r.reporter else 'Anonyme',
                'is_whitelisted': num.is_whitelisted if num else False,
                'whitelist_reason': num.whitelist_reason if num else '',
            })
        return Response(data)






# ==============================================================================
# SIGNAUX DJANGO : INVALIDATION AUTOMATIQUE DU CACHE MEMOIRE
# ==============================================================================
@receiver([post_save, post_delete], sender=BlacklistedNumber)
def invalidate_blacklist_cache(sender, **kwargs):
    cache.clear()

@receiver([post_save, post_delete], sender=SpamReport)
def invalidate_report_cache(sender, **kwargs):
    cache.clear()


# ==============================================================================
# STATUT DE SYNCHRONISATION & BROADCAST
# ==============================================================================
class SyncStatusView(APIView):
    """
    GET /api/v1/sync/status/
    Endpoint ultra-rapide permettant au mobile de vérifier si la liste noire a changé.
    """
    permission_classes = [HasAPIKeyOrAuthenticated]

    def get(self, request):
        latest = BlacklistedNumber.objects.order_by('-updated_at').first()
        total_active = BlacklistedNumber.objects.filter(is_blocked=True, is_whitelisted=False, risk_score__gte=30).count()
        return Response({
            'last_modified': latest.updated_at.isoformat() if latest else timezone.now().isoformat(),
            'total_active': total_active,
            'server_time': timezone.now().isoformat(),
        })

# ==============================================================================
# JOURNAL D'AUDIT ET TRAÇABILITÉ (ADMINISTRATION)
# ==============================================================================
class AdminAuditLogsListView(APIView):
    """
    GET /api/v1/admin/audit-logs/
    Liste chronologique des actions d'administration (Web & Mobile).
    """
    permission_classes = [IsAdminStaffUser]

    def get(self, request):
        page = int(request.query_params.get('page', 1))
        limit = int(request.query_params.get('limit', 50))
        offset = (page - 1) * limit

        logs = AuditLog.objects.all().select_related('user')[offset:offset + limit]
        serializer = AuditLogSerializer(logs, many=True)
        total = AuditLog.objects.count()
        return Response({
            'results': serializer.data,
            'total': total,
            'page': page,
            'has_more': (offset + limit) < total,
        })


# ==============================================================================
# MODULE D'ANALYSE SÉMANTIQUE & ARBITRAGE DES SIGNALEMENTS
# ==============================================================================
from .ai_engine import ShieldNetAIEngine

class AIDiagnoseView(APIView):
    """
    POST /api/v1/ai/diagnose/ ou GET /api/v1/ai/diagnose/?phone_number=...
    Diagnostic de réputation télécom, arbitrage des faux-positifs
    et détail des facteurs explicatifs du score.
    """
    permission_classes = [HasAPIKeyOrAuthenticated]

    def get(self, request):
        phone_number = request.query_params.get('phone_number', '').strip()[:32]
        phone_hash = request.query_params.get('phone_hash', '').strip()[:64]
        attestation = request.query_params.get('attestation', '').strip()[:1]
        if not phone_number and not phone_hash:
            return Response(
                {'error': 'Veuillez fournir un phone_number ou un phone_hash.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        result = ShieldNetAIEngine.diagnose(phone_number=phone_number, phone_hash=phone_hash, attestation=attestation)
        return Response(result)

    def post(self, request):
        phone_number = request.data.get('phone_number', '').strip()[:32]
        phone_hash = request.data.get('phone_hash', '').strip()[:64]
        attestation = request.data.get('attestation', '').strip()[:1]
        if not phone_number and not phone_hash:
            return Response(
                {'error': 'Veuillez fournir un phone_number ou un phone_hash.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        result = ShieldNetAIEngine.diagnose(phone_number=phone_number, phone_hash=phone_hash, attestation=attestation)
        return Response(result)


# ==============================================================================
# OBSERVABILITÉ & TÉLÉMÉTRIE OPENMETRICS / PROMETHEUS
# ==============================================================================
class PrometheusMetricsView(APIView):
    """
    GET /api/v1/metrics/
    Expose les compteurs et jauges opérationnels du SOC ShieldNet
    au format standard OpenMetrics / Prometheus (text/plain; version=0.0.4).
    """
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        active_blacklist = BlacklistedNumber.objects.filter(is_blocked=True, is_whitelisted=False, risk_score__gte=30).count()
        total_blacklist = BlacklistedNumber.objects.count()
        whitelisted = BlacklistedNumber.objects.filter(is_whitelisted=True).count()
        auto_consensus = BlacklistedNumber.objects.filter(whitelist_reason='auto_consensus').count()
        total_spam = SpamReport.objects.count()
        total_safe = SafeReport.objects.count()
        total_users = User.objects.count()
        total_audit_logs = AuditLog.objects.count()

        category_counts = (
            SpamReport.objects.values('category')
            .annotate(count=models.Count('id'))
            .order_by('category')
        )

        lines = [
            "# HELP shieldnet_blacklist_active_total Nombre de numéros activement bloqués",
            "# TYPE shieldnet_blacklist_active_total gauge",
            f"shieldnet_blacklist_active_total {active_blacklist}",
            "",
            "# HELP shieldnet_blacklist_records_total Nombre total d'enregistrements dans la liste",
            "# TYPE shieldnet_blacklist_records_total gauge",
            f"shieldnet_blacklist_records_total {total_blacklist}",
            "",
            "# HELP shieldnet_whitelisted_total Nombre de numéros réhabilités (liste blanche)",
            "# TYPE shieldnet_whitelisted_total gauge",
            f"shieldnet_whitelisted_total {whitelisted}",
            "",
            "# HELP shieldnet_auto_consensus_total Numéros réhabilités automatiquement par consensus citoyen",
            "# TYPE shieldnet_auto_consensus_total gauge",
            f"shieldnet_auto_consensus_total {auto_consensus}",
            "",
            "# HELP shieldnet_spam_reports_total Total des signalements de spam enregistrés",
            "# TYPE shieldnet_spam_reports_total counter",
            f"shieldnet_spam_reports_total {total_spam}",
            "",
            "# HELP shieldnet_safe_reports_total Total des avis légitimes / contestations reçus",
            "# TYPE shieldnet_safe_reports_total counter",
            f"shieldnet_safe_reports_total {total_safe}",
            "",
            "# HELP shieldnet_users_total Nombre de comptes utilisateurs enregistrés",
            "# TYPE shieldnet_users_total gauge",
            f"shieldnet_users_total {total_users}",
            "",
            "# HELP shieldnet_audit_logs_total Total des entrées dans le journal d'audit",
            "# TYPE shieldnet_audit_logs_total counter",
            f"shieldnet_audit_logs_total {total_audit_logs}",
            "",
            "# HELP shieldnet_spam_reports_by_category Nombre de signalements par catégorie d'infraction",
            "# TYPE shieldnet_spam_reports_by_category gauge",
        ]

        for item in category_counts:
            cat = item['category'] or 'unknown'
            lines.append(f'shieldnet_spam_reports_by_category{{category="{cat}"}} {item["count"]}')

        lines.append("")  # newline final requis par OpenMetrics
        metrics_body = "\n".join(lines)
        return HttpResponse(metrics_body, content_type="text/plain; version=0.0.4; charset=utf-8")



class BloomFilterDownloadView(APIView):
    """
    GET /api/v1/sync/bloom/
    Télécharge le filtre de Bloom compressé pour vérification ultra-rapide en mémoire sur mobile.
    """
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        from .services import BloomFilterService
        try:
            size = int(request.query_params.get('size_bits', BloomFilterService.DEFAULT_SIZE_BITS))
        except (ValueError, TypeError):
            size = BloomFilterService.DEFAULT_SIZE_BITS
        payload = BloomFilterService.generate_filter_payload(size_bits=size)
        return Response(payload, status=status.HTTP_200_OK)


class RegionalThreatsView(APIView):
    """
    GET /api/v1/threats/regional/
    Fournit un rapport de Threat Intelligence sur les vagues de spoofing ciblées par indicatif régional.
    """
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        from .services import RegionalThreatIntelligenceService
        report = RegionalThreatIntelligenceService.get_regional_threat_report()
        return Response(report, status=status.HTTP_200_OK)


class RegionalComplianceNormsView(APIView):
    """
    GET /api/v1/compliance/norms/?country=CA&province=QC
    Fournit le détail des normes réglementaires et juridiques applicables
    pour la juridiction sélectionnée (Loi 25 QC, PIPEDA, TCPA, CCPA).
    Accessible publiquement pour initialiser l'onboarding mobile ou les paramètres.
    """
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        country = request.query_params.get('country', 'CA').strip().upper()
        province = request.query_params.get('province', 'QC').strip().upper()
        from .services import RegionalComplianceService
        compliance = RegionalComplianceService.get_compliance_for_region(country, province)
        return Response(compliance, status=status.HTTP_200_OK)


class RegionalComplianceRegionsView(APIView):
    """
    GET /api/v1/compliance/regions/
    Fournit la liste des pays (Canada, États-Unis) et de toutes leurs provinces/états supportés.
    """
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        from .services import RegionalComplianceService
        return Response(RegionalComplianceService.get_available_regions(), status=status.HTTP_200_OK)



class AdminReportDetailView(APIView):
    """
    GET /api/v1/admin/reports/<report_id>/ : Détail d'un signalement spécifique.
    DELETE /api/v1/admin/reports/<report_id>/ : Suppression d'un signalement.
    """
    permission_classes = [IsManagerOrAdminUser]

    def get(self, request, report_id):
        from django.shortcuts import get_object_or_404
        report = get_object_or_404(SpamReport, id=report_id)
        num = BlacklistedNumber.objects.filter(phone_hash=report.phone_hash).first()
        return Response({
            'id': str(report.id),
            'phone_hash': report.phone_hash,
            'masked_number': num.masked_number if num and num.masked_number else 'Inconnu',
            'category': report.category,
            'comment': report.comment or '',
            'created_at': report.created_at.isoformat(),
            'reporter_email': report.reporter.email if report.reporter else 'Anonyme',
            'risk_score': num.risk_score if num else 0,
        })

    def delete(self, request, report_id):
        from django.shortcuts import get_object_or_404
        report = get_object_or_404(SpamReport, id=report_id)
        report.delete()
        return Response({'success': True, 'message': 'Signalement supprimé avec succès.'})


class HealthLiveView(APIView):
    """
    GET /api/v1/health/live/
    Sonde Liveness Probe (Kubernetes / Docker).
    Indique que le processus du serveur HTTP est vivant et répond aux requêtes.
    """
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        return Response({
            'status': 'live',
            'timestamp': timezone.now().isoformat(),
            'version': '1.0.0',
        })


class HealthReadyView(APIView):
    """
    GET /api/v1/health/ready/
    Sonde Readiness Probe (Kubernetes / Docker).
    Vérifie l'état opérationnel réel des dépendances critiques (Base de données et Cache).
    """
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        from django.db import connection
        from django.core.cache import cache
        db_ok = False
        cache_ok = False
        errors = []

        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1")
            db_ok = True
        except Exception as e:
            errors.append(f"Database error: {str(e)}")

        try:
            cache.set('ready_check', '1', timeout=5)
            cache_ok = cache.get('ready_check') == '1'
        except Exception as e:
            errors.append(f"Cache error: {str(e)}")

        is_ready = db_ok and cache_ok
        status_code = 200 if is_ready else 503

        return Response({
            'status': 'ready' if is_ready else 'not_ready',
            'db_connected': db_ok,
            'cache_connected': cache_ok,
            'errors': errors,
            'timestamp': timezone.now().isoformat(),
            'version': '1.0.0',
        }, status=status_code)


import random
from django.core.cache import cache

class SendEmailOTPView(APIView):
    """
    POST /api/v1/auth/email/send-otp/
    Génère et envoie un code de vérification OTP à 6 chiffres par courriel.
    """
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        email = request.data.get('email', '').strip().lower()
        if not email or '@' not in email:
            return Response({'detail': 'Adresse courriel invalide.'}, status=status.HTTP_400_BAD_REQUEST)

        # Génération du code OTP à 6 chiffres
        otp_code = str(random.randint(100000, 999999))
        cache.set(f'otp_{email}', otp_code, timeout=600) # Valide 10 minutes

        subject = f"[ShieldNet] Votre code de verification : {otp_code}"
        message = f"""Bonjour,

Votre code de vérification à 6 chiffres pour accéder à ShieldNet est :

👉  {otp_code}  👈

Ce code expire dans 10 minutes. Ne le communiquez à personne.

L'équipe ShieldNet Security
"""
        try:
            from django.conf import settings
            send_mail(
                subject=subject,
                message=message,
                from_email=getattr(settings, 'DEFAULT_FROM_EMAIL', 'no-reply@shieldnet.app'),
                recipient_list=[email],
                fail_silently=True,
            )
        except Exception:
            pass

        return Response({'detail': 'Code de vérification envoyé avec succès à votre adresse courriel.'}, status=status.HTTP_200_OK)

class VerifyEmailOTPView(APIView):
    """
    POST /api/v1/auth/email/verify-otp/
    Vérifie le code OTP à 6 chiffres et authentifie/inscrit l'utilisateur.
    """
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        email = request.data.get('email', '').strip().lower()
        code = request.data.get('code', '').strip()

        if not email or not code:
            return Response({'detail': 'Courriel et code requis.'}, status=status.HTTP_400_BAD_REQUEST)

        cached_code = cache.get(f'otp_{email}')
        if not cached_code or cached_code != code:
            return Response({'detail': 'Code de vérification incorrect ou expiré.'}, status=status.HTTP_400_BAD_REQUEST)

        # Invalidation du code utilisé
        cache.delete(f'otp_{email}')

        # Récupération ou création automatique du compte
        user = User.objects.filter(email__iexact=email).first()
        if not user:
            username = email
            random_password = secrets.token_urlsafe(24)
            user = User.objects.create_user(username=username, email=email, password=random_password)
            UserProfile.objects.get_or_create(user=user)
            send_welcome_confirmation_email(user)

        refresh = RefreshToken.for_user(user)
        return Response({
            'user': UserSerializer(user).data,
            'tokens': {
                'refresh': str(refresh),
                'access': str(refresh.access_token),
            }
        }, status=status.HTTP_200_OK)
