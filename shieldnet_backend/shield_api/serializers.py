
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
from .models import BlacklistedNumber, SpamReport, SafeReport, SafeReasonChoices, AuditLog

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
        return obj.reporter.email if obj.reporter else 'Anonyme'

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
        email = data.get('email', '').strip().lower()
        password = data.get('password')

        user = User.objects.filter(email__iexact=email).first()
        if not user:
            user = User.objects.filter(username__iexact=email).first()

        if not user or not user.check_password(password):
            raise serializers.ValidationError("Adresse email ou mot de passe incorrect.")

        if not user.is_active:
            raise serializers.ValidationError("Ce compte utilisateur est inactif.")

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
