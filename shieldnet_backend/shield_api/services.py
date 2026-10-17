import re
import hmac
import hashlib
from datetime import timedelta
from django.conf import settings
from django.utils import timezone
from django.db import transaction
from .models import BlacklistedNumber, SpamReport, SafeReport, SafeReasonChoices

def hash_phone_number(phone_number: str) -> str:
    cleaned = phone_number.strip()
    digits = re.sub(r'\D', '', cleaned)
    if not digits:
        return ""
    has_plus = cleaned.startswith('+')
    normalized = f"+{digits}" if has_plus else (f"+1{digits}" if len(digits) == 10 else f"+{digits}")
    salt = getattr(settings, 'HASH_SALT', '')
    if not salt:
        raise ValueError("Paramètre de sécurité HASH_SALT manquant dans la configuration.")
    return hmac.new(salt.encode('utf-8'), normalized.encode('utf-8'), hashlib.sha256).hexdigest()

def mask_phone_number(phone_number: str) -> str:
    cleaned = phone_number.strip()
    if len(cleaned) < 6:
        return '***'
    return f"{cleaned[:5]} *** **{cleaned[-2:]}"


def mask_email(email: str) -> str:
    """
    Masque une adresse courriel pour preserver la vie privee et respecter la Loi 25.
    Exemple: 'citoyen.montreal@gmail.com' -> 'c***l@gmail.com'
    Robuste contre toutes entrees malformees, partielles ou non-chaines.
    """
    if not email or not isinstance(email, str) or '@' not in email:
        return 'Anonyme'
    clean = email.strip()
    if '@' not in clean:
        return 'Anonyme'
    parts = clean.split('@', 1)
    local_part, domain = parts[0].strip(), parts[1].strip()
    if not local_part or not domain:
        return 'Anonyme'
    if len(local_part) <= 2:
        masked_local = f"{local_part[0]}***"
    else:
        masked_local = f"{local_part[0]}***{local_part[-1]}"
    return f"{masked_local}@{domain}"


def get_canonical_email(email: str) -> str:
    """
    Normalise l'adresse courriel pour contrer l'evasion du rate-limiting (CWE-307)
    par sous-adressage (+tag) et insertion de points specifiques a Gmail/Google Workspace.
    Exemple: 'a.l.i.c.e+spam@gmail.com' -> 'alice@gmail.com'
    """
    clean = str(email or '').strip().lower()
    if '@' not in clean:
        return clean
    parts = clean.split('@', 1)
    local_part, domain = parts[0].strip(), parts[1].strip()
    if domain in ('gmail.com', 'googlemail.com'):
        local_part = local_part.split('+')[0].replace('.', '')
    else:
        local_part = local_part.split('+')[0]
    return f"{local_part}@{domain}"

class DatabaseSanitizerService:
    """
    Nettoyage et maintenance de la base de données.
    """

    @classmethod
    def purge_obsolete_and_unverified_junk(cls) -> int:
        """
        Supprime les signalements isolés non confirmés de plus de 30 jours.
        """
        thirty_days_ago = timezone.now() - timedelta(days=30)
        
        # Supprimer les numéros à faible risque qui n'ont reçu qu'un seul signalement ancien
        junk_numbers = BlacklistedNumber.objects.filter(
            reports_count=1,
            risk_score__lt=30,
            updated_at__lt=thirty_days_ago
        )
        
        count = junk_numbers.count()
        junk_numbers.delete()
        return count

class AutomatedSpamVerifier:
    """
    Évaluation heuristique automatique des numéros.
    """
    
    NANP_PATTERN = re.compile(r'^\+1[2-9]\d{2}[2-9]\d{6}$')

    @classmethod
    def evaluate_number(cls, phone_hash: str, raw_number: str = None, attestation: str = None) -> dict:
        score = 0
        anomalies = []

        if raw_number:
            cleaned = raw_number.strip()
            digits = re.sub(r'\D', '', cleaned)
            has_plus = cleaned.startswith('+')

            normalized = f"+{digits}" if has_plus else (f"+1{digits}" if len(digits) == 10 else f"+{digits}")

            if not normalized.startswith('+1'):
                score += 55
                anomalies.append("Origine géographique internationale hors Amérique du Nord (+1)")

            if not cls.NANP_PATTERN.match(normalized):
                score += 65
                anomalies.append("Structure de numéro générée ou non conforme au format NANP")

            national_part = digits[1:] if len(digits) == 11 else digits
            if re.search(r'(\d)\1{6,}', national_part) or national_part in ['1234567890', '9876543210']:
                score += 70
                anomalies.append("Séquence de chiffres générée artificiellement")

        # Évaluation du standard télécom STIR/SHAKEN (FCC / CRTC)
        attestation_clean = (attestation or '').strip().upper()
        if attestation_clean == 'A':
            # Attestation A : Identité de l'appelant et droit d'usage certifiés par l'opérateur
            score = max(0, score - 30)
        elif attestation_clean == 'C':
            # Attestation C : Passerelle VoIP non sécurisée sans validation d'identité
            score += 25
            anomalies.append("Attestation STIR/SHAKEN niveau C : Passerelle non authentifiée")

        return {
            'calculated_score': min(100, max(0, score)),
            'is_verified_spam': score >= 40 or len(anomalies) > 0,
            'anomalies': anomalies,
            'attestation': attestation_clean if attestation_clean in ('A', 'B', 'C') else None,
        }

class FalsePositiveConsensusService:
    """
    Gestion du consensus communautaire et réhabilitation des faux positifs.
    Compare les signalements de spam aux avis légitimes déposés par les utilisateurs
    et réhabilite automatiquement un numéro si le quorum et le ratio pondéré sont atteints.
    """
    QUORUM_MINIMUM_DEFAULT = 2         # Au moins 2 avis favorables distincts pour initier le consensus
    CONSENSUS_THRESHOLD_DEFAULT = 0.55    # Au moins 55% de masse favorable pondérée

    REASON_WEIGHTS = {
        'medical': 2.0,      # Priorité absolue : urgences / santé
        'delivery': 1.6,     # Services de messagerie / transporteurs
        'service': 1.4,      # Entreprises et services certifiés
        'personal': 1.3,     # Contacts personnels
        'mistake': 1.2,      # Erreur reconnue de signalement
        'other': 1.0,
    }

    SPAM_CATEGORY_WEIGHTS = {
        'fraud': 1.5,
        'financial_scam': 1.6,
        'phishing': 1.5,
        'robocall': 1.1,
        'telemarketing': 0.9,
        'other': 0.8,
    }

    @classmethod
    def calculate_reporter_weight(cls, user, ip_address=None) -> float:
        """Pondère la fiabilité du votant : admin (5.0), utilisateur inscrit (1.5), anonyme (1.0)."""
        if not user:
            return 1.0
        if getattr(user, 'is_staff', False) or getattr(user, 'is_superuser', False):
            return 5.0
        return 1.5

    @classmethod
    def evaluate_consensus(cls, phone_hash: str) -> dict:
        """
        Calcule l'indice de consensualité C(h) = (M_safe * alpha) / (M_safe * alpha + M_spam).
        Retourne les métriques détaillées et le verdict de détection de faux positif.
        """
        number_obj = BlacklistedNumber.objects.filter(phone_hash=phone_hash).first()
        spam_reports = list(SpamReport.objects.filter(phone_hash=phone_hash).select_related('reporter'))
        safe_reports = list(SafeReport.objects.filter(phone_hash=phone_hash).select_related('reporter'))

        from .ai_engine import TemporalDecayService, NLPSemanticAnalyzer

        # Calcul de la masse pondérée des signalements négatifs avec amortissement temporel
        m_spam = 0.0
        spam_comments = []
        for s in spam_reports:
            w_cat = cls.SPAM_CATEGORY_WEIGHTS.get(s.category, 1.0)
            w_user = cls.calculate_reporter_weight(s.reporter)
            w_decay = TemporalDecayService.calculate_decay_weight(s.created_at)
            m_spam += (w_cat * w_user * w_decay)
            if s.comment:
                spam_comments.append(s.comment)

        # Calcul de la masse pondérée des avis favorables légitimes avec amortissement temporel
        m_safe = 0.0
        safe_comments = []
        for r in safe_reports:
            w_reason = cls.REASON_WEIGHTS.get(r.reason, 1.0)
            w_user = cls.calculate_reporter_weight(r.reporter, r.ip_address)
            w_decay = TemporalDecayService.calculate_decay_weight(r.created_at)
            m_safe += (w_reason * w_user * w_decay)
            if r.comment:
                safe_comments.append(r.comment)

        # Analyse sémantique NLP et détection d'usurpation contradictoire
        nlp_res = NLPSemanticAnalyzer.analyze(spam_comments=spam_comments, safe_comments=safe_comments)

        # Coefficient correcteur selon la conformité du format télécom
        raw_num = number_obj.masked_number if number_obj else None
        eval_algo = AutomatedSpamVerifier.evaluate_number(phone_hash, raw_num)
        alpha = 0.7 if eval_algo.get('is_verified_spam', False) else 1.25

        # Modulation bayésienne sémantique :
        # - En cas d'usurpation paradoxale détectée, la force de réhabilitation est fortement réduite (0.5)
        # - En cas de confirmation sémantique de légitimité (santé, rdv...), bonus modéré
        if nlp_res.get('is_impersonation', False):
            beta_nlp = 0.5
        elif nlp_res.get('legitimacy_score', 0) > 15:
            beta_nlp = min(1.35, 1.0 + (nlp_res['legitimacy_score'] / 300.0))
        else:
            beta_nlp = 1.0

        weighted_safe = m_safe * alpha * beta_nlp
        total_mass = weighted_safe + m_spam

        consensus_ratio = (weighted_safe / total_mass) if total_mass > 0 else 0.0
        unique_safe_count = len(safe_reports)

        has_admin_safe = any(
            r.reporter and (r.reporter.is_staff or r.reporter.is_superuser)
            for r in safe_reports
        )
        quorum_met = (unique_safe_count >= cls.QUORUM_MINIMUM_DEFAULT) or has_admin_safe
        ratio_met = consensus_ratio >= cls.CONSENSUS_THRESHOLD_DEFAULT
        mass_met = weighted_safe >= m_spam

        is_false_positive = quorum_met and ratio_met and mass_met

        return {
            'phone_hash': phone_hash,
            'spam_count': len(spam_reports),
            'safe_count': unique_safe_count,
            'm_spam': round(m_spam, 2),
            'm_safe': round(m_safe, 2),
            'alpha': alpha,
            'beta_nlp': round(beta_nlp, 2),
            'consensus_ratio': round(consensus_ratio, 3),
            'quorum_met': quorum_met,
            'is_false_positive': is_false_positive,
            'details': (
                f"Consensus légitime atteint ({round(consensus_ratio * 100, 1)}%) avec {unique_safe_count} avis."
                if is_false_positive else
                f"Consensus insuffisant ({round(consensus_ratio * 100, 1)}% favorable, {unique_safe_count}/{cls.QUORUM_MINIMUM_DEFAULT} avis requis)."
            )
        }

    @classmethod
    @transaction.atomic
    def apply_consensus_decision(cls, phone_hash: str) -> bool:
        """
        Applique automatiquement la décision de consensualité sur la base de données
        avec verrouillage transactionnel strict (ACID / Concurrency-safe).
        Si faux positif avéré :
          - is_whitelisted = True
          - is_blocked = False
          - risk_score = 0
          - whitelist_reason = 'auto_consensus'
        Retourne True si le numéro est réhabilité comme faux positif.
        """
        analysis = cls.evaluate_consensus(phone_hash)
        number_obj = BlacklistedNumber.objects.select_for_update().filter(phone_hash=phone_hash).first()
        if not number_obj:
            return False

        number_obj.safe_reports_count = analysis['safe_count']
        number_obj.consensus_score = analysis['consensus_ratio']

        # Si déjà blanchi (manuellement ou préexistant hors auto_consensus), conserver la décision
        if number_obj.is_whitelisted and number_obj.whitelist_reason != 'auto_consensus':
            number_obj.save()
            return False

        if analysis['is_false_positive']:
            number_obj.is_whitelisted = True
            number_obj.is_blocked = False
            number_obj.risk_score = 0
            number_obj.whitelist_reason = 'auto_consensus'
            number_obj.save()
            return True
        else:
            # Révocation dynamique si un numéro auto-consensuel subit une vague massive de nouveaux spams
            if number_obj.whitelist_reason == 'auto_consensus' and analysis['consensus_ratio'] < 0.40:
                number_obj.is_whitelisted = False
                number_obj.is_blocked = True
                number_obj.whitelist_reason = ''
                number_obj.risk_score = min(100, int(analysis['m_spam'] * 15))
                number_obj.save()
            else:
                number_obj.save()
            return False

    @classmethod
    @transaction.atomic
    def register_safe_feedback(
        cls,
        phone_hash: str,
        reason: str = 'service',
        comment: str = '',
        user=None,
        ip_address=None,
        masked_number: str = None
    ) -> tuple[SafeReport, bool]:
        """
        Enregistre un avis favorable / contestation avec protection anti-Sybil,
        puis exécute immédiatement l'analyse et la réhabilitation consensuelle automatique.
        """
        # Anti-Sybil : Un même utilisateur connecté ne vote qu'une fois par numéro
        if user and user.is_authenticated:
            existing = SafeReport.objects.filter(reporter=user, phone_hash=phone_hash).first()
            if existing:
                existing.reason = reason
                if comment:
                    existing.comment = comment
                existing.save()
                auto_whitelisted = cls.apply_consensus_decision(phone_hash)
                return existing, auto_whitelisted

        # Anti-Flood par IP pour les utilisateurs non connectés (1 vote par IP / 2h sur le même numéro)
        if ip_address:
            two_hours_ago = timezone.now() - timedelta(hours=2)
            existing_ip = SafeReport.objects.filter(
                phone_hash=phone_hash,
                ip_address=ip_address,
                created_at__gte=two_hours_ago
            ).first()
            if existing_ip:
                auto_whitelisted = cls.apply_consensus_decision(phone_hash)
                return existing_ip, auto_whitelisted

        report = SafeReport.objects.create(
            reporter=user if (user and user.is_authenticated) else None,
            phone_hash=phone_hash,
            reason=reason,
            comment=comment,
            ip_address=ip_address,
        )

        number_obj, _ = BlacklistedNumber.objects.get_or_create(
            phone_hash=phone_hash,
            defaults={
                'masked_number': masked_number,
                'category': 'other',
                'risk_score': 0,
                'reports_count': 0,
                'is_blocked': False,
                'is_whitelisted': False,
            }
        )
        if masked_number and not number_obj.masked_number:
            number_obj.masked_number = masked_number

        auto_whitelisted = cls.apply_consensus_decision(phone_hash)
        return report, auto_whitelisted

    @classmethod
    def run_consensus_audit(cls) -> dict:
        """
        Audit et réévaluation globale des faux positifs par consensualité
        sur l'intégralité de la base de données.
        """
        candidates = BlacklistedNumber.objects.filter(safe_reports_count__gte=1)
        auto_whitelisted_hashes = []

        for num in candidates:
            if cls.apply_consensus_decision(num.phone_hash):
                auto_whitelisted_hashes.append(num.phone_hash)

        return {
            'candidates_audited': candidates.count(),
            'auto_whitelisted_count': len(auto_whitelisted_hashes),
            'auto_whitelisted_hashes': auto_whitelisted_hashes,
        }

class ReputationService:
    """
    Algorithme de calcul de réputation et modération anti-pollution.
    """
    
    CATEGORY_WEIGHTS = {
        'fraud': 35,
        'financial_scam': 40,
        'phishing': 35,
        'robocall': 25,
        'telemarketing': 20,
        'other': 15,
    }

    @classmethod
    @transaction.atomic
    def process_new_report(cls, phone_hash: str, category: str, masked_number: str = None, user = None, comment: str = None) -> SpamReport:
        """
        Traite un nouveau signalement et exécute les vérifications anti-pollution
        avec garantie d'intégrité transactionnelle ACID.
        """
        # Déduplication : ignorer les signalements identiques rapprochés (< 1h) par le même utilisateur
        one_hour_ago = timezone.now() - timedelta(hours=1)
        if user and SpamReport.objects.filter(reporter=user, phone_hash=phone_hash, created_at__gte=one_hour_ago).exists():
            return SpamReport.objects.filter(reporter=user, phone_hash=phone_hash).first()

        # Plafond anti-saturation par hash (max 50 signalements archivés)
        if SpamReport.objects.filter(phone_hash=phone_hash).count() > 50:
            return SpamReport.objects.filter(phone_hash=phone_hash).first()

        report = SpamReport.objects.create(
            reporter=user,
            phone_hash=phone_hash,
            category=category,
            comment=comment,
        )

        number_obj = BlacklistedNumber.objects.select_for_update().filter(phone_hash=phone_hash).first()
        if not number_obj:
            number_obj = BlacklistedNumber.objects.create(
                phone_hash=phone_hash,
                category=category,
                masked_number=masked_number,
                reports_count=1,
                risk_score=cls.CATEGORY_WEIGHTS.get(category, 20),
                is_blocked=True,
            )
            created = True
        else:
            created = False

        if not created:
            number_obj.reports_count += 1

            # Si le numéro a été blanchi (manuellement ou préexistant hors auto_consensus),
            # on préserve la décision souveraine.
            if number_obj.is_whitelisted and number_obj.whitelist_reason != 'auto_consensus':
                pass
            # Si le numéro a été auto-blanchi par consensus, on ré-évalue immédiatement
            elif number_obj.is_whitelisted and number_obj.whitelist_reason == 'auto_consensus':
                FalsePositiveConsensusService.apply_consensus_decision(phone_hash)
            else:
                weight = cls.CATEGORY_WEIGHTS.get(category, 20)
                calculated_score = weight + (number_obj.reports_count * 15)
                number_obj.risk_score = min(100, calculated_score)
                number_obj.category = category
                
                if number_obj.risk_score >= 40:
                    number_obj.is_blocked = True

            if masked_number and not number_obj.masked_number:
                number_obj.masked_number = masked_number

            number_obj.save()

            # Mise à jour du score de consensualité en temps réel
            FalsePositiveConsensusService.apply_consensus_decision(phone_hash)

        return report


class BloomFilterService:
    """
    Générateur de filtre de Bloom probabiliste pour vérification instantanée en mémoire côté client.
    Taille standard : 65536 bits (8192 octets = 8 Ko) avec 4 fonctions de hachage.
    """
    DEFAULT_SIZE_BITS = 65536
    DEFAULT_HASH_COUNT = 4

    @classmethod
    def generate_filter_payload(cls, size_bits=DEFAULT_SIZE_BITS, hash_count=DEFAULT_HASH_COUNT) -> dict:
        import base64
        from .models import BlacklistedNumber
        
        active_hashes = list(
            BlacklistedNumber.objects.filter(is_blocked=True, is_whitelisted=False)
            .values_list('phone_hash', flat=True)
        )
        
        byte_size = (size_bits + 7) // 8
        bit_array = bytearray(byte_size)
        
        for phone_hash in active_hashes:
            try:
                h1 = int(phone_hash[:16], 16)
                h2 = int(phone_hash[16:32], 16) | 1
            except (ValueError, IndexError):
                continue
            
            for i in range(hash_count):
                bit_index = (h1 + i * h2) % size_bits
                byte_pos = bit_index // 8
                bit_pos = bit_index % 8
                bit_array[byte_pos] |= (1 << bit_pos)
                
        encoded_b64 = base64.b64encode(bit_array).decode('ascii')
        
        return {
            'format': 'bloom_filter_v1',
            'size_bits': size_bits,
            'size_bytes': byte_size,
            'hash_count': hash_count,
            'entries_count': len(active_hashes),
            'bit_array_base64': encoded_b64,
            'generated_at': timezone.now().isoformat(),
        }


class RegionalThreatIntelligenceService:
    """
    Détection et analyse des vagues d'attaques téléphoniques régionales (Spoofing ciblé par indicatif).
    """
    QUEBEC_AREA_CODES = {
        '514': 'Montréal Centre-Ville (QC)',
        '438': 'Grand Montréal & Rive-Sud (QC)',
        '263': 'Montréal Métropole (QC)',
        '450': 'Laval & Couronnes (QC)',
        '579': 'Laval, Laurentides & Lanaudière (QC)',
        '354': 'Montérégie & Couronne Sud (QC)',
        '418': 'Capitale-Nationale & Est (QC)',
        '581': 'Québec Métropole & Saguenay (QC)',
        '367': 'Québec / Est (QC)',
        '819': 'Outaouais / Gatineau / Laurentides (QC)',
        '873': 'Gatineau, Mauricie & Abitibi (QC)',
        '468': 'Mauricie & Centre-du-Québec (QC)',
    }

    AREA_CODE_PROVINCE = {
        '514': 'QC', '438': 'QC', '263': 'QC', '450': 'QC', '579': 'QC', '354': 'QC',
        '418': 'QC', '581': 'QC', '367': 'QC', '819': 'QC', '873': 'QC', '468': 'QC',
        '613': 'ON', '416': 'ON', '647': 'ON', '905': 'ON',
        '604': 'BC', '778': 'BC',
        '403': 'AB', '780': 'AB',
        '204': 'MB',
        '902': 'NS',
        '212': 'NY', '718': 'NY', '917': 'NY',
        '213': 'CA', '310': 'CA', '415': 'CA', '619': 'CA',
        '312': 'IL', '773': 'IL',
        '713': 'TX', '214': 'TX', '512': 'TX',
        '305': 'FL', '407': 'FL',
        '202': 'DC',
        '206': 'WA',
        '617': 'MA',
        '404': 'GA',
        '215': 'PA',
        '602': 'AZ',
    }

    REGION_NAMES = {
        # Canada (Québec)
        '514': 'Montréal Centre-Ville (QC)',
        '438': 'Grand Montréal & Rive-Sud (QC)',
        '263': 'Montréal Métropole (QC)',
        '450': 'Laval & Couronnes (QC)',
        '579': 'Laval, Laurentides & Lanaudière (QC)',
        '354': 'Montérégie & Couronne Sud (QC)',
        '418': 'Capitale-Nationale & Est (QC)',
        '581': 'Québec Métropole & Saguenay (QC)',
        '367': 'Québec / Est (QC)',
        '819': 'Outaouais / Gatineau / Laurentides (QC)',
        '873': 'Gatineau, Mauricie & Abitibi (QC)',
        '468': 'Mauricie & Centre-du-Québec (QC)',

        # Canada (Ontario, Ouest, Atlantique)
        '613': 'Ottawa / Est Ontarien (ON)',
        '416': 'Toronto Centre (ON)',
        '647': 'Grand Toronto (ON)',
        '905': 'GTA / Hamilton / Niagara (ON)',
        '604': 'Grand Vancouver (BC)',
        '778': 'Colombie-Britannique (BC)',
        '403': 'Calgary & Sud (AB)',
        '780': 'Edmonton & Nord (AB)',
        '204': 'Winnipeg / Manitoba (MB)',
        '902': 'Nouvelle-Écosse / Atlantique (NS/PE)',

        # États-Unis (Principaux pôles et indicatifs métropolitains)
        '212': 'New York City / Manhattan (NY)',
        '718': 'New York City / Brooklyn / Queens (NY)',
        '917': 'New York Métropole (NY)',
        '213': 'Los Angeles Centre (CA)',
        '310': 'Los Angeles Ouest / Beverly Hills (CA)',
        '415': 'San Francisco / Bay Area (CA)',
        '619': 'San Diego (CA)',
        '312': 'Chicago Centre (IL)',
        '773': 'Chicago Métropole (IL)',
        '713': 'Houston (TX)',
        '214': 'Dallas / Fort Worth (TX)',
        '512': 'Austin (TX)',
        '305': 'Miami / Florida Keys (FL)',
        '407': 'Orlando / Floride Centrale (FL)',
        '202': 'Washington D.C. (District fédéral)',
        '206': 'Seattle / Washington (WA)',
        '617': 'Boston / Massachusetts (MA)',
        '404': 'Atlanta / Géorgie (GA)',
        '215': 'Philadelphie (PA)',
        '602': 'Phoenix / Arizona (AZ)',
    }

    @classmethod
    def get_regional_threat_report(cls, province: str = None) -> dict:
        from .models import BlacklistedNumber
        
        numbers = BlacklistedNumber.objects.filter(is_blocked=True, is_whitelisted=False).exclude(masked_number__isnull=True)
        
        regional_stats = {}
        for num in numbers:
            masked = num.masked_number or ''
            clean_digits = re.sub(r'\D', '', masked)
            code = None
            if len(clean_digits) >= 4 and clean_digits.startswith('1'):
                candidate = clean_digits[1:4]
                if candidate in cls.REGION_NAMES:
                    code = candidate
            elif len(clean_digits) >= 3:
                candidate = clean_digits[:3]
                if candidate in cls.REGION_NAMES:
                    code = candidate

            if not code:
                pattern = r'\b(' + '|'.join(cls.REGION_NAMES.keys()) + r')\b'
                match = re.search(pattern, masked)
                code = match.group(1) if match else 'AUTRE'
                
            if code not in regional_stats:
                province_code = cls.AREA_CODE_PROVINCE.get(
                    code, 'QC' if '(QC)' in cls.REGION_NAMES.get(code, '') else ''
                )
                regional_stats[code] = {
                    'area_code': code,
                    'region_name': cls.REGION_NAMES.get(code, 'Région NANP (Canada / É-U)'),
                    'province': province_code,
                    'total_spams': 0,
                    'top_category': num.category,
                    'categories': {},
                    'max_risk_score': 0,
                }
                
            entry = regional_stats[code]
            entry['total_spams'] += num.reports_count
            entry['categories'][num.category] = entry['categories'].get(num.category, 0) + num.reports_count
            if num.risk_score > entry['max_risk_score']:
                entry['max_risk_score'] = num.risk_score
                
        result_list = []
        for code, data in regional_stats.items():
            top_cat = max(data['categories'], key=data['categories'].get) if data['categories'] else 'fraud'
            data['top_category'] = top_cat
            del data['categories']
            
            if data['total_spams'] >= 20 or data['max_risk_score'] >= 90:
                data['alert_level'] = 'CRITIQUE'
            elif data['total_spams'] >= 5 or data['max_risk_score'] >= 60:
                data['alert_level'] = 'ÉLEVÉ'
            else:
                data['alert_level'] = 'MODÉRÉ'
                
            result_list.append(data)
            
        if province:
            prov_clean = str(province).strip().upper()
            if prov_clean == 'QC':
                result_list = [
                    r for r in result_list
                    if r.get('area_code') in cls.QUEBEC_AREA_CODES
                    or r.get('province') == 'QC'
                    or '(QC)' in r.get('region_name', '')
                ]
            else:
                result_list = [
                    r for r in result_list
                    if r.get('province') == prov_clean
                    or f"({prov_clean})" in r.get('region_name', '').upper()
                ]

        result_list.sort(key=lambda x: x['total_spams'], reverse=True)
        
        return {
            'generated_at': timezone.now().isoformat(),
            'total_regions_tracked': len(result_list),
            'province_filter': province.strip().upper() if province else None,
            'regions': result_list,
        }


class RegionalComplianceService:
    """
    Service d'arbitrage et d'application des réglementations télécoms et de protection
    de la vie privée en fonction du pays (Canada / États-Unis) et de la province/état.
    Garantit l'application des normes :
      - Loi 25 du Québec (CA-QC)
      - LPRPDE / PIPEDA & LCAP / CASL (Reste du Canada)
      - TCPA & CCPA / CPRA (Californie US-CA)
      - TCPA & TRACED Act FCC / FTC (Reste des États-Unis)
    """

    CANADIAN_PROVINCES = {
        'QC': 'Québec',
        'ON': 'Ontario',
        'BC': 'Colombie-Britannique',
        'AB': 'Alberta',
        'MB': 'Manitoba',
        'SK': 'Saskatchewan',
        'NS': 'Nouvelle-Écosse',
        'NB': 'Nouveau-Brunswick',
        'NL': 'Terre-Neuve-et-Labrador',
        'PE': 'Île-du-Prince-Édouard',
        'NT': 'Territoires du Nord-Ouest',
        'YT': 'Yukon',
        'NU': 'Nunavut',
    }

    US_STATES = {
        'AL': 'Alabama', 'AK': 'Alaska', 'AZ': 'Arizona', 'AR': 'Arkansas',
        'CA': 'Californie (California)', 'CO': 'Colorado', 'CT': 'Connecticut',
        'DE': 'Delaware', 'FL': 'Floride (Florida)', 'GA': 'Géorgie (Georgia)',
        'HI': 'Hawaï (Hawaii)', 'ID': 'Idaho', 'IL': 'Illinois', 'IN': 'Indiana',
        'IA': 'Iowa', 'KS': 'Kansas', 'KY': 'Kentucky', 'LA': 'Louisiane (Louisiana)',
        'ME': 'Maine', 'MD': 'Maryland', 'MA': 'Massachusetts', 'MI': 'Michigan',
        'MN': 'Minnesota', 'MS': 'Mississippi', 'MO': 'Missouri', 'MT': 'Montana',
        'NE': 'Nebraska', 'NV': 'Nevada', 'NH': 'New Hampshire', 'NJ': 'New Jersey',
        'NM': 'Nouveau-Mexique', 'NY': 'New York', 'NC': 'Caroline du Nord',
        'ND': 'Dakota du Nord', 'OH': 'Ohio', 'OK': 'Oklahoma', 'OR': 'Oregon',
        'PA': 'Pennsylvanie', 'RI': 'Rhode Island', 'SC': 'Caroline du Sud',
        'SD': 'Dakota du Sud', 'TN': 'Tennessee', 'TX': 'Texas', 'UT': 'Utah',
        'VT': 'Vermont', 'VA': 'Virginie', 'WA': 'Washington', 'WV': 'Virginie-Occidentale',
        'WI': 'Wisconsin', 'WY': 'Wyoming', 'DC': 'District of Columbia',
    }

    @classmethod
    def get_available_regions(cls) -> dict:
        """Retourne l'arborescence complète des pays et provinces/états supportés."""
        return {
            'countries': [
                {
                    'code': 'CA',
                    'name': 'Canada',
                    'flag': '🇨🇦',
                    'subdivision_type': 'province',
                    'subdivision_label': 'Province ou Territoire',
                    'provinces': [
                        {'code': code, 'name': name}
                        for code, name in cls.CANADIAN_PROVINCES.items()
                    ],
                },
                {
                    'code': 'US',
                    'name': 'États-Unis',
                    'flag': '🇺🇸',
                    'subdivision_type': 'state',
                    'subdivision_label': 'État américain (State)',
                    'states': [
                        {'code': code, 'name': name}
                        for code, name in cls.US_STATES.items()
                    ],
                },
            ]
        }

    @classmethod
    def normalize_region(cls, country: str, province_or_state: str) -> tuple[str, str]:
        c = (country or 'CA').strip().upper()
        if c not in ('CA', 'US'):
            c = 'CA'

        p = (province_or_state or '').strip().upper()
        if c == 'CA':
            if p not in cls.CANADIAN_PROVINCES:
                # Chercher par nom si l'utilisateur envoie "Québec"
                for code, name in cls.CANADIAN_PROVINCES.items():
                    if p in name.upper() or name.upper() in p:
                        p = code
                        break
                else:
                    p = 'QC'
        else:
            if p not in cls.US_STATES:
                for code, name in cls.US_STATES.items():
                    if p in name.upper() or name.upper() in p:
                        p = code
                        break
                else:
                    p = 'NY'

        return c, p

    @classmethod
    def get_compliance_for_region(cls, country: str, province_or_state: str) -> dict:
        """
        Détermine et applique les normes juridiques et réglementaires appropriées
        selon la combinaison Pays / Province / État.
        """
        c, p = cls.normalize_region(country, province_or_state)

        if c == 'CA' and p == 'QC':
            return {
                'country': 'CA',
                'country_name': 'Canada',
                'country_flag': '🇨🇦',
                'province_or_state': 'QC',
                'province_name': cls.CANADIAN_PROVINCES.get('QC', 'Québec'),
                'norm_key': 'LOI_25_QC',
                'norm_name': 'Loi 25 du Québec',
                'legal_framework': "Loi sur la protection des renseignements personnels dans le secteur privé (Loi 25 du Québec)",
                'regulator': "Commission d'accès à l'information du Québec (CAI) & CRTC",
                'description': "Protection stricte sous la Loi 25 québécoise : chiffrement HMAC-SHA256, zéro transmission de carnet de contacts, consentement exprès et purge de rétention sous 30 jours.",
                'data_retention_days': 30,
                'strict_consent_required': True,
                'telecom_standard': 'CRTC Décision 2019-403 & STIR/SHAKEN',
                'principles': [
                    "Confidentialité par défaut dès la conception (Privacy by Design)",
                    "Zéro indexation ni extraction du carnet d'adresses personnel",
                    "Empreintes cryptographiques locales HMAC-SHA256 avec sel",
                    "Droit d'accès, d'effacement et de portabilité des données",
                    "Purge automatisée des journaux d'audit et signalements sous 30 jours",
                ],
                'emergency_numbers': [
                    {'number': '911', 'label': 'Urgences vitales (Police, Pompiers, Ambulance)', 'immune': True},
                    {'number': '811', 'label': 'Info-Santé & Info-Social Québec', 'immune': True},
                    {'number': '988', 'label': 'Ligne de crise de suicide canadienne', 'immune': True},
                    {'number': '211', 'label': 'Services communautaires et sociaux', 'immune': True},
                ],
            }

        elif c == 'CA':
            prov_name = cls.CANADIAN_PROVINCES.get(p, p)
            return {
                'country': 'CA',
                'country_name': 'Canada',
                'country_flag': '🇨🇦',
                'province_or_state': p,
                'province_name': prov_name,
                'norm_key': 'PIPEDA_CASL_CRTC',
                'norm_name': f'LPRPDE / PIPEDA & LCAP ({prov_name})',
                'legal_framework': "Loi sur la protection des renseignements personnels et les documents électroniques (LPRPDE / PIPEDA) & Loi canadienne anti-pourriel (LCAP)",
                'regulator': "Commissariat à la protection de la vie privée du Canada (CPVP) & CRTC",
                'description': f"Conformité fédérale canadienne pour {prov_name} : protection de la vie privée LPRPDE, filtrage télécom validé CRTC et signalement au Centre antifraude du Canada.",
                'data_retention_days': 60,
                'strict_consent_required': True,
                'telecom_standard': 'CRTC 2019-403 / STIR-SHAKEN Canada',
                'principles': [
                    "Protection et traitement transparent selon la norme fédérale LPRPDE",
                    "Filtrage télécom conforme aux directives du CRTC",
                    "Consentement préalable pour le filtrage et l'analyse de pourriels",
                    "Signalement d'abus coordonné avec le Centre antifraude du Canada",
                ],
                'emergency_numbers': [
                    {'number': '911', 'label': 'Services d\'urgence', 'immune': True},
                    {'number': '811', 'label': 'Ligne d\'information santé provinciale', 'immune': True},
                    {'number': '988', 'label': 'Ligne de crise de suicide', 'immune': True},
                    {'number': '211', 'label': 'Ressources communautaires et d\'aide sociale', 'immune': True},
                ],
            }

        elif c == 'US' and p == 'CA':
            return {
                'country': 'US',
                'country_name': 'États-Unis',
                'country_flag': '🇺🇸',
                'province_or_state': 'CA',
                'province_name': 'Californie (California)',
                'norm_key': 'TCPA_CCPA_CALIFORNIA',
                'norm_name': 'TCPA & CCPA / CPRA (Californie)',
                'legal_framework': "Telephone Consumer Protection Act (47 U.S.C. § 227) & California Consumer Privacy Act (CCPA / CPRA)",
                'regulator': "California Privacy Protection Agency (CPPA), FCC & FTC",
                'description': "Conformité de pointe en Californie : respect des droits CCPA (Do Not Sell/Share PII), filtrage vocal STIR/SHAKEN mandaté par la FCC et protection TCPA.",
                'data_retention_days': 45,
                'strict_consent_required': True,
                'telecom_standard': 'FCC Robocall Mitigation Database & STIR/SHAKEN',
                'principles': [
                    "Garantie 'Do Not Sell or Share My Personal Information' (CCPA/CPRA)",
                    "Filtrage préventif des robocalls selon le standard fédéral TCPA",
                    "Vérification des niveaux d'attestation opérateur FCC STIR/SHAKEN",
                    "Zéro profilage ni commercialisation des données d'appels",
                ],
                'emergency_numbers': [
                    {'number': '911', 'label': 'Emergency Services (Police / Fire / EMS)', 'immune': True},
                    {'number': '988', 'label': 'Suicide & Crisis Lifeline', 'immune': True},
                    {'number': '311', 'label': 'Non-Emergency City Services', 'immune': True},
                    {'number': '211', 'label': 'Essential Community & Health Services', 'immune': True},
                ],
            }

        else:
            state_name = cls.US_STATES.get(p, p)
            return {
                'country': 'US',
                'country_name': 'États-Unis',
                'country_flag': '🇺🇸',
                'province_or_state': p,
                'province_name': state_name,
                'norm_key': 'TCPA_TRACED_FCC',
                'norm_name': f'TCPA & TRACED Act ({p})',
                'legal_framework': "Telephone Consumer Protection Act (TCPA) & Pallone-Thune TRACED Act (Public Law 116-105)",
                'regulator': "Federal Communications Commission (FCC) & Federal Trade Commission (FTC)",
                'description': f"Réglementation télécom américaine pour l'État de {state_name} : interception anti-robocall TCPA, respect du National DNC Registry et authentification FCC.",
                'data_retention_days': 60,
                'strict_consent_required': False,
                'telecom_standard': 'FCC TRACED Act STIR/SHAKEN Mandate',
                'principles': [
                    "Interception des appels automatisés non sollicités (TCPA)",
                    "Vérification cryptographique STIR/SHAKEN (Attestations A/B/C)",
                    "Respect du registre fédéral National Do Not Call (DNC)",
                    "Traitement local sécurisé sans transfert de numéros de contacts",
                ],
                'emergency_numbers': [
                    {'number': '911', 'label': 'Emergency Services', 'immune': True},
                    {'number': '988', 'label': 'Suicide & Crisis Lifeline', 'immune': True},
                    {'number': '311', 'label': 'Non-Emergency Municipal Services', 'immune': True},
                    {'number': '211', 'label': 'Community Resources & Information', 'immune': True},
                ],
            }

