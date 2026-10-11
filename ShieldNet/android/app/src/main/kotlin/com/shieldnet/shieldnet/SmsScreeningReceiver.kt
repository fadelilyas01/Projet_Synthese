package com.shieldnet.shieldnet

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log

class SmsScreeningReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ShieldNetSms"
    }

    private fun isContact(context: Context, phoneNumber: String): Boolean {
        return try {
            val uri = android.net.Uri.withAppendedPath(
                android.provider.ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
                android.net.Uri.encode(phoneNumber)
            )
            val projection = arrayOf(android.provider.ContactsContract.PhoneLookup._ID)
            context.contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                cursor.moveToFirst()
            } ?: false
        } catch (e: Exception) {
            false
        }
    }

    private fun isSmishingSuspicious(body: String?): Boolean {
        if (body.isNullOrBlank()) return false
        val lower = body.lowercase()
        val suspiciousKeywords = listOf(
            "interac", "virement", "remboursement", "colis", "suspendu",
            "bloqué", "urgent", "desjardins", "cliquez", "poste canada", "douane"
        )
        val hasKeyword = suspiciousKeywords.any { lower.contains(it) }
        val hasLink = lower.contains("http://") || lower.contains("https://") || 
                      lower.contains("bit.ly") || lower.contains(".xyz") || lower.contains(".top") || lower.contains("@")
        return hasKeyword && hasLink
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            
            for (sms in messages) {
                val rawNumber = sms.displayOriginatingAddress
                val body = sms.messageBody
                if (!rawNumber.isNullOrEmpty()) {
                    val phoneHash = ShieldNetDatabaseHelper.hashPhoneNumber(context, rawNumber)
                    Log.d(TAG, "SMS reçu depuis $rawNumber -> Hash: $phoneHash")

                    // 1. Immunité d'urgence absolue
                    if (ShieldNetDatabaseHelper.isEmergencyNumber(context, rawNumber, phoneHash)) {
                        Log.i(TAG, "SMS légitime autorisé sans délai ($rawNumber)")
                        continue
                    }
                    
                    // 2. Blocage si numéro sur liste noire
                    if (ShieldNetDatabaseHelper.isNumberBlacklisted(context, phoneHash)) {
                        Log.w(TAG, "SMS SPAM bloqué depuis liste noire: $rawNumber")
                        abortBroadcast()
                        return
                    }

                    // 3. Détection de Smishing heuristique sur inconnu
                    if (!isContact(context, rawNumber) && isSmishingSuspicious(body)) {
                        Log.w(TAG, "SMS SMISHING/PHISHING bloqué en temps réel depuis $rawNumber : $body")
                        abortBroadcast()
                        return
                    }
                }
            }
        }
    }
}

