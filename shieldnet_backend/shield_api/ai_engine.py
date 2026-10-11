"""
Module d'arbitrage et de détection des faux positifs pour ShieldNet.
Analyse multimodale haute précision :
1. Classifieur bayésien multinomial à N-grammes (Log-Odds probabilistes).
2. Détection d'usurpation paradoxale (Adversarial Impersonation).
3. Détecteur de rafales par processus de Poisson et score Z.
4. Validation structurelle télécom NANP (codes de centraux N11, spoofing de voisinage).
5. Entropie de Shannon des chiffres et analyse spectrale.
6. Amortissement temporel exponentiel (demi-vie de 90 jours).
7. Fusion décisionnelle calibrée par sigmoïde (Platt Scaling) avec profils adaptatifs.
"""

import re
import math
import time
import unicodedata
from datetime import timedelta
from django.utils import timezone
from .models import BlacklistedNumber, SpamReport, SafeReport
from .services import hash_phone_number, mask_phone_number


def normalize_text(text: str) -> str:
    """Normalise une chaîne de caractères (minuscules, sans accents ni ponctuation)."""
    if not text:
        return ""
    text = unicodedata.normalize('NFKD', text)
    text = "".join([c for c in text if not unicodedata.combining(c)])
    text = text.lower()
    text = re.sub(r'[^a-z0-9\s]', ' ', text)
    return re.sub(r'\s+', ' ', text).strip()


class ShannonEntropyAnalyzer:
    """
    Analyse de la distribution d'entropie des chiffres d'un numéro de téléphone.
    H(X) = - sum(p_i * log2(p_i))
    Permet de discriminer les numéros humains normaux (entropie 2.5 à 3.32 bits)
    des numéros synthétiques spoofés ou générés par composeur automatique (entropie < 2.2).
    """

    @classmethod
    def calculate_digit_entropy(cls, raw_number: str) -> float:
        digits = re.sub(r'\D', '', raw_number or '')
        if not digits:
            return 0.0
        # On extrait les 10 chiffres nationaux (sans l'indicatif international +1)
        if len(digits) == 11 and digits.startswith('1'):
            digits = digits[1:]
        if not digits:
            return 0.0
        n = len(digits)
        counts = {}
        for d in digits:
            counts[d] = counts.get(d, 0) + 1
        entropy = 0.0
        for count in counts.values():
            p = count / n
            entropy -= p * math.log2(p)
        return round(entropy, 3)

    @classmethod
    def evaluate_entropy_risk(cls, raw_number: str) -> dict:
        entropy = cls.calculate_digit_entropy(raw_number)
        is_synthetic = 0.0 <= entropy < 2.2
        return {
            'entropy': entropy,
            'is_synthetic': is_synthetic,
            'description': (
                f"Entropie de Shannon anormale ({entropy} bits) indiquant une séquence VoIP synthétique."
                if is_synthetic else f"Entropie spectrale conforme ({entropy} bits)."
            )
        }


class ArithmeticSequenceAnalyzer:
    """
    Détecteur de motifs arithmétiques et séquentiels non aléatoires.
    Comble un angle mort classique de l'entropie de Shannon :
    les suites arithmétiques (ex: 1234567, 9876543) ont une entropie
    apparente élevée malgré leur nature 100% synthétique générée par automate.
    """
    @classmethod
    def evaluate_sequences(cls, raw_number: str) -> dict:
        digits = re.sub(r'\D', '', raw_number or '')
        if len(digits) == 11 and digits.startswith('1'):
            digits = digits[1:]
        if len(digits) < 7:
            return {'has_pattern': False, 'pattern_type': None, 'description': ''}

        # 1. Suite arithmétique croissante ou décroissante (>= 5 chiffres consécutifs)
        for i in range(len(digits) - 4):
            slice_5 = [int(d) for d in digits[i:i+5]]
            diffs = [slice_5[j+1] - slice_5[j] for j in range(4)]
            if all(d == 1 for d in diffs):
                seq_str = ''.join(digits[i:i+5])
                # Ignorer '01234' isolé qui résulte fréquemment d'un central terminant par 0 et d'une ligne 1234 (ex: 800-1234)
                if seq_str == '01234':
                    if i + 5 < len(digits) and digits[i+5] == '5':
                        seq_str = '012345'
                    else:
                        continue
                return {
                    'has_pattern': True,
                    'pattern_type': 'ASCENDING_RUN',
                    'description': f"Séquence arithmétique croissante artificielle ({seq_str}), typique d'un composeur automatique."
                }
            if all(d == -1 for d in diffs):
                seq_str = ''.join(digits[i:i+5])
                return {
                    'has_pattern': True,
                    'pattern_type': 'DESCENDING_RUN',
                    'description': f"Séquence arithmétique décroissante artificielle ({seq_str}), typique d'un composeur automatique."
                }

        # 2. Motif périodique oscillant (ex: 121212, 787878 sur 6 chiffres)
        for i in range(len(digits) - 5):
            slice_6 = digits[i:i+6]
            if slice_6[0] == slice_6[2] == slice_6[4] and slice_6[1] == slice_6[3] == slice_6[5] and slice_6[0] != slice_6[1]:
                return {
                    'has_pattern': True,
                    'pattern_type': 'PERIODIC_OSCILLATION',
                    'description': f"Motif périodique oscillant détecté ({slice_6}), caractéristique d'une génération VoIP synthétique."
                }

        # 3. Bloc répétitif dense (ex: 8888, 0000 sur 4 chiffres consécutifs)
        for i in range(len(digits) - 3):
            slice_4 = digits[i:i+4]
            if slice_4[0] == slice_4[1] == slice_4[2] == slice_4[3]:
                return {
                    'has_pattern': True,
                    'pattern_type': 'REPETITIVE_BLOCK',
                    'description': f"Répétition artificielle consécutive ({slice_4}), indicative de numéroteur prédictif."
                }

        return {'has_pattern': False, 'pattern_type': None, 'description': ''}


class TemporalDecayService:
    """
    Amortissement temporel exponentiel des signalements télécoms.
    Modélise la demi-vie des signalements (90 jours) pour permettre
    la réhabilitation naturelle et progressive des numéros réassignés ou recyclés.
    w(t) = exp(- lambda * delta_t_jours) avec lambda = ln(2) / 90
    """
    HALF_LIFE_DAYS = 90.0
    LAMBDA = math.log(2) / HALF_LIFE_DAYS

    @classmethod
    def calculate_decay_weight(cls, report_timestamp) -> float:
        if not report_timestamp:
            return 1.0
        now = timezone.now()
        delta = (now - report_timestamp).total_seconds() / 86400.0
        if delta <= 0:
            return 1.0
        weight = math.exp(-cls.LAMBDA * delta)
        return max(0.05, round(weight, 4))


class AdversarialImpersonationDetector:
    """
    Détection d'usurpation institutionnelle par co-occurrence paradoxale.
    Repère les fraudes où un appelant invoque une autorité reconnue (Hôpital, Police, Revenu Québec, Banque)
    tout en formulant une exigence financière ou coercitive illégitime (cartes cadeaux, virement urgent, cryptomonnaie).
    """
    AUTHORITY_KEYWORDS = {
        # Canada
        'revenu quebec', 'arc', 'cra', 'impot', 'police', 'grc', 'rcmp', 'sq', 'opp',
        'tribunal', 'service canada', 'douane', 'cbsa', 'desjardins', 'hydro quebec',
        'clsc', 'hopital', 'gendarmerie royale',
        # États-Unis
        'irs', 'internal revenue', 'social security', 'ssa', 'fbi', 'federal bureau',
        'medicare', 'medicaid', 'dhs', 'homeland security', 'usps', 'us postal service',
        'sheriff', 'police department', 'ftc', 'border patrol', 'ice', 'dea'
    }

    EXTORTION_KEYWORDS = {
        'carte cadeau', 'gift card', 'itunes', 'apple card', 'target card', 'walmart card',
        'bitcoin', 'crypto', 'cryptomonnaie', 'virement interac', 'wire transfer', 'zelle',
        'venmo', 'cash app', 'arrestation', 'arrest', 'mandat d arret', 'mandat', 'warrant',
        'compte bloque', 'argent immediat', 'frais urgents', 'amende impayee'
    }

    NEGATION_WORDS = {
        'ne', 'pas', 'jamais', 'aucun', 'aucune', 'sans', 'nullement', 'rien', 'ni',
        'not', 'never', 'no', 'none', 'neither', 'nor', 'fake', 'faux'
    }

    @classmethod
    def _is_negated_extortion(cls, text: str, extortion_kw: str) -> bool:
        """Détecte si la mention d'extorsion est précédée d'une négation (ex: 'ne demande pas de carte cadeau')."""
        words = text.split()
        kw_words = extortion_kw.split()
        n = len(kw_words)
        for i in range(len(words) - n + 1):
            if words[i:i+n] == kw_words:
                window_start = max(0, i - 6)
                preceding = words[window_start:i]
                if any(w in cls.NEGATION_WORDS for w in preceding):
                    return True
        return False

    @classmethod
    def detect(cls, text: str) -> dict:
        normalized = normalize_text(text)
        found_authorities = [k for k in cls.AUTHORITY_KEYWORDS if k in normalized]
        raw_extortions = [k for k in cls.EXTORTION_KEYWORDS if k in normalized]

        active_extortions = [k for k in raw_extortions if not cls._is_negated_extortion(normalized, k)]
        negated_extortions = [k for k in raw_extortions if cls._is_negated_extortion(normalized, k)]

        is_impersonation = bool(found_authorities and active_extortions)
        return {
            'is_impersonation': is_impersonation,
            'authorities': found_authorities,
            'extortions': active_extortions,
            'negated_extortions': negated_extortions,
            'severity': 90 if is_impersonation else 0
        }


class BayesianSemanticClassifier:
    """
    Classifieur bayésien multinomial à N-grammes (unigrammes et bigrammes).
    Calcule le rapport de log-vraisemblance (Log-Odds) probabiliste :
      LogOdds = ln(P(Threat) / P(Legitimate)) + sum(LLR(token))
    Assure une discrimination mathématique de haute précision sans risque d'underflow.
    """

    # Prior logarithmique : probabilité a priori légèrement biaisée en faveur de la conformité
    PRIOR_LOG_ODDS = -0.30

    # Dictionnaire de Log-Likelihood Ratios (LLR) calibrés sur le corpus télécom nord-américain (Canada / É-U)
    # LLR > 0 : probabilité accrue de menace / spam
    # LLR < 0 : probabilité accrue de service légitime / santé / livraison
    TOKEN_LLR = {
        # Sémantique de fraude fiscale et usurpation d'autorité (fortement positif)
        'arc': 3.8, 'cra': 3.8, 'impot': 3.6, 'taxes': 3.2, 'arrestation': 4.5,
        'arrest': 4.2, 'mandat': 4.6, 'mandat arret': 5.2, 'police': 3.5,
        'grc': 3.8, 'rcmp': 3.8, 'sq': 3.4, 'cbsa': 3.7, 'douane': 3.6,
        'tribunal': 4.0, 'warrant': 4.5, 'gendarmerie': 3.8,
        # Autorités américaines (IRS, SSA, FBI, etc.)
        'irs': 4.5, 'internal revenue': 4.5, 'social security': 4.3, 'ssa': 3.8,
        'medicare': 4.0, 'medicaid': 3.6, 'fbi': 4.2, 'dhs': 3.8, 'sheriff': 3.8,
        'federal bureau': 4.0, 'police department': 3.6,

        # Extorsion financière et pressions (fortement positif)
        'carte cadeau': 5.0, 'gift card': 5.0, 'itunes': 4.8, 'apple card': 4.8,
        'bitcoin': 4.6, 'crypto': 4.4, 'cryptomonnaie': 4.4, 'virement': 2.8,
        'virement interac': 3.6, 'wire transfer': 3.9, 'western union': 4.5,
        'nas': 4.2, 'sin': 4.0, 'assurance sociale': 4.5, 'compte bloque': 4.2,
        'compte suspendu': 4.2, 'amende': 3.5, 'amende impayee': 4.8,

        # Phishing et arnaques de livraison (positif)
        'cliquez ici': 3.8, 'click here': 3.8, 'lien suspect': 4.2,
        'colis bloque': 3.6, 'frais douane': 3.8, 'remboursement': 2.9,
        'pret rapide': 3.5, 'fast cash': 3.7, 'loterie': 4.0, 'gagne': 3.2,

        # Robocall massif (positif)
        'robocall': 3.6, 'message automatique': 3.5, 'automated message': 3.5,
        'voix robotique': 3.8, 'robotic voice': 3.8, 'press 1': 3.6,
        'conduit aeration': 3.8, 'conduits': 3.2,

        # Services médicaux et urgences vitales (fortement négatif)
        'hopital': -4.5, 'hospital': -4.5, 'clinique': -4.2, 'clinic': -4.2,
        'medecin': -4.0, 'doctor': -4.0, 'docteur': -4.0, 'sante': -3.2,
        'health': -3.0, 'pharmacie': -3.8, 'pharmacy': -3.8, 'dentiste': -3.5,
        'dentist': -3.5, 'infirmiere': -3.6, 'nurse': -3.6, 'clsc': -4.5,
        'chsld': -4.5, 'pediatre': -4.0, 'rendez vous': -4.6, 'appointment': -4.2,
        'rappel rdv': -4.8, 'laboratoire': -3.8, 'biopsie': -4.6, 'vaccination': -3.6,
        'urgence 811': -4.8, 'jean coutu': -4.0, 'familiprix': -4.0,
        'pharmaprix': -4.0, 'uniprix': -4.0, 'secretariat medical': -5.0,
        'consultations externes': -4.6,

        # Transporteurs et logistique (négatif)
        'livraison': -3.5, 'delivery': -3.5, 'livreur': -3.8, 'courier': -3.4,
        'amazon': -3.6, 'postes canada': -4.2, 'canada post': -4.2, 'fedex': -3.8,
        'ups': -3.8, 'dhl': -3.8, 'purolator': -4.0, 'doordash': -3.6,
        'uber eats': -3.6, 'ubereats': -3.6, 'colis': -2.5, 'suivi colis': -3.8,

        # Services publics et éducation (négatif)
        'hydro quebec': -4.2, 'hydroquebec': -4.2, 'desjardins': -2.8,
        'ecole': -3.5, 'school': -3.5, 'universite': -4.0, 'university': -4.0,
        'uqo': -4.5, 'cegep': -4.0, 'garderie': -3.8, 'daycare': -3.8,
        'ville gatineau': -4.2, 'ville ottawa': -4.2, 'coupure service': -3.0,

        # Confirmations citoyennes explicites (négatif)
        'bon numero': -3.8, 'vrai numero': -3.8, 'personne reelle': -3.6,
        'pas spam': -4.2, 'aucun probleme': -3.5, 'legitime': -3.8, 'legit': -3.6,
    }

    @classmethod
    def extract_ngrams(cls, normalized_text: str) -> list[str]:
        words = normalized_text.split()
        if not words:
            return []
        unigrams = list(words)
        bigrams = [f"{words[i]} {words[i+1]}" for i in range(len(words) - 1)]
        return unigrams + bigrams

    @classmethod
    def classify(cls, text: str) -> dict:
        norm = normalize_text(text)
        tokens = cls.extract_ngrams(norm)
        log_odds = cls.PRIOR_LOG_ODDS
        matched_tokens = []

        for token in tokens:
            if token in cls.TOKEN_LLR:
                weight = cls.TOKEN_LLR[token]
                log_odds += weight
                matched_tokens.append((token, weight))

        # Borner log_odds pour stabilité numérique entre -15.0 et +15.0
        bounded_log_odds = max(-15.0, min(15.0, log_odds))
        probability_threat = 1.0 / (1.0 + math.exp(-bounded_log_odds))
        probability_legitimate = 1.0 - probability_threat

        return {
            'log_odds': round(bounded_log_odds, 3),
            'probability_threat': round(probability_threat, 4),
            'probability_legitimate': round(probability_legitimate, 4),
            'matched_tokens': matched_tokens,
        }


class PoissonBurstAnalyzer:
    """
    Analyseur statistique de rafales par modélisation de Poisson multi-échelle.
    Détecte à la fois les pics d'attaques synchronisées ultra-rapides (Flash Robocalls en 15 min),
    les rafales standard (fenêtre 2h), et les campagnes diffuses prolongées (24h).
    Calcule le Z-score d'anomalie temporelle :
      Z = (k - mu) / sqrt(mu)
    """
    BASELINE_RATE_PER_HOUR = 0.08  # Taux normal attendu pour un numéro déjà signalé

    @classmethod
    def evaluate_burst(cls, timestamps: list, window_hours: float = 2.0) -> dict:
        if not timestamps:
            return {
                'is_burst': False,
                'z_score': 0.0,
                'recent_count': 0,
                'significance': 'NORMALE',
                'multi_scale': {'micro_15m_z': 0.0, 'standard_z': 0.0, 'macro_24h_z': 0.0}
            }

        now = timezone.now()

        # Fenêtre principale demandée (par défaut 2h)
        threshold = now - timedelta(hours=window_hours)
        recent_count = sum(1 for t in timestamps if t and t >= threshold)

        expected_count = max(0.15, cls.BASELINE_RATE_PER_HOUR * window_hours)
        variance = expected_count
        z_score = (recent_count - expected_count) / math.sqrt(variance)

        # Échelle micro-rafale (15 minutes) pour détecter les flash attacks
        micro_threshold = now - timedelta(minutes=15)
        micro_count = sum(1 for t in timestamps if t and t >= micro_threshold)
        micro_expected = max(0.04, cls.BASELINE_RATE_PER_HOUR * 0.25)
        micro_z = (micro_count - micro_expected) / math.sqrt(micro_expected)

        # Échelle macro-campagne (24 heures) pour détecter les campagnes étalées
        macro_threshold = now - timedelta(hours=24)
        macro_count = sum(1 for t in timestamps if t and t >= macro_threshold)
        macro_expected = max(1.0, cls.BASELINE_RATE_PER_HOUR * 24.0)
        macro_z = (macro_count - macro_expected) / math.sqrt(macro_expected)

        # Détection de rafale : par la fenêtre standard OU par un flash micro-burst critique
        is_burst = (recent_count >= 2 and z_score >= 2.5) or (micro_count >= 3 and micro_z >= 3.5)
        effective_z = max(z_score, micro_z if micro_count >= 3 else 0.0)

        significance = 'CRITIQUE' if effective_z >= 4.0 else ('ÉLEVÉE' if effective_z >= 2.5 else 'NORMALE')

        if is_burst:
            if micro_count >= 3 and micro_z >= 3.5:
                desc = f"Attaque flash en rafale immédiate : {micro_count} appels en 15 min (Score Z = {round(micro_z, 1)})."
            else:
                desc = f"Rafale suspecte détectée : {recent_count} signalements en {int(window_hours)}h (Score Z = {round(z_score, 1)})."
        else:
            desc = "Activité temporelle conforme au rythme de référence."

        return {
            'is_burst': is_burst,
            'recent_count': recent_count,
            'z_score': round(max(0.0, z_score), 2),
            'significance': significance,
            'description': desc,
            'multi_scale': {
                'micro_15m_count': micro_count,
                'micro_15m_z': round(max(0.0, micro_z), 2),
                'standard_count': recent_count,
                'standard_z': round(max(0.0, z_score), 2),
                'macro_24h_count': macro_count,
                'macro_24h_z': round(max(0.0, macro_z), 2),
            }
        }


class NANPTelephonyValidator:
    """
    Validateur télécom approfondi pour le Plan de Numérotation Nord-Américain (NANP)
    et qualification des risques internationaux (fraudes Wangiri / callback traps).
    Format canonique : +1-NPA-NXX-XXXX
    NPA (Indicatif régional) : [2-9][0-9]{2}
    NXX (Code du central local) : [2-9][0-9]{2}
    Règles de conformité technique des télécommunications :
    1. Codes N11 (211, 311, 411, 511, 611, 711, 811, 911) réservés :
       Le bloc central NXX ne peut JAMAIS correspondre à un code N11.
       Exemple : +1-819-911-XXXX est un numéro techniquement impossible (100% usurpé).
    2. Plage fictive réservée au cinéma / tests : 555-0100 à 555-0199.
    3. Codes d'assistance annuaire : 555-1212.
    4. Destinations Wangiri à haut risque de rappel surtaxé (îles isolées, réseaux par satellite).
    """

    NANP_REGEX = re.compile(r'^\+1([2-9]\d{2})([2-9]\d{2})(\d{4})$')
    N11_CODES = {'211', '311', '411', '511', '611', '711', '811', '911'}
    TOLL_FREE_NPAS = {'800', '888', '877', '866', '855', '844', '833'}

    WANGIRI_HIGH_RISK_PREFIXES = {
        '247',  # Île de l'Ascension
        '290',  # Sainte-Hélène
        '881',  # Réseaux satellites Globalstar / Iridium
        '882', '883',  # Réseaux internationaux de télécommunications
        '870',  # Inmarsat maritime
        '676',  # Tonga
        '685',  # Samoa
        '674',  # Nauru
        '688',  # Tuvalu
        '682',  # Îles Cook
        '232',  # Sierra Leone
        '252',  # Somalie
        '220',  # Gambie
        '235',  # Tchad
        '245',  # Guinée-Bissau
        '269',  # Comores
        '387',  # Bosnie (plages surtaxées)
        '371',  # Lettonie (plages surtaxées)
    }

    @classmethod
    def validate_number(cls, raw_number: str) -> dict:
        if not raw_number:
            return {'is_valid_nanp': False, 'is_impossible_routing': False, 'details': 'Numéro vide'}

        cleaned = str(raw_number).strip()
        has_plus = cleaned.startswith('+')
        digits = re.sub(r'\D', '', cleaned)

        # Vérification Wangiri (sur les chiffres bruts ou format E.164)
        is_wangiri = any(digits.startswith(pfx) for pfx in cls.WANGIRI_HIGH_RISK_PREFIXES)

        # Seul un numéro nord-américain à 10 chiffres sans '+' explicite reçoit le préfixe '1'
        if len(digits) == 10 and not has_plus:
            digits = f"1{digits}"
        e164 = f"+{digits}"

        match = cls.NANP_REGEX.match(e164)
        if not match:
            # Numéro hors plan NANP
            if is_wangiri:
                return {
                    'is_valid_nanp': False,
                    'is_impossible_routing': False,
                    'is_wangiri_risk': True,
                    'is_valid_international': True,
                    'npa': None,
                    'nxx': None,
                    'is_fictitious_555': False,
                    'is_n11_central': False,
                    'is_toll_free': False,
                    'details': "Alerte Fraude Télécom : Destination internationale à risque Wangiri (rappel surtaxé exorbitant)."
                }
            # Numéro international valide générique (ex: +33, +44, +49)
            if len(digits) >= 8 and not digits.startswith('1'):
                return {
                    'is_valid_nanp': False,
                    'is_impossible_routing': False,
                    'is_wangiri_risk': False,
                    'is_valid_international': True,
                    'npa': None,
                    'nxx': None,
                    'is_fictitious_555': False,
                    'is_n11_central': False,
                    'is_toll_free': False,
                    'details': "Numéro international valide hors zone nord-américaine (+1)."
                }
            return {
                'is_valid_nanp': False,
                'is_impossible_routing': True,
                'is_wangiri_risk': False,
                'is_valid_international': False,
                'npa': None,
                'nxx': None,
                'is_fictitious_555': False,
                'is_n11_central': False,
                'is_toll_free': False,
                'details': "Format non conforme aux spécifications du plan NANP (+1)."
            }

        npa, nxx, line = match.group(1), match.group(2), match.group(3)
        is_n11 = nxx in cls.N11_CODES
        is_fictitious = (nxx == '555' and line.startswith('01'))
        is_toll_free = npa in cls.TOLL_FREE_NPAS

        impossible_routing = is_n11 or (nxx == '555' and line.startswith('01'))

        if is_n11:
            details = f"Routage impossible : Code central NXX invalide ({nxx}). Les indicatifs N11 sont réservés aux services publics (usurpation avérée)."
        elif is_fictitious:
            details = "Numéro appartenant à la plage fictive 555-01xx réservée aux fictions et tests télécom."
        elif is_toll_free:
            details = f"Ligne sans frais nord-américaine (indicatif {npa})."
        else:
            details = f"Structure NANP valide (Indicatif régional : {npa}, Central : {nxx})."

        return {
            'is_valid_nanp': not impossible_routing,
            'is_impossible_routing': impossible_routing,
            'is_wangiri_risk': False,
            'is_valid_international': False,
            'parsed': {'npa': npa, 'nxx': nxx, 'line': line},
            'npa': npa,
            'nxx': nxx,
            'line': line,
            'is_fictitious_555': is_fictitious,
            'is_n11_central': is_n11,
            'is_toll_free': is_toll_free,
            'details': details,
        }


class NLPSemanticAnalyzer:
    """
    Analyse sémantique hybride (Bayésienne & Lexicale avancée) des commentaires (FR / EN).
    Combine le modèle bayésien Naïve Bayes multinomial avec la détection d'entités métiers.
    """

    LEGITIMATE_LEXICON = {
        'SANTE_MEDICAL': {
            'weight': 3.5,
            'label': 'Service Médical ou Urgence Santé',
            'keywords': [
                'hopital', 'hospital', 'clinique', 'clinic', 'medecin', 'doctor', 'docteur',
                'sante', 'health', 'pharmacie', 'pharmacy', 'dentiste', 'dentist', 'infirmiere',
                'nurse', 'clsc', 'chsld', 'pediatre', 'rendez vous', 'appointment', 'rappel rdv',
                'laboratoire', 'analyse sanguine', 'vaccination', 'urgence 811', 'jean coutu',
                'familiprix', 'pharmaprix', 'uniprix', 'consultations externes', 'biopsie',
                'secretariat medical'
            ]
        },
        'LIVRAISON_MESSAGERIE': {
            'weight': 2.8,
            'label': 'Transporteur & Livraison Légitime',
            'keywords': [
                'livraison', 'delivery', 'livreur', 'courier', 'doordash', 'uber eats', 'ubereats',
                'skip', 'skipthedishes', 'fedex', 'ups', 'dhl', 'purolator', 'postes canada',
                'canada post', 'usps', 'united states postal', 'amazon', 'colis a la porte', 'chauffeur', 'suivi colis'
            ]
        },
        'BANQUE_SERVICES_PUBLICS': {
            'weight': 3.0,
            'label': 'Institution Bancaire ou Service Public Reconnu',
            'keywords': [
                'hydro quebec', 'hydroquebec', 'hydro', 'desjardins', 'caisse populaire', 'rbc',
                'td', 'bmo', 'scotia', 'cibc', 'banque nationale', 'chase', 'bank of america',
                'wells fargo', 'citibank', 'capital one', 'assurance', 'insurance',
                'ecole', 'school', 'universite', 'university', 'uqo', 'cegep', 'garderie',
                'daycare', 'ville de gatineau', 'ville d ottawa', 'municipalite', 'employeur',
                'coupure de service'
            ]
        },
        'ATTESTATION_CITOYENNE': {
            'weight': 2.0,
            'label': 'Attestation Citoyenne Positive',
            'keywords': [
                'bon numero', 'vrai numero', 'personne reelle', 'aucun probleme', 'pas un spam',
                'legit', 'legitime', 'ami', 'famille', 'collegue', 'travail', 'client'
            ]
        }
    }

    THREAT_LEXICON = {
        'USURPATION_GOUVERNEMENTALE': {
            'weight': 4.0,
            'label': 'Agence Publique / Fiscale Usurpée',
            'keywords': [
                'agence du revenu', 'revenu canada', 'arc', 'cra', 'impot', 'taxes', 'police',
                'grc', 'rcmp', 'sq', 'opp', 'arrestation', 'arrest', 'mandat d arret', 'warrant',
                'tribunal', 'court', 'service canada', 'douane', 'frontiere', 'cbsa', 'immigration',
                'gendarmerie royale', 'irs', 'internal revenue', 'social security', 'ssa',
                'fbi', 'medicare', 'medicaid', 'dhs', 'homeland security', 'sheriff', 'usps'
            ]
        },
        'EXTORSION_FINANCIERE': {
            'weight': 3.8,
            'label': 'Extorsion Financière & Vol d\'Identité',
            'keywords': [
                'carte cadeau', 'gift card', 'itunes', 'apple card', 'target card', 'walmart card',
                'bitcoin', 'crypto', 'cryptomonnaie', 'virement interac', 'wire transfer', 'zelle',
                'venmo', 'cash app', 'western union', 'dette', 'huissier', 'compte suspendu',
                'compte bloque', 'nas', 'sin', 'assurance sociale', 'social insurance',
                'frais non payes', 'amende impayee'
            ]
        },
        'HAME CONNAGE_PHISHING': {
            'weight': 3.2,
            'label': 'Hameçonnage / Phishing Télécom & SMS',
            'keywords': [
                'colis bloque', 'frais de douane', 'cliquez ici', 'click here', 'lien suspect',
                'remboursement interac', 'e transfer', 'etransfer', 'gain loterie', 'gagne un prix',
                'pret rapide', 'fast cash', 'taux d interet', 'reduction de dette'
            ]
        },
        'ROBOCALL_AUTOMATISE': {
            'weight': 2.6,
            'label': 'Appel Automatisé Massif (Robocall)',
            'keywords': [
                'message automatique', 'automated message', 'voix robotique', 'robotic voice',
                'robocall', 'chinois', 'chinese embassy', 'ambassade de chine', 'demarchage agressif',
                'conduit d aeration', 'nettoyage de conduits', 'press 1'
            ]
        }
    }

    @classmethod
    def analyze(cls, spam_comments: list[str], safe_comments: list[str]) -> dict:
        all_safe_text = " ".join([normalize_text(c) for c in safe_comments if c])
        all_spam_text = " ".join([normalize_text(c) for c in spam_comments if c])
        combined_text = f"{all_safe_text} {all_spam_text}".strip()

        # 1. Évaluation bayésienne probabiliste
        bayes_eval = BayesianSemanticClassifier.classify(combined_text)

        # 2. Détection d'usurpation paradoxale
        impersonation = AdversarialImpersonationDetector.detect(combined_text)
        is_impersonation = impersonation['is_impersonation']

        legitimacy_score = 0.0
        threat_score = 0.0
        detected_entities = []
        xai_factors = []

        # 3. Détection des motifs légitimes
        for domain_key, domain_data in cls.LEGITIMATE_LEXICON.items():
            matches = [kw for kw in domain_data['keywords'] if kw in combined_text]
            if matches:
                tf_factor = 1.0 + math.log(len(matches))
                weight = domain_data['weight'] * tf_factor

                in_safe = [kw for kw in domain_data['keywords'] if kw in all_safe_text]
                if in_safe:
                    weight *= 1.8

                if is_impersonation and not in_safe:
                    weight = 0.0

                if weight > 0:
                    legitimacy_score += weight
                    entity_label = f"{domain_data['label']} ({', '.join(matches[:2])})"
                    if entity_label not in detected_entities:
                        detected_entities.append(entity_label)
                    xai_factors.append({
                        'type': 'LEGITIMACY',
                        'impact': 'POSITIVE',
                        'weight': min(45, int(weight * 5)),
                        'description': f"Sémantique de service légitime identifiée : {domain_data['label']}"
                    })

        # 4. Détection des motifs de menace
        for domain_key, domain_data in cls.THREAT_LEXICON.items():
            matches = [kw for kw in domain_data['keywords'] if kw in all_spam_text or kw in combined_text]
            if matches:
                tf_factor = 1.0 + math.log(len(matches))
                weight = domain_data['weight'] * tf_factor
                threat_score += weight
                entity_label = f"{domain_data['label']} ({', '.join(matches[:2])})"
                if entity_label not in detected_entities:
                    detected_entities.append(entity_label)
                xai_factors.append({
                    'type': 'THREAT',
                    'impact': 'NEGATIVE',
                    'weight': min(50, int(weight * 6)),
                    'description': f"Sémantique de fraude/usurpation détectée : {domain_data['label']}"
                })

        # 5. Pénalité d'usurpation paradoxale
        if is_impersonation:
            threat_score += 45.0
            xai_factors.append({
                'type': 'ADVERSARIAL_IMPERSONATION',
                'impact': 'NEGATIVE',
                'weight': 50,
                'description': "Scénario d'usurpation : invocation d'un organisme officiel associée à une extorsion financière."
            })

        # Intégration du composant Bayésien aux facteurs d'explicabilité
        if bayes_eval['matched_tokens']:
            if bayes_eval['probability_threat'] >= 0.70:
                xai_factors.append({
                    'type': 'BAYESIAN_INFERENCE',
                    'impact': 'NEGATIVE',
                    'weight': int(bayes_eval['probability_threat'] * 40),
                    'description': f"Modèle Bayésien : probabilité d'escroquerie évaluée à {int(bayes_eval['probability_threat'] * 100)}% (Log-Odds: {bayes_eval['log_odds']})."
                })
            elif bayes_eval['probability_legitimate'] >= 0.70:
                xai_factors.append({
                    'type': 'BAYESIAN_INFERENCE',
                    'impact': 'POSITIVE',
                    'weight': int(bayes_eval['probability_legitimate'] * 40),
                    'description': f"Modèle Bayésien : probabilité de légitimité évaluée à {int(bayes_eval['probability_legitimate'] * 100)}% (Log-Odds: {bayes_eval['log_odds']})."
                })

        norm_legitimacy = min(100.0, round(legitimacy_score * 4.5, 1))
        norm_threat = min(100.0, round(threat_score * 5.0, 1))

        return {
            'legitimacy_score': norm_legitimacy,
            'threat_score': norm_threat,
            'is_impersonation': is_impersonation,
            'detected_entities': detected_entities[:4],
            'xai_factors': xai_factors,
            'bayes': bayes_eval
        }

    @classmethod
    def analyze_comments(cls, comments: list[str]) -> tuple[float, list[str]]:
        res = cls.analyze(spam_comments=comments, safe_comments=[])
        net_score = res['legitimacy_score'] - res['threat_score']
        return net_score, res['detected_entities']


class CalibratedDecisionFusion:
    """
    Fusion décisionnelle par régression logistique sigmoïde calibrée (Platt Scaling).
    Combine harmonieusement les dimensions hétérogènes (NLP Bayesien, Entropie, Vélocité,
    STIR/SHAKEN, Consensus communautaire) en une probabilité continue de risque.
    """

    PROFILES = {
        'balanced': {'bias': 0.0, 'threshold_block': 70, 'threshold_fp': 65},
        'senior_shield': {'bias': 0.85, 'threshold_block': 60, 'threshold_fp': 75},
        'high_precision': {'bias': -0.75, 'threshold_block': 78, 'threshold_fp': 55},
    }

    @classmethod
    def fuse_signals(
        cls,
        threat_score: float,
        legit_score: float,
        decayed_spam: float,
        decayed_safe: float,
        burst_z_score: float,
        entropy_val: float,
        is_synthetic_entropy: bool,
        is_impossible_routing: bool,
        is_impersonation: bool,
        stir_attestation: str,
        profile_name: str = 'balanced',
        is_wangiri_risk: bool = False,
        has_arithmetic_pattern: bool = False,
    ) -> tuple[int, float]:
        profile = cls.PROFILES.get(profile_name, cls.PROFILES['balanced'])
        bias = profile['bias']

        # Normalisation des composantes
        x_threat = threat_score / 100.0
        x_legit = legit_score / 100.0
        x_burst = min(3.0, max(0.0, burst_z_score)) / 3.0
        x_volume_spam = min(10.0, decayed_spam) / 10.0
        x_volume_safe = min(10.0, decayed_safe) / 10.0

        total_activity = decayed_spam + decayed_safe
        safe_ratio = (decayed_safe / total_activity) if total_activity > 0 else 0.0

        # Base logit calibré sur la distribution télécom (prior sain -2.6)
        base_logit = -2.6 + bias

        # Pondérations calibrées
        z = (
            base_logit +
            (x_threat * 4.2) +
            (x_volume_spam * 2.8) +
            (x_burst * 1.8) -
            (x_legit * 3.8) -
            (safe_ratio * 3.2) -
            (x_volume_safe * 2.0)
        )

        if is_impossible_routing:
            z += 5.0
        if is_impersonation:
            z += 4.0
        if is_synthetic_entropy:
            z += 2.0
        if is_wangiri_risk:
            z += 4.5
        if has_arithmetic_pattern:
            z += 2.0

        # Modificateur cryptographique STIR/SHAKEN
        if stir_attestation == 'A':
            z -= 2.5
        elif stir_attestation == 'C':
            z += 2.0
        elif stir_attestation == 'B':
            z += 0.5

        if x_threat == 0 and decayed_spam == 0 and not is_impossible_routing and not is_synthetic_entropy and not is_impersonation and not is_wangiri_risk and not has_arithmetic_pattern:
            composite_score = 0
        else:
            bounded_z = max(-10.0, min(10.0, z))
            prob_threat = 1.0 / (1.0 + math.exp(-bounded_z))
            composite_score = int(round(prob_threat * 100))

        # Calcul de l'indice de confiance de faux-positif (0 à 100%)
        if not is_impersonation and (x_legit > 0.15 or safe_ratio >= 0.30 or decayed_safe >= 1.0):
            fp_raw = (x_legit * 55.0) + (safe_ratio * 45.0) - (x_threat * 18.0)
            if stir_attestation == 'A':
                fp_raw += 15.0
            fp_conf = max(15.0, min(99.0, round(fp_raw, 1)))
        else:
            fp_conf = max(0.0, min(14.0, round(10.0 - (composite_score * 0.1), 1)))

        return composite_score, fp_conf


class ShieldNetAIEngine:
    """
    Moteur de diagnostic et d'arbitrage multimodal haute précision.
    Combine l'inférence bayésienne à N-grammes, la validation télécom NANP,
    la détection de rafales par processus de Poisson, l'entropie spectrale,
    l'amortissement temporel et la fusion logistique sigmoïde.
    """

    NANP_PATTERN = re.compile(r'^\+1[2-9]\d{2}[2-9]\d{6}$')
    NANP_FICTITIOUS_555 = re.compile(r'^\+1\d{3}55501\d{2}$')

    @classmethod
    def diagnose(
        cls,
        phone_number: str = None,
        phone_hash: str = None,
        attestation: str = None,
        profile: str = 'balanced'
    ) -> dict:
        start_time = time.perf_counter()

        if phone_number and not phone_hash:
            phone_hash = hash_phone_number(phone_number)
        elif not phone_hash:
            return {'error': "Aucun numéro ou empreinte fourni."}

        number_obj = BlacklistedNumber.objects.filter(phone_hash=phone_hash).first()
        spam_reports = list(SpamReport.objects.filter(phone_hash=phone_hash).order_by('-created_at'))
        safe_reports = list(SafeReport.objects.filter(phone_hash=phone_hash).order_by('-created_at'))

        spam_comments = [s.comment for s in spam_reports if s.comment]
        safe_comments = [r.comment for r in safe_reports if r.comment]
        masked = number_obj.masked_number if number_obj and number_obj.masked_number else (
            mask_phone_number(phone_number) if phone_number else '***'
        )

        # 1. Analyse sémantique bayésienne et détection d'usurpation
        nlp_res = NLPSemanticAnalyzer.analyze(spam_comments, safe_comments)
        legit_score = nlp_res['legitimacy_score']
        threat_score = nlp_res['threat_score']
        is_impersonation = nlp_res.get('is_impersonation', False)
        xai_factors = list(nlp_res['xai_factors'])

        # 2. Amortissement temporel exponentiel
        decayed_spam_weight = sum(
            TemporalDecayService.calculate_decay_weight(s.created_at) for s in spam_reports
        )
        decayed_safe_weight = sum(
            TemporalDecayService.calculate_decay_weight(r.created_at) for r in safe_reports
        )

        spam_count = len(spam_reports)
        safe_count = len(safe_reports)
        total_interactions = spam_count + safe_count
        safe_ratio = (safe_count / total_interactions) if total_interactions > 0 else 0.0

        # 3. Détection de rafale temporelle (Processus de Poisson et Z-score)
        spam_timestamps = [s.created_at for s in spam_reports if s.created_at]
        burst_eval = PoissonBurstAnalyzer.evaluate_burst(spam_timestamps, window_hours=2.0)
        if burst_eval['is_burst']:
            xai_factors.append({
                'type': 'POISSON_BURST',
                'impact': 'NEGATIVE',
                'weight': min(40, int(burst_eval['z_score'] * 10)),
                'description': burst_eval['description']
            })

        # Convergence des catégories d'infraction
        categories = [s.category for s in spam_reports]
        high_risk_categories = sum(1 for c in categories if c in ['fraud', 'financial_scam', 'phishing', 'robocall'])
        high_risk_ratio = (high_risk_categories / spam_count) if spam_count > 0 else 0.0
        if high_risk_ratio >= 0.75 and spam_count >= 2:
            threat_score = min(100.0, threat_score + 25.0)
            xai_factors.append({
                'type': 'CATEGORY_PURITY',
                'impact': 'NEGATIVE',
                'weight': 20,
                'description': f"Forte convergence citoyenne vers des infractions criminelles ({int(high_risk_ratio * 100)}% de fraude/phishing)."
            })

        # 4. Validation structurelle NANP, Entropie de Shannon et Détection Arithmétique
        nanp_eval = NANPTelephonyValidator.validate_number(phone_number)
        entropy_eval = {'entropy': 0.0, 'is_synthetic': False}
        arithmetic_eval = {'has_pattern': False, 'pattern_type': None, 'description': ''}

        if phone_number:
            entropy_eval = ShannonEntropyAnalyzer.evaluate_entropy_risk(phone_number)
            arithmetic_eval = ArithmeticSequenceAnalyzer.evaluate_sequences(phone_number)

            if arithmetic_eval['has_pattern']:
                threat_score = min(100.0, threat_score + 30.0)
                xai_factors.append({
                    'type': 'ARITHMETIC_PATTERN',
                    'impact': 'NEGATIVE',
                    'weight': 30,
                    'description': arithmetic_eval['description']
                })

            if entropy_eval['is_synthetic']:
                threat_score = min(100.0, threat_score + 30.0)
                xai_factors.append({
                    'type': 'ENTROPY_ANOMALY',
                    'impact': 'NEGATIVE',
                    'weight': 30,
                    'description': entropy_eval['description']
                })

            if nanp_eval.get('is_wangiri_risk'):
                threat_score = max(threat_score, 90.0)
                xai_factors.append({
                    'type': 'WANGIRI_FRAUD',
                    'impact': 'NEGATIVE',
                    'weight': 50,
                    'description': nanp_eval['details']
                })
            elif nanp_eval['is_impossible_routing']:
                threat_score = max(threat_score, 85.0)
                xai_factors.append({
                    'type': 'TELECOM_STRUCTURE',
                    'impact': 'NEGATIVE',
                    'weight': 45,
                    'description': nanp_eval['details']
                })
            elif not nanp_eval['is_valid_nanp'] and not nanp_eval.get('is_valid_international'):
                xai_factors.append({
                    'type': 'TELECOM_STRUCTURE',
                    'impact': 'NEGATIVE',
                    'weight': 25,
                    'description': "Format ou indicatif non standard dans le plan de numérotation nord-américain."
                })

        # Consensus communautaire favorable
        if safe_count > 0:
            xai_factors.append({
                'type': 'COMMUNITY_CONSENSUS',
                'impact': 'POSITIVE',
                'weight': min(40, safe_count * 15),
                'description': f"Présence de {safe_count} avis légitimes / contestations citoyennes favorables."
            })

        # Évaluation STIR/SHAKEN
        clean_attestation = (attestation or '').strip().upper()
        if clean_attestation == 'A':
            legit_score += 25.0
            threat_score = max(0.0, threat_score - 20.0)
            xai_factors.append({
                'type': 'STIR_SHAKEN',
                'impact': 'POSITIVE',
                'weight': 30,
                'description': "Attestation STIR/SHAKEN Niveau A (Signature cryptographique pleine par l'opérateur source)."
            })
        elif clean_attestation == 'C':
            threat_score = min(100.0, threat_score + 25.0)
            xai_factors.append({
                'type': 'STIR_SHAKEN',
                'impact': 'NEGATIVE',
                'weight': 25,
                'description': "Attestation STIR/SHAKEN Niveau C (Appel acheminé via passerelle VoIP sans validation d'origine)."
            })
        elif clean_attestation == 'B':
            xai_factors.append({
                'type': 'STIR_SHAKEN',
                'impact': 'NEGATIVE',
                'weight': 10,
                'description': "Attestation STIR/SHAKEN Niveau B (Authenticité partielle du trunk SIP d'entreprise)."
            })

        # Qualification de l'incertitude épistémique (maturité de l'échantillon)
        if total_interactions >= 5:
            epistemic_confidence = "ELEVEE (Échantillon robuste >5 retours)"
        elif total_interactions >= 2:
            epistemic_confidence = "MODEREE (Quorum citoyen émergent)"
        else:
            epistemic_confidence = "PRELIMINAIRE (Signalement individuel ou inférence heuristique)"

        # 5. Fusion décisionnelle par régression logistique sigmoïde (Platt Scaling)
        ai_risk_score, fp_confidence = CalibratedDecisionFusion.fuse_signals(
            threat_score=threat_score,
            legit_score=legit_score,
            decayed_spam=decayed_spam_weight,
            decayed_safe=decayed_safe_weight,
            burst_z_score=burst_eval['z_score'],
            entropy_val=entropy_eval['entropy'],
            is_synthetic_entropy=entropy_eval['is_synthetic'],
            is_impossible_routing=nanp_eval['is_impossible_routing'] and spam_count >= 1,
            is_impersonation=is_impersonation,
            stir_attestation=clean_attestation,
            profile_name=profile,
            is_wangiri_risk=nanp_eval.get('is_wangiri_risk', False),
            has_arithmetic_pattern=arithmetic_eval['has_pattern'],
        )

        # Décision humaine souveraine
        if number_obj and number_obj.is_whitelisted:
            ai_risk_score = 0
            xai_factors.insert(0, {
                'type': 'ADMIN_DECISION',
                'impact': 'POSITIVE',
                'weight': 100,
                'description': "Numéro officiellement réhabilité et blanchi par l'administration SOC."
            })
        elif number_obj and number_obj.is_blocked and number_obj.risk_score >= 80:
            ai_risk_score = max(ai_risk_score, 85)

        # 6. Verdict final et recommandations
        if number_obj and number_obj.is_whitelisted:
            verdict = "REHABILITE_BLANCHI"
            verdict_label = "Blanchi & Réhabilité"
            recommendation = "NONE"
            recommendation_label = "Aucune action nécessaire"
            confidence_level = 100.0
            badge_class = "badge-safe"
        elif fp_confidence >= 65.0 and ai_risk_score <= 45:
            verdict = "FAUX_POSITIF_CONFIRME"
            verdict_label = "Faux-Positif Confirmé (Service Essentiel)"
            recommendation = "AUTO_WHITELIST"
            recommendation_label = "Blanchir Immédiatement (Recommandé)"
            confidence_level = fp_confidence
            badge_class = "badge-safe"
        elif ai_risk_score >= 70:
            verdict = "CYBER_MENACE_CRITIQUE"
            verdict_label = "Menace Télécom Critique Confirmée"
            recommendation = "ESCALATE_BLOCK"
            recommendation_label = "Bloquer sur Tout le Réseau"
            confidence_level = round(min(99.0, 50.0 + (ai_risk_score * 0.49)), 1)
            badge_class = "badge-critical"
        elif ai_risk_score >= 35:
            verdict = "SUSPECT_SURVEILLANCE"
            verdict_label = "Activité Suspecte sous Surveillance"
            recommendation = "MONITOR"
            recommendation_label = "Surveiller les Prochains Appels"
            confidence_level = 65.0
            badge_class = "badge-warning"
        else:
            verdict = "SAIN_NEUTRE"
            verdict_label = "Numéro Réputé Sain"
            recommendation = "NONE"
            recommendation_label = "Conforme aux Normes Télécom"
            confidence_level = 92.0
            badge_class = "badge-safe"

        # Synthèse explicative humaine et claire
        if verdict == "FAUX_POSITIF_CONFIRME":
            summary = (
                f"Probabilité élevée de faux-positif ({fp_confidence}%). "
                f"L'analyse des commentaires indique un service légitime "
                f"({', '.join(nlp_res['detected_entities']) or 'service vérifié'}) et les avis positifs "
                f"sont supérieurs aux signalements négatifs."
            )
        elif verdict == "CYBER_MENACE_CRITIQUE":
            summary = (
                f"Numéro identifié comme menace indésirable (Score {ai_risk_score}/100). "
                f"Des motifs d'escroquerie ont été détectés "
                f"({', '.join(nlp_res['detected_entities']) or 'signalements récents'})."
            )
        elif verdict == "SUSPECT_SURVEILLANCE":
            summary = (
                f"Numéro à risque modéré ({ai_risk_score}/100). Signalements encore limités, "
                f"placé sous surveillance active."
            )
        else:
            summary = "Aucune anomalie ou motif d'arnaque identifié pour ce numéro."

        elapsed_ms = (time.perf_counter() - start_time) * 1000.0

        formatted_xai = []
        for factor in xai_factors:
            is_pos = factor.get('impact') == 'POSITIVE' or factor.get('direction') == 'positive'
            desc = factor.get('description') or factor.get('factor') or ''
            formatted_xai.append({
                'type': factor.get('type', 'GENERAL'),
                'impact': 'POSITIVE' if is_pos else 'NEGATIVE',
                'direction': 'positive' if is_pos else 'threat',
                'weight': factor.get('weight', 0),
                'description': desc,
                'factor': desc,
            })

        return {
            'success': True,
            'phone_number': phone_number or masked,
            'phone_hash': phone_hash,
            'masked_number': masked,
            'ai_risk_score': ai_risk_score,
            'composite_risk_score': ai_risk_score,
            'false_positive_confidence': fp_confidence,
            'confidence_level': confidence_level,
            'verdict': verdict,
            'verdict_label': verdict_label,
            'badge_class': badge_class,
            'recommendation': recommendation,
            'recommendation_label': recommendation_label,
            'detected_entities': nlp_res['detected_entities'],
            'extracted_entities': nlp_res['detected_entities'],
            'xai_factors': formatted_xai,
            'diagnostic_summary': summary,
            'verdict_description': summary,
            'execution_time_ms': round(max(0.1, elapsed_ms), 2),
            'metrics': {
                'spam_reports': spam_count,
                'decayed_spam_weight': round(decayed_spam_weight, 2),
                'safe_reports': safe_count,
                'decayed_safe_weight': round(decayed_safe_weight, 2),
                'safe_ratio_pct': round(safe_ratio * 100, 1),
                'velocity_recent_2h': burst_eval['recent_count'],
                'burst_z_score': burst_eval['z_score'],
                'digit_entropy': entropy_eval['entropy'],
                'is_synthetic_entropy': entropy_eval['is_synthetic'],
                'is_impersonation_attack': is_impersonation,
                'is_impossible_routing': nanp_eval['is_impossible_routing'],
                'nlp_legitimacy_score': legit_score,
                'nlp_threat_score': threat_score,
                'bayes_threat_prob': nlp_res['bayes']['probability_threat'],
                'stir_shaken_attestation': clean_attestation if clean_attestation in ('A', 'B', 'C') else None,
                'has_arithmetic_pattern': arithmetic_eval['has_pattern'],
                'is_wangiri_risk': nanp_eval.get('is_wangiri_risk', False),
                'epistemic_confidence': epistemic_confidence,
            }
        }
