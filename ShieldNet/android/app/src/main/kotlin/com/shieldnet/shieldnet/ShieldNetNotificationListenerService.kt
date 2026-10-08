package com.shieldnet.shieldnet

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.regex.Pattern

/**
 * Service d'écoute proactif des notifications de messagerie et SMS.
 * Analyse les messages entrants en temps réel à l'aide de motifs heuristiques
 * de détection de phishing (Loi 25 : traitement strictement local sur l'appareil).
 */
class ShieldNetNotificationListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "ShieldNetNotifListener"
        private const val CHANNEL_ID = "shieldnet_phishing_alerts"
        private const val NOTIFICATION_ID = 2026

        // Packages de messagerie SMS courants
        private val SMS_PACKAGES = setOf(
            "com.google.android.apps.messaging",
            "com.samsung.android.messaging",
            "com.android.mms",
            "com.verizon.messaging.vzmsgs"
        )

        // Expressions régulières de détection de phishing bancaire, postal et administratif
        private val SUSPICIOUS_PATTERNS = listOf(
            Pattern.compile("(?i)(interac|desjardins|scotiabank|rbc|td|bmo|cibc|national[ -]?bank|zelle|venmo|chase|wellsfargo)"),
            Pattern.compile("(?i)(remboursement|virement[ -]?en[ -]?attente|bloqu[eé]|suspendu|dépôt|fisc|arc|cra|revenu[ -]?qu[eé]bec|saaq|ramq|hydro[ -]?qu[eé]bec|usps|canadapost|postes[ -]?canada|purolator|fedex|ups|dhl)"),
            Pattern.compile("(?i)(bit\\.ly|tinyurl\\.com|t\\.co|is\\.gd|rb\\.gy|cutt\\.ly|ow\\.ly|shorturl|\\.xyz|\\.top|\\.click|\\.club|\\.sbs|\\.rest|\\.online|\\.site)"),
            Pattern.compile("(?i)(cliquez[ -]?ici|r[eé]clamez|connectez[ -]?vous|urgent|imm[eé]diat|amende|contravention|frais[ -]?de[ -]?douane|frais[ -]?de[ -]?port|colis|livraison|adresse[ -]?incorrecte)")
        )
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val packageName = sbn.packageName
        // Filtre les notifications provenant des applications de messagerie
        if (!SMS_PACKAGES.contains(packageName) && !packageName.contains("sms", ignoreCase = true) && !packageName.contains("mms", ignoreCase = true)) {
            return
        }

        val extras = sbn.notification?.extras ?: return
        val title = extras.getCharSequence("android.title")?.toString() ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        val fullContent = "$title $text"

        if (fullContent.isBlank()) return

        // Analyse heuristique du contenu
        val matchedPatterns = SUSPICIOUS_PATTERNS.count { it.matcher(fullContent).find() }

        // Si au moins 2 indicateurs de risque concordent (ex: banque + lien raccourci ou virement + urgence)
        if (matchedPatterns >= 2) {
            Log.w(TAG, "SMS de Phishing suspect détecté en temps réel depuis $packageName")
            triggerPhishingAlert(this, text)
        }
    }

    private fun triggerPhishingAlert(context: Context, snippet: String) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Alertes Anti-Phishing ShieldNet",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Avertissements immédiats en cas de SMS suspect ou tentative de fraude bancaire"
                enableLights(true)
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("⚠️ Alerte ShieldNet : SMS Suspect")
            .setContentText("Tentative d'hameçonnage détectée. Ne cliquez sur aucun lien.")
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText("ShieldNet a détecté un faux message bancaire ou administratif.\nExtrait : \"$snippet\"\nNe cliquez sur aucun lien et ne transmettez aucune coordonnée bancaire.")
            )
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        notificationManager.notify(NOTIFICATION_ID, notification)
    }
}
