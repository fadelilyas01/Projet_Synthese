
DISPOSABLE_EMAIL_DOMAINS = {
    'mailinator.com', 'guerrillamail.com', '10minutemail.com', 'tempmail.com',
    'temp-mail.org', 'throwawaymail.com', 'fakeinbox.com', 'yopmail.com',
    'getairmail.com', 'dispostable.com', 'sharklasers.com', 'trashmail.com',
    'nada.ltd', 'mohmal.com', 'burnermail.io', 'inboxkitten.com',
    'mytemp.email', 'crazymailing.com', 'zillamail.com', 'generator.email',
    'sharklasers.com', 'guerrillamailblock.com', 'pokemail.net'
}

def validate_secure_email(email_str):
    email_clean = email_str.strip().lower()
    if '@' not in email_clean:
        raise serializers.ValidationError("Adresse courriel invalide.")
    domain = email_clean.split('@')[-1]
    if domain in DISPOSABLE_EMAIL_DOMAINS:
        raise serializers.ValidationError("Les adresses courriel temporaires ou jetables sont strictement interdites sur ShieldNet pour des raisons de sécurité.")
    if domain == 'gmail.com':
        username = email_clean.split('@')[0]
        # Suppression des points pour le contrôle Gmail
        pure_user = username.replace('.', '')
        if len(pure_user) < 6:
            raise serializers.ValidationError("L'adresse Gmail doit comporter au moins 6 caractères avant le @.")
    return email_clean

import re
from rest_framework import serializers
from .services import mask_email
from .models import BlacklistedNumber, SpamReport, SafeReport, SafeReasonChoices, AuditLog, AuditLogAction

class BlacklistedNumberSerializer(serializers.ModelSerializer):
    """
    Sérialiseur pour la liste noire diffusée à l'application mobile.
    """
    class Meta:
        model = BlacklistedNumber
        fields = [
            'phone_hash',
            'masked_number',
            'category',
            'risk_score',
            'reports_count',
            'safe_reports_count',
            'consensus_score',
            'is_whitelisted',
            'whitelist_reason',
            'updated_at',
        ]

class SpamReportCreateSerializer(serializers.Serializer):
    """
    Sérialiseur pour la soumission d'un nouveau signalement anonymisé.
    """
    phone_hash = serializers.CharField(max_length=64, min_length=64)
    masked_number = serializers.CharField(max_length=30, required=False, allow_blank=True)
    category = serializers.ChoiceField(choices=BlacklistedNumber._meta.get_field('category').choices)
    comment = serializers.CharField(required=False, allow_blank=True, max_length=1000)

    def validate_phone_hash(self, value):
        # Vérification stricte du format SHA-256 (64 caractères hexadécimaux)
        if not re.match(r'^[a-fA-F0-9]{64}$', value):
            raise serializers.ValidationError("L'empreinte phone_hash doit être un hash SHA-256 hexadécimal valide de 64 caractères.")
        return value.lower()

class SafeReportCreateSerializer(serializers.Serializer):
    """
    Sérialiseur pour la soumission d'un avis favorable ou contestation de faux positif.
    """
    phone_hash = serializers.CharField(max_length=64, min_length=64)
    masked_number = serializers.CharField(max_length=30, required=False, allow_blank=True)
    reason = serializers.ChoiceField(choices=SafeReasonChoices.choices, default=SafeReasonChoices.LEGITIMATE_SERVICE)
    comment = serializers.CharField(required=False, allow_blank=True, max_length=1000)

    def validate_phone_hash(self, value):
        if not re.match(r'^[a-fA-F0-9]{64}$', value):
            raise serializers.ValidationError("L'empreinte phone_hash doit être un hash SHA-256 hexadécimal valide de 64 caractères.")
        return value.lower()

class SafeReportSerializer(serializers.ModelSerializer):
    reporter_email = serializers.SerializerMethodField()

    class Meta:
        model = SafeReport
        fields = ['id', 'phone_hash', 'reason', 'comment', 'reporter_email', 'created_at']

    def get_reporter_email(self, obj):
        if not obj.reporter or not obj.reporter.email:
            return 'Anonyme'
        return mask_email(obj.reporter.email)

class CheckNumberResponseSerializer(serializers.Serializer):
    is_spam = serializers.BooleanField()
    risk_score = serializers.IntegerField()
    category = serializers.CharField(allow_null=True)
    reports_count = serializers.IntegerField()
    safe_reports_count = serializers.IntegerField(default=0)
    consensus_score = serializers.FloatField(default=0.0)
    is_whitelisted = serializers.BooleanField(default=False)
    whitelist_reason = serializers.CharField(allow_null=True, required=False)

class BatchCheckRequestSerializer(serializers.Serializer):
    """
    Sérialiseur pour la vérification groupée d'empreintes SHA-256 (jusqu'à 100 numéros).
    Permet au mobile de scanner en une seule requête son journal d'appels.
    """
    hashes = serializers.ListField(
        child=serializers.CharField(max_length=64, min_length=64),
        max_length=100,
        allow_empty=False
    )

    def validate_hashes(self, value):
        cleaned = []
        for h in value:
            h_str = h.strip().lower()
            if not re.match(r'^[a-f0-9]{64}$', h_str):
                raise serializers.ValidationError(f"L'empreinte '{h}' n'est pas un hash SHA-256 hexadécimal valide.")
            cleaned.append(h_str)
        return list(set(cleaned))

from django.contrib.auth.models import User
from .models import UserProfile, CountryChoices

from .services import RegionalComplianceService

class UserSerializer(serializers.ModelSerializer):
    name = serializers.SerializerMethodField()
    role = serializers.SerializerMethodField()
    country = serializers.SerializerMethodField()
    province_or_state = serializers.SerializerMethodField()
    country_name = serializers.SerializerMethodField()
    province_name = serializers.SerializerMethodField()
    compliance_norm = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'id', 'email', 'name', 'is_staff', 'is_superuser', 'role',
            'country', 'province_or_state', 'country_name', 'province_name',
            'compliance_norm', 'date_joined'
        ]

    def get_name(self, obj):
        full_name = f"{obj.first_name} {obj.last_name}".strip()
        return full_name if full_name else (obj.email.split('@')[0] if obj.email else obj.username)

    def get_role(self, obj):
        if obj.is_superuser:
            return 'ADMIN'
        if obj.is_staff or obj.groups.filter(name='Gestionnaires').exists():
            return 'MANAGER'
        return 'CITIZEN'

    def get_country(self, obj):
        profile = getattr(obj, 'profile', None)
        return profile.country if profile else 'CA'

    def get_province_or_state(self, obj):
        profile = getattr(obj, 'profile', None)
        return profile.province_or_state if profile else 'QC'

    def get_country_name(self, obj):
        country = self.get_country(obj)
        return 'Canada' if country == 'CA' else ('États-Unis' if country == 'US' else country)

    def get_province_name(self, obj):
        country = self.get_country(obj)
        prov = self.get_province_or_state(obj)
        if country == 'CA':
            return RegionalComplianceService.CANADIAN_PROVINCES.get(prov, prov)
        return RegionalComplianceService.US_STATES.get(prov, prov)

    def get_compliance_norm(self, obj):
        country = self.get_country(obj)
        prov = self.get_province_or_state(obj)
        return RegionalComplianceService.get_compliance_for_region(country, prov)

class UserRegisterSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, min_length=6)
    name = serializers.CharField(required=False, allow_blank=True, default='')
    country = serializers.ChoiceField(choices=CountryChoices.choices, required=False, default=CountryChoices.CANADA)
    province_or_state = serializers.CharField(max_length=50, required=False, default='QC')

    def validate_email(self, value):
        email_clean = validate_secure_email(value)
        if User.objects.filter(email__iexact=email_clean).exists() or User.objects.filter(username__iexact=email_clean).exists():
            raise serializers.ValidationError("Cet email est déjà associé à un compte.")
        return email_clean

    def validate_password(self, value):
        from django.contrib.auth.password_validation import validate_password
        from django.core.exceptions import ValidationError as DjangoValidationError
        try:
            validate_password(value)
        except DjangoValidationError as e:
            raise serializers.ValidationError(list(e.messages))
        return value

    def create(self, validated_data):
        email = validated_data['email']
        password = validated_data['password']
        name = validated_data.get('name', '').strip()
        country = validated_data.get('country', 'CA').upper()
        province_or_state = validated_data.get('province_or_state', 'QC').upper()
        first_name = name.split()[0] if name else ''
        last_name = ' '.join(name.split()[1:]) if len(name.split()) > 1 else ''

        user = User.objects.create_user(
            username=email,
            email=email,
            password=password,
            first_name=first_name,
            last_name=last_name,
        )
        profile, _ = UserProfile.objects.get_or_create(user=user)
        profile.country = country
        profile.province_or_state = province_or_state
        profile.save()
        return user

class EmailLoginSerializer(serializers.Serializer):
    email = serializers.CharField()  # Accepte soit l'email soit le username (ex: admin)
    password = serializers.CharField(write_only=True)

    def validate(self, data):
        from django.core.cache import cache
        email = data.get('email', '').strip().lower()
        password = data.get('password')

        lockout_key = f'login_lockout_{email}'
        if cache.get(lockout_key):
            raise serializers.ValidationError("Compte temporairement verrouillé suite à de multiples tentatives erronées. Veuillez patienter 15 minutes.")

        user = User.objects.filter(email__iexact=email).first()
        if not user:
            user = User.objects.filter(username__iexact=email).first()

        # Atténuation des attaques par canal auxiliaire (CWE-208 / Timing Attack)
        if not user:
            User().check_password(password)
            raise serializers.ValidationError("Adresse email ou mot de passe incorrect.")

        if not user.check_password(password):
            attempts_key = f'login_attempts_{email}'
            attempts = cache.get(attempts_key, 0) + 1
            cache.set(attempts_key, attempts, timeout=900)
            if attempts >= 5:
                cache.set(lockout_key, True, timeout=900)
                cache.delete(attempts_key)
                AuditLog.objects.create(
                    user=user,
                    action=AuditLogAction.APPROVE_BLOCK,
                    details=f"Verrouillage de sécurité déclenché pour le compte {email} (5 tentatives erronées)",
                    source='SECURITY_DEFENSE'
                )
                raise serializers.ValidationError("Compte temporairement verrouillé suite à 5 tentatives erronées. Veuillez patienter 15 minutes.")
            raise serializers.ValidationError("Adresse email ou mot de passe incorrect.")

        if not user.is_active:
            raise serializers.ValidationError("Ce compte utilisateur est inactif.")

        cache.delete(f'login_attempts_{email}')
        cache.delete(lockout_key)

        data['user'] = user
        return data

class GoogleLoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    name = serializers.CharField(required=False, allow_blank=True, default='')
    id_token = serializers.CharField(required=False, allow_blank=True, default='')
    country = serializers.ChoiceField(choices=CountryChoices.choices, required=False, default=CountryChoices.CANADA)
    province_or_state = serializers.CharField(max_length=50, required=False, default='QC')

    def validate_email(self, value):
        return validate_secure_email(value)

class UpdateUserRegionSerializer(serializers.Serializer):
    country = serializers.ChoiceField(choices=CountryChoices.choices, required=False)
    province_or_state = serializers.CharField(max_length=50, required=False)


class PasswordChangeSerializer(serializers.Serializer):
    """
    Sérialiseur de changement de mot de passe pour utilisateur authentifié.
    Valide l'ancien mot de passe, l'entropie du nouveau mot de passe et l'égalité avec la confirmation.
    """
    old_password = serializers.CharField(write_only=True, required=True)
    new_password = serializers.CharField(write_only=True, required=True, min_length=8)
    confirm_password = serializers.CharField(write_only=True, required=True, min_length=8)

    def validate_old_password(self, value):
        request = self.context.get('request')
        user = getattr(request, 'user', None)
        if not user or not user.check_password(value):
            raise serializers.ValidationError("Le mot de passe actuel est incorrect.")
        return value

    def validate(self, data):
        old_password = data.get('old_password')
        new_password = data.get('new_password')
        confirm_password = data.get('confirm_password')

        if new_password != confirm_password:
            raise serializers.ValidationError({"confirm_password": "La confirmation ne correspond pas au nouveau mot de passe."})

        if old_password and new_password and old_password == new_password:
            raise serializers.ValidationError({"new_password": "Le nouveau mot de passe doit être différent du mot de passe actuel."})

        request = self.context.get('request')
        user = getattr(request, 'user', None)
        from django.contrib.auth.password_validation import validate_password
        from django.core.exceptions import ValidationError as DjangoValidationError
        try:
            validate_password(new_password, user)
        except DjangoValidationError as e:
            raise serializers.ValidationError({"new_password": list(e.messages)})

        return data




class AuditLogSerializer(serializers.ModelSerializer):
    username = serializers.SerializerMethodField()

    class Meta:
        model = AuditLog
        fields = [
            'id',
            'user',
            'username',
            'action',
            'details',
            'target_hash',
            'source',
            'created_at',
        ]

    def get_username(self, obj):
        return obj.user.username if obj.user else 'Système'
