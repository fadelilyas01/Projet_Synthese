import uuid
from django.db import models
from django.core.validators import RegexValidator
from django.contrib.auth.models import User

sha256_validator = RegexValidator(
    regex=r'^[a-fA-F0-9]{64}$',
    message="L'empreinte phone_hash doit être un hash SHA-256 hexadécimal valide de 64 caractères."
)

class CategoryChoices(models.TextChoices):
    FRAUD = 'fraud', 'Fraude / Arnaque'
    TELEMARKETING = 'telemarketing', 'Démarchage commercial'
    FINANCIAL_SCAM = 'financial_scam', 'Arnaque financière'
    PHISHING = 'phishing', 'Hameçonnage / Phishing'
    ROBOCALL = 'robocall', 'Appel automatisé / Robocall'
    OTHER = 'other', 'Autre nuisance'

class BlacklistedNumber(models.Model):
    """
    Représente un numéro dans la liste noire globale collaborative.
    """
    phone_hash = models.CharField(
        max_length=64,
        unique=True,
        db_index=True,
        validators=[sha256_validator],
        help_text="Empreinte SHA-256 anonymisée du numéro de téléphone"
    )
    masked_number = models.CharField(
        max_length=30,
        blank=True,
        null=True,
        help_text="Numéro partiellement masqué pour affichage admin (ex: +1 819 *** **67)"
    )
    category = models.CharField(
        max_length=30,
        choices=CategoryChoices.choices,
        default=CategoryChoices.FRAUD
    )
    risk_score = models.IntegerField(
        default=0,
        help_text="Score de réputation calculé de 0 (faible) à 100 (extrême)"
    )
    reports_count = models.IntegerField(
        default=1,
        help_text="Nombre total de signalements croisés"
    )
    is_blocked = models.BooleanField(
        default=True,
        help_text="Indique si le numéro est actif dans la liste noire diffusée au mobile"
    )
    is_whitelisted = models.BooleanField(
        default=False,
        help_text="Indique si le numéro a été blanchi / approuvé (faux positif résolu)"
    )
    whitelist_reason = models.CharField(
        max_length=50,
        blank=True,
        null=True,
        default='',
        help_text="Origine de la décision de blanchiment : 'auto_consensus', 'manual_admin', etc."
    )
    safe_reports_count = models.IntegerField(
        default=0,
        help_text="Nombre total d'avis favorables ou contestations de faux positif soumis"
    )
    consensus_score = models.FloatField(
        default=0.0,
        help_text="Score de consensualité légitime calculé de 0.0 (100% spam) à 1.0 (100% légitime)"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Numéro Indésirable"
        verbose_name_plural = "Liste Noire Globale"
        ordering = ['-risk_score', '-reports_count']
        indexes = [
            models.Index(fields=['is_blocked', 'is_whitelisted', 'risk_score'], name='idx_bl_active_filter'),
            models.Index(fields=['updated_at'], name='idx_bl_updated_at'),
            models.Index(fields=['phone_hash', 'is_blocked'], name='idx_bl_hash_blocked'),
        ]

    def __str__(self):
        return f"{self.masked_number or self.phone_hash[:12]} (Score: {self.risk_score})"

class SpamReport(models.Model):
    """
    Représente un signalement individuel soumis par un utilisateur mobile.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    reporter = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='spam_reports'
    )
    phone_hash = models.CharField(
        max_length=64,
        db_index=True,
        validators=[sha256_validator],
        help_text="Empreinte SHA-256 du numéro signalé"
    )
    category = models.CharField(max_length=30, choices=CategoryChoices.choices)
    comment = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Signalement utilisateur"
        verbose_name_plural = "Signalements communautaires"
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['phone_hash', 'created_at'], name='idx_spam_hash_created'),
            models.Index(fields=['category', 'created_at'], name='idx_spam_cat_created'),
        ]

    def __str__(self):
        return f"Signalement {self.category} -> {self.phone_hash[:10]}"

class SafeReasonChoices(models.TextChoices):
    LEGITIMATE_SERVICE = 'service', 'Service légitime / Entreprise certifiée'
    PERSONAL_CONTACT = 'personal', 'Contact personnel / Famille / Ami'
    DELIVERY = 'delivery', 'Service de livraison / Transport'
    MEDICAL = 'medical', 'Santé / Cabinet médical / Urgence'
    MISTAKE = 'mistake', 'Erreur de signalement préalable'
    OTHER = 'other', 'Autre usage légitime'

class SafeReport(models.Model):
    """
    Représente un avis favorable ou une contestation de blocage émise par un utilisateur.
    Brique fondamentale du mécanisme de consensualité pour la détection automatique des faux positifs.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    reporter = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='safe_reports'
    )
    phone_hash = models.CharField(
        max_length=64,
        db_index=True,
        validators=[sha256_validator],
        help_text="Empreinte SHA-256 du numéro contesté"
    )
    reason = models.CharField(
        max_length=30,
        choices=SafeReasonChoices.choices,
        default=SafeReasonChoices.LEGITIMATE_SERVICE
    )
    comment = models.TextField(blank=True, null=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Avis de légitimité"
        verbose_name_plural = "Avis de légitimité (Consensualité)"
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['phone_hash', 'created_at'], name='idx_safe_hash_created'),
            models.Index(fields=['reason', 'created_at'], name='idx_safe_reason_created'),
        ]

    def __str__(self):
        return f"Avis légitime {self.reason} -> {self.phone_hash[:10]}"


class AuditLogAction(models.TextChoices):
    APPROVE_BLOCK = 'APPROVE_BLOCK', 'Approuver et Bloquer'
    WHITELIST_UNBLOCK = 'WHITELIST_UNBLOCK', 'Débloquer et Blanchir'
    MANUAL_ADD = 'MANUAL_ADD', 'Ajout Manuel'
    DELETE_NUMBER = 'DELETE_NUMBER', 'Suppression de la Liste Noire'
    DELETE_REPORT = 'DELETE_REPORT', 'Suppression de Signalement'
    PURGE_DATABASE = 'PURGE_DATABASE', 'Purge de la Base'
    PASSWORD_CHANGE = 'PASSWORD_CHANGE', 'Changement de Mot de Passe'

class AuditLog(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='audit_logs')
    action = models.CharField(max_length=40, choices=AuditLogAction.choices)
    details = models.TextField(blank=True, default='')
    target_hash = models.CharField(max_length=64, blank=True, default='')
    source = models.CharField(max_length=20, default='MOBILE_ADMIN')  # 'WEB_ADMIN' ou 'MOBILE_ADMIN'
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Journal d'Audit"
        verbose_name_plural = "Journaux d'Audit"
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['action', 'created_at'], name='idx_audit_action_created'),
            models.Index(fields=['target_hash', 'created_at'], name='idx_audit_hash_created'),
        ]

    def __str__(self):
        return f"[{self.source}] {self.action} par {self.user or 'Système'} ({self.created_at.strftime('%Y-%m-%d %H:%M')})"


class CountryChoices(models.TextChoices):
    CANADA = 'CA', 'Canada'
    USA = 'US', 'États-Unis'

class UserProfile(models.Model):
    """
    Profil régional et juridictionnel étendu associé à un compte utilisateur.
    Permet d'appliquer les réglementations locales (Loi 25 QC, CRTC, TCPA FCC)
    et de localiser les utilisateurs dans les interfaces d'administration Web et Mobile.
    """
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    country = models.CharField(
        max_length=2,
        choices=CountryChoices.choices,
        default=CountryChoices.CANADA,
        db_index=True,
        help_text="Pays de résidence de l'utilisateur (CA: Canada, US: États-Unis)"
    )
    province_or_state = models.CharField(
        max_length=50,
        default='QC',
        db_index=True,
        help_text="Province/Territoire canadien (ex: QC, ON) ou État américain (ex: NY, CA)"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Profil Régional Utilisateur"
        verbose_name_plural = "Profils Régionaux Utilisateurs"
        indexes = [
            models.Index(fields=['country', 'province_or_state'], name='idx_profile_region'),
        ]

    def __str__(self):
        country_display = "Canada (CA)" if self.country == 'CA' else "États-Unis (US)"
        return f"{self.user.username} [{country_display} - {self.province_or_state}]"


from django.db.models.signals import post_save
from django.dispatch import receiver

@receiver(post_save, sender=User)
def create_or_update_user_profile(sender, instance, created, **kwargs):
    """
    Garantit que chaque utilisateur Django dispose systématiquement
    d'un profil régional UserProfile associé dès sa création.
    """
    if created:
        UserProfile.objects.get_or_create(user=instance)
    else:
        if hasattr(instance, 'profile'):
            instance.profile.save()

