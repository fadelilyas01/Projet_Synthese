package com.shieldnet.shieldnet

import android.content.Context
import android.os.Build
import android.telecom.Call
import android.telecom.CallScreeningService
import android.util.Log
import androidx.annotation.RequiresApi

@RequiresApi(Build.VERSION_CODES.Q)
class ShieldNetCallScreeningService : CallScreeningService() {

    companion object {
        private const val TAG = "ShieldNetScreening"
    }

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

    private val TOLL_FREE_PREFIXES = setOf("800", "888", "877", "866", "855", "844", "833")

    /**
     * Détecte les faux numéros impossibles selon le plan de numérotation nord-américain (NANP)
     * Les robots usurpateurs génèrent souvent des numéros syntaxiquement invalides.
     */
    private fun isInvalidNanpFormat(rawNumber: String): Boolean {
        val digits = rawNumber.replace(Regex("\\D"), "")
        val tenDigits = when {
            digits.length == 10 -> digits
            digits.length == 11 && digits.startsWith("1") -> digits.substring(1)
            else -> null
        } ?: return false

        // 1. Règle NANP : L'indicatif régional (NPA) ne peut pas commencer par 0 ou 1
        if (tenDigits[0] == '0' || tenDigits[0] == '1') return true

        // 2. Règle NANP : Le central téléphonique (NXX) ne peut pas commencer par 0 ou 1
        if (tenDigits[3] == '0' || tenDigits[3] == '1') return true

        // 3. Indicatifs de central fictifs réservés pour la fiction (ex: 555-0100 à 555-0199)
        if (tenDigits.substring(3, 6) == "555") return true

        // 4. Motifs artificiels de robots (séquences répétitives identiques sur 4 chiffres)
        if (tenDigits.substring(6).all { it == tenDigits[6] }) return true

        return false
    }

    /**
     * Détecte le "Neighbor Spoofing" : l'usurpateur copie les 6 premiers chiffres
     * (indicatif régional + central) de la victime pour simuler un voisin ou un commerce local.
     */
    private fun isNeighborSpoofing(context: Context, rawNumber: String): Boolean {
        return try {
            val telephonyManager = context.getSystemService(Context.TELEPHONY_SERVICE) as? android.telephony.TelephonyManager
            val userNumber = telephonyManager?.line1Number ?: ""
            val userDigits = userNumber.replace(Regex("\\D"), "")
            val rawDigits = rawNumber.replace(Regex("\\D"), "")

            val user10 = if (userDigits.length == 11 && userDigits.startsWith("1")) userDigits.substring(1) else userDigits
            val raw10 = if (rawDigits.length == 11 && rawDigits.startsWith("1")) rawDigits.substring(1) else rawDigits

            if (user10.length == 10 && raw10.length == 10) {
                val sameCluster = user10.substring(0, 6) == raw10.substring(0, 6)
                if (sameCluster && user10 != raw10 && !isContact(rawNumber)) {
                    Log.w(TAG, "ALERTE NEIGHBOR SPOOFING : Les 6 premiers chiffres usurpent le quartier local de l'utilisateur ($rawNumber)")
                    return true
                }
            }
            false
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

        // 1. Calcul du hash HMAC-SHA256 avec normalisation E.164
        val phoneHash = ShieldNetDatabaseHelper.hashPhoneNumber(applicationContext, rawNumber)
        Log.d(TAG, "Appel entrant reçu: $rawNumber -> Empreinte: $phoneHash")

        // 1.5 PRIORITÉ ABSOLUE : Vérification d'Urgence & Liste Blanche (Immunité Totale)
        if (ShieldNetDatabaseHelper.isEmergencyNumber(applicationContext, rawNumber, phoneHash)) {
            Log.i(TAG, "IMMUNITÉ ACCORDÉE : Appel d'urgence ou contact prioritaire autorisé sans délai ($rawNumber)")
            respondToCall(callDetails, CallResponse.Builder().build())
            return
        }

        // 2. Interrogation directe de la base SQLite partagée (Spam avéré en liste noire)
        if (ShieldNetDatabaseHelper.isNumberBlacklisted(applicationContext, phoneHash)) {
            Log.w(TAG, "APPEL SPAM BLOQUÉ EN TEMPS RÉEL (Liste Noire) ! Empreinte: $phoneHash")
            val response = CallResponse.Builder()
                .setDisallowCall(true)            
                .setRejectCall(true)              
                .setSkipCallLog(false)            
                .setSkipNotification(true)        
                .build()

            respondToCall(callDetails, response)
            return
        }

        // 3. VÉRIFICATION CRYPTOGRAPHIQUE STIR/SHAKEN (Opérateur Télécom)
        // Si l'opérateur télécom atteste que le numéro appelant a échoué à la signature cryptographique
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val verificationStatus = callDetails.callerNumberVerificationStatus
            if (verificationStatus == android.telecom.Connection.VERIFICATION_STATUS_FAILED) {
                Log.w(TAG, "REJET SÉCURITÉ STIR/SHAKEN : Usurpation d'identité confirmée par l'opérateur pour $rawNumber")
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

        // 4. ANALYSE HEURISTIQUE DES FAUX NUMÉROS NANP IMPOSSIBLES
        if (isInvalidNanpFormat(rawNumber) && !isContact(rawNumber)) {
            Log.w(TAG, "REJET SÉCURITÉ : Format de numéro NANP frauduleux ou synthétique détecté ($rawNumber)")
            val response = CallResponse.Builder()
                .setDisallowCall(true)
                .setRejectCall(true)
                .setSkipCallLog(false)
                .setSkipNotification(true)
                .build()

            respondToCall(callDetails, response)
            return
        }

        // 5. ANALYSE ANTI-NEIGHBOR SPOOFING (Usurpation des 6 chiffres locaux)
        if (isNeighborSpoofing(applicationContext, rawNumber)) {
            Log.w(TAG, "REJET SÉCURITÉ : Tentative d'usurpation de numéro voisin (Neighbor Spoofing) interceptée ($rawNumber)")
            val response = CallResponse.Builder()
                .setDisallowCall(true)
                .setRejectCall(true)
                .setSkipCallLog(false)
                .setSkipNotification(true)
                .build()

            respondToCall(callDetails, response)
            return
        }

        // 6. Vérification du Mode Bouclier Strict (Contacts uniquement)
        if (isContactsOnlyEnabled()) {
            val inContacts = isContact(rawNumber)
            if (!inContacts) {
                Log.w(TAG, "APPEL INCONNU REJETÉ (Mode Contacts Uniquement actif) : $rawNumber")
                val response = CallResponse.Builder()
                    .setDisallowCall(true)
                    .setRejectCall(true)
                    .setSkipCallLog(false)
                    .setSkipNotification(false)
                    .build()

                respondToCall(callDetails, response)
                return
            } else {
                Log.d(TAG, "Numéro identifié dans les contacts : $rawNumber")
            }
        }

        Log.d(TAG, "Numéro vérifié et autorisé.")
        respondToCall(callDetails, CallResponse.Builder().build())
    }
}
