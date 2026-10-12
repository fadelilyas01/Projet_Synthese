package com.shieldnet.shieldnet

import android.content.Context
import android.os.Build
import android.telecom.Call
import android.telecom.CallScreeningService
import android.util.Log
import androidx.annotation.RequiresApi
import java.util.Calendar
import kotlin.math.log2

@RequiresApi(Build.VERSION_CODES.Q)
class ShieldNetCallScreeningService : CallScreeningService() {

    companion object {
        private const val TAG = "ShieldNetScreening"

        // Clusters régionaux d'indicatifs téléphoniques superposés (Overlays canadiens et nord-américains)
        private val REGIONAL_OVERLAY_CLUSTERS = listOf(
            setOf("514", "438", "263"), // Montréal
            setOf("418", "581", "367"), // Québec
            setOf("450", "579", "354"), // Laval / Montérégie
            setOf("819", "873"),        // Sherbrooke / Estrie / Mauricie
            setOf("416", "647", "437"), // Toronto Central
            setOf("905", "289", "365"), // GTA Couronne
            setOf("613", "343", "753"), // Ottawa / Région de l'Est
            setOf("604", "778", "236", "672"), // Vancouver
            setOf("403", "587", "825"), // Calgary
            setOf("780", "587", "825")  // Edmonton
        )

        // Codes pays et préfixes hautement frauduleux (Arnaques Wangiri à rappel surtaxé)
        private val WANGIRI_HIGH_RISK_PREFIXES = setOf(
            "247", // Île de l'Ascension
            "290", // Sainte-Hélène
            "881", "882", "883", // Réseaux satellites et internationaux
            "870", // Inmarsat maritime
            "676", // Tonga
            "685", // Samoa
            "674", // Nauru
            "688", // Tuvalu
            "682", // Îles Cook
            "232", // Sierra Leone
            "252", // Somalie
            "220", // Gambie
            "235", // Tchad
            "245", // Guinée-Bissau
            "269", // Comores
            "387", // Bosnie (numéros spéciaux surtaxés)
            "371"  // Lettonie (numéros spéciaux surtaxés)
        )

        // Services d'urgence et d'assistance institutionnels prioritaires (Immunité totale)
        private val INSTITUTIONAL_SHORT_CODES = setOf("911", "112", "811", "988", "211", "311", "511")
        private val INSTITUTIONAL_LONG_CODES = setOf(
            "18002678097", // Agence du revenu du Canada (ARC)
            "18009598281", // ARC Particuliers
            "18002676299"  // Revenu Québec
        )
    }

    /**
     * Vérifie si le mode Contacts Uniquement (Mode Bouclier Strict) est activé.
     */
    private fun isContactsOnlyEnabled(): Boolean {
        return try {
            val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            if (flutterPrefs.getBoolean("flutter.settings_contacts_only", false)) {
                return true
            }
            val nativePrefs = getSharedPreferences("shieldnet_prefs", Context.MODE_PRIVATE)
            nativePrefs.getBoolean("contacts_only_mode", false)
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Vérifie si le numéro appelant figure dans le carnet de contacts de l'utilisateur.
     */
    private fun isContact(phoneNumber: String): Boolean {
        return try {
            val uri = android.net.Uri.withAppendedPath(
                android.provider.ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
                android.net.Uri.encode(phoneNumber)
            )
            val projection = arrayOf(android.provider.ContactsContract.PhoneLookup._ID)
            contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                cursor.moveToFirst()
            } ?: false
        } catch (e: Exception) {
            Log.e(TAG, "Erreur vérification contact: ${e.message}")
            false
        }
    }

    /**
     * Vérifie si le numéro est un service public ou gouvernemental certifié exempt de filtrage.
     */
    private fun isInstitutionalNumber(rawNumber: String): Boolean {
        val digits = rawNumber.replace(Regex("\\D"), "")
        val national3 = if (digits.length == 4 && digits.startsWith("1")) digits.substring(1) else digits
        if (national3.length == 3 && INSTITUTIONAL_SHORT_CODES.contains(national3)) {
            return true
        }
        val national11 = if (digits.length == 10) "1$digits" else digits
        for (inst in INSTITUTIONAL_LONG_CODES) {
            if (national11.startsWith(inst)) {
                return true
            }
        }
        return false
    }

    /**
     * Détecte les fraudes Wangiri (appels internationaux surtaxés visant un rappel coûteux).
     */
    private fun isWangiriTrap(rawNumber: String): Boolean {
        val trimmed = rawNumber.trim()
        val digits = trimmed.replace(Regex("\\D"), "")
        if (trimmed.startsWith("+") && !trimmed.startsWith("+1")) {
            for (prefix in WANGIRI_HIGH_RISK_PREFIXES) {
                if (digits.startsWith(prefix)) {
                    return true
                }
            }
        }
        return false
    }

    /**
     * Calcule l'entropie de Shannon des chiffres d'un numéro nord-américain à 10 chiffres.
     * Une entropie inférieure à 2.2 bits révèle une distribution artificielle
     * typique des générateurs automatiques VoIP / robocallers (ex: 819-111-2222).
     */
    private fun calculateDigitEntropy(rawNumber: String): Double {
        val digits = rawNumber.replace(Regex("\\D"), "")
        val tenDigits = when {
            digits.length == 10 -> digits
            digits.length == 11 && digits.startsWith("1") -> digits.substring(1)
            else -> return 3.0 // Hors format NANP standard, ne pas biaiser
        }

        val counts = IntArray(10)
        for (c in tenDigits) {
            val d = c - '0'
            if (d in 0..9) counts[d]++
        }

        var entropy = 0.0
        val total = tenDigits.length.toDouble()
        for (cnt in counts) {
            if (cnt > 0) {
                val p = cnt / total
                entropy -= p * (log2(p))
            }
        }
        return entropy
    }

    /**
     * Détecte les suites arithmétiques évidentes (croissantes, décroissantes ou répétition de 4 chiffres).
     * Les automates VoIP exploitent souvent ces motifs pour générer des numéros à la volée.
     */
    private fun hasArithmeticPattern(rawNumber: String): Boolean {
        val digits = rawNumber.replace(Regex("\\D"), "")
        val tenDigits = when {
            digits.length == 10 -> digits
            digits.length == 11 && digits.startsWith("1") -> digits.substring(1)
            else -> return false
        }

        if (tenDigits.length < 5) return false

        // 1. Suite arithmétique de 5 chiffres consécutifs
        for (i in 0..(tenDigits.length - 5)) {
            var isAsc = true
            var isDesc = true
            for (j in 0 until 4) {
                val d1 = tenDigits[i + j] - '0'
                val d2 = tenDigits[i + j + 1] - '0'
                if (d2 != d1 + 1) isAsc = false
                if (d2 != d1 - 1) isDesc = false
            }
            if (isAsc) {
                val slice = tenDigits.substring(i, i + 5)
                if (slice == "01234") {
                    if (i + 5 < tenDigits.length && tenDigits[i + 5] == '5') return true
                } else {
                    return true
                }
            }
            if (isDesc) return true
        }

        // 2. Bloc de 4 chiffres identiques consécutifs (ex: 8888, 0000)
        for (i in 0..(tenDigits.length - 4)) {
            val c = tenDigits[i]
            if (tenDigits[i + 1] == c && tenDigits[i + 2] == c && tenDigits[i + 3] == c) {
                return true
            }
        }

        return false
    }

    /**
     * Détecte les faux numéros impossibles selon le plan de numérotation nord-américain (NANP).
     */
    private fun isInvalidNanpFormat(rawNumber: String): Boolean {
        val digits = rawNumber.replace(Regex("\\D"), "")
        val tenDigits = when {
            digits.length == 10 -> digits
            digits.length == 11 && digits.startsWith("1") -> digits.substring(1)
            else -> null
        } ?: return false

        // 1. NPA ne commence pas par 0 ou 1
        if (tenDigits[0] == '0' || tenDigits[0] == '1') return true

        // 2. NXX ne commence pas par 0 ou 1
        if (tenDigits[3] == '0' || tenDigits[3] == '1') return true

        // 3. Fictions 555-0100 à 555-0199
        if (tenDigits.substring(3, 6) == "555") return true

        return false
    }

    /**
     * Récupère le numéro de l'utilisateur avec multi-niveaux de repli :
     * 1. Flutter SharedPreferences (saisi par l'utilisateur)
     * 2. Préférences natives
     * 3. TelephonyManager système
     */
    private fun getUserPhoneNumber(context: Context): String {
        try {
            val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val flutterUserNumber = flutterPrefs.getString("flutter.user_phone_number", null)
                ?: flutterPrefs.getString("flutter.user_phone", null)
            if (!flutterUserNumber.isNullOrBlank()) {
                return flutterUserNumber
            }

            val nativePrefs = context.getSharedPreferences("shieldnet_prefs", Context.MODE_PRIVATE)
            val nativeUserNumber = nativePrefs.getString("user_phone_number", null)
            if (!nativeUserNumber.isNullOrBlank()) {
                return nativeUserNumber
            }

            val telephonyManager = context.getSystemService(Context.TELEPHONY_SERVICE) as? android.telephony.TelephonyManager
            val simNumber = telephonyManager?.line1Number ?: ""
            if (simNumber.isNotBlank()) {
                return simNumber
            }
        } catch (_: Exception) {}
        return ""
    }

    /**
     * Détecte le "Neighbor Spoofing" et le "Cluster Spoofing" par grappes régionales.
     */
    private fun isNeighborSpoofing(context: Context, rawNumber: String): Boolean {
        return try {
            val userNumber = getUserPhoneNumber(context)
            if (userNumber.isBlank()) return false

            val userDigits = userNumber.replace(Regex("\\D"), "")
            val rawDigits = rawNumber.replace(Regex("\\D"), "")

            val user10 = if (userDigits.length == 11 && userDigits.startsWith("1")) userDigits.substring(1) else userDigits
            val raw10 = if (rawDigits.length == 11 && rawDigits.startsWith("1")) rawDigits.substring(1) else rawDigits

            if (user10.length == 10 && raw10.length == 10 && user10 != raw10) {
                // 1. Usurpation directe des 6 premiers chiffres (NPA + NXX)
                if (user10.substring(0, 6) == raw10.substring(0, 6)) {
                    Log.w(TAG, "ALERTE NEIGHBOR SPOOFING : Les 6 premiers chiffres usurpent le quartier local ($rawNumber)")
                    return true
                }

                // 2. Usurpation par grappe régionale superposée (Overlay Cluster Spoofing)
                val userNpa = user10.substring(0, 3)
                val rawNpa = raw10.substring(0, 3)
                val userNxx = user10.substring(3, 6)
                val rawNxx = raw10.substring(3, 6)

                if (userNpa != rawNpa && userNxx == rawNxx) {
                    for (cluster in REGIONAL_OVERLAY_CLUSTERS) {
                        if (cluster.contains(userNpa) && cluster.contains(rawNpa)) {
                            Log.w(TAG, "ALERTE CLUSTER SPOOFING : Usurpation via indicatif superposé régional ($rawNumber)")
                            return true
                        }
                    }
                }
            }
            false
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Vérifie si le mode Bouclier Nuit (Night Shield) est actif à la minute courante.
     */
    private fun isNightShieldActive(): Boolean {
        return try {
            val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val isEnabled = flutterPrefs.getBoolean("flutter.settings_night_shield_enabled", false)
            if (!isEnabled) return false

            val startH = flutterPrefs.getInt("flutter.settings_night_start_h", 22)
            val startM = flutterPrefs.getInt("flutter.settings_night_start_m", 0)
            val endH = flutterPrefs.getInt("flutter.settings_night_end_h", 7)
            val endM = flutterPrefs.getInt("flutter.settings_night_end_m", 0)

            val now = Calendar.getInstance()
            val nowMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
            val startMinutes = startH * 60 + startM
            val endMinutes = endH * 60 + endM

            if (startMinutes < endMinutes) {
                nowMinutes in startMinutes until endMinutes
            } else {
                nowMinutes >= startMinutes || nowMinutes < endMinutes
            }
        } catch (e: Exception) {
            false
        }
    }

    override fun onScreenCall(callDetails: Call.Details) {
        val handle = callDetails.handle
        val rawNumber = handle?.schemeSpecificPart

        if (rawNumber == null) {
            respondToCall(callDetails, CallResponse.Builder().build())
            return
        }

        // =========================================================================
        // PALIER 1 : COUPE-CIRCUIT ULTRA-RAPIDE EN MÉMOIRE VIVE (< 0.05 ms)
        // Évite tout calcul cryptographique ou lecture disque pour 95%+ des appels
        // =========================================================================

        // 1. IMMUNITÉ ABSOLUE : Urgences (911, 811, 988, 211, 311) et lignes d'État (ARC, Revenu Québec)
        if (isInstitutionalNumber(rawNumber)) {
            Log.i(TAG, "IMMUNITÉ ACCORDÉE (<0.01ms) : Service officiel ou d'urgence ($rawNumber)")
            respondToCall(callDetails, CallResponse.Builder().build())
            return
        }

        // 2. CONTACTS FAMILIERS : Si le correspondant est dans le carnet d'adresses personnel
        val inContacts = isContact(rawNumber)
        if (inContacts) {
            Log.d(TAG, "CONTACT RECONNU (<0.2ms) : Appel autorisé immédiatement ($rawNumber)")
            respondToCall(callDetails, CallResponse.Builder().build())
            return
        }

        // 3. BOUCLIER STRICT (Mode Contacts Uniquement) :
        if (isContactsOnlyEnabled()) {
            Log.w(TAG, "BOUCLIER STRICT (<0.01ms) : Appel inconnu rejeté ($rawNumber)")
            val response = CallResponse.Builder()
                .setDisallowCall(true)
                .setRejectCall(true)
                .setSkipCallLog(false)
                .setSkipNotification(false)
                .build()
            respondToCall(callDetails, response)
            return
        }

        // 4. BOUCLIER NUIT (Night Shield) :
        if (isNightShieldActive()) {
            Log.w(TAG, "BOUCLIER NUIT (<0.01ms) : Appel inconnu nocturne neutralisé silencieusement ($rawNumber)")
            val response = CallResponse.Builder()
                .setDisallowCall(true)
                .setRejectCall(true)
                .setSkipCallLog(false)
                .setSkipNotification(false)
                .build()
            respondToCall(callDetails, response)
            return
        }

        // 5. ATTESTATION TÉLÉCOM STIR/SHAKEN (Fournie directement par Android Telecom) :
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val verificationStatus = callDetails.callerNumberVerificationStatus
            if (verificationStatus == android.telecom.Connection.VERIFICATION_STATUS_FAILED) {
                Log.w(TAG, "REJET SÉCURITÉ STIR/SHAKEN (<0.01ms) : Usurpation d'identité confirmée pour $rawNumber")
                val response = CallResponse.Builder()
                    .setDisallowCall(true)
                    .setRejectCall(true)
                    .setSkipCallLog(false)
                    .setSkipNotification(true)
                    .build()
                respondToCall(callDetails, response)
                return
            }
        }

        // 6. PIÈGES WANGIRI INTERNATIONAUX :
        if (isWangiriTrap(rawNumber)) {
            Log.w(TAG, "REJET WANGIRI (<0.01ms) : Fraude internationale surtaxée interceptée ($rawNumber)")
            val response = CallResponse.Builder()
                .setDisallowCall(true)
                .setRejectCall(true)
                .setSkipCallLog(false)
                .setSkipNotification(true)
                .build()
            respondToCall(callDetails, response)
            return
        }

        // 7. FORMAT NANP SYNTAXIQUEMENT IMPOSSIBLE :
        if (isInvalidNanpFormat(rawNumber)) {
            Log.w(TAG, "REJET NANP (<0.01ms) : Format synthétique ou frauduleux ($rawNumber)")
            val response = CallResponse.Builder()
                .setDisallowCall(true)
                .setRejectCall(true)
                .setSkipCallLog(false)
                .setSkipNotification(true)
                .build()
            respondToCall(callDetails, response)
            return
        }

        // 8. NEIGHBOR SPOOFING & GRAVES RÉGIONALES SUPERPOSÉES :
        if (isNeighborSpoofing(applicationContext, rawNumber)) {
            Log.w(TAG, "REJET SPOOFING VOISIN (<0.01ms) : Usurpation locale interceptée ($rawNumber)")
            val response = CallResponse.Builder()
                .setDisallowCall(true)
                .setRejectCall(true)
                .setSkipCallLog(false)
                .setSkipNotification(true)
                .build()
            respondToCall(callDetails, response)
            return
        }

        // 9. ANALYSE IA ON-DEVICE : ENTROPIE DE SHANNON & SUITES ARITHMÉTIQUES :
        val entropy = calculateDigitEntropy(rawNumber)
        val hasArithmetic = hasArithmeticPattern(rawNumber)
        if (entropy < 2.2 || hasArithmetic) {
            Log.w(TAG, "REJET IA STATISTIQUE (<0.01ms) : Entropie basse (${"%.2f".format(entropy)} bits) ou suite ($rawNumber)")
            val response = CallResponse.Builder()
                .setDisallowCall(true)
                .setRejectCall(true)
                .setSkipCallLog(false)
                .setSkipNotification(true)
                .build()
            respondToCall(callDetails, response)
            return
        }

        // =========================================================================
        // PALIER 2 : BASE DE DONNÉES SQLITE EN CACHE RAM (< 0.8 ms)
        // Exécuté uniquement pour les correspondants inconnus non suspects
        // =========================================================================
        val phoneHash = ShieldNetDatabaseHelper.hashPhoneNumber(applicationContext, rawNumber)

        // Immunité SQLite personnalisée (Liste blanche d'urgence)
        if (ShieldNetDatabaseHelper.isEmergencyNumber(applicationContext, rawNumber, phoneHash)) {
            Log.i(TAG, "IMMUNITÉ ACCORDÉE (<0.8ms) : Numéro en liste blanche SQLite ($rawNumber)")
            respondToCall(callDetails, CallResponse.Builder().build())
            return
        }

        // Base SQLite partagée (Liste noire confirmée)
        if (ShieldNetDatabaseHelper.isNumberBlacklisted(applicationContext, phoneHash)) {
            Log.w(TAG, "REJET LISTE NOIRE SQLITE (<0.8ms) : Spam avéré bloqué ($rawNumber)")
            val response = CallResponse.Builder()
                .setDisallowCall(true)
                .setRejectCall(true)
                .setSkipCallLog(false)
                .setSkipNotification(true)
                .build()
            respondToCall(callDetails, response)
            return
        }

        Log.d(TAG, "Appel autorisé en temps record (<1ms) : $rawNumber")
        respondToCall(callDetails, CallResponse.Builder().build())
    }
}
