package com.shieldnet.shieldnet

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import java.io.File
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

object ShieldNetDatabaseHelper {

    private const val TAG = "ShieldNetDBHelper"
    const val DEFAULT_SALT = "dev-local-hash-salt-test-do-not-use-in-prod"

    @Volatile
    private var cachedSalt: String? = null

    @Volatile
    private var cachedDbFile: File? = null

    /**
     * Permet d'alimenter immédiatement le cache mémoire du sel.
     */
    fun setCachedSalt(salt: String) {
        cachedSalt = salt
    }

    /**
     * Recherche le fichier de base de données SQLite créé par Flutter/Sqflite
     * à travers tous les emplacements possibles sur Android.
     * Utilise le cache en mémoire RAM après la première détection.
     */
    fun findDatabaseFile(context: Context): File? {
        val existing = cachedDbFile
        if (existing != null && existing.exists() && existing.canRead()) {
            return existing
        }

        val candidatePaths = listOf(
            File(context.getDir("flutter", Context.MODE_PRIVATE), "shieldnet_cache.db"),
            File(context.filesDir, "shieldnet_cache.db"),
            context.getDatabasePath("shieldnet_cache.db"),
            File(context.applicationInfo.dataDir, "databases/shieldnet_cache.db"),
            File(context.applicationInfo.dataDir, "app_flutter/shieldnet_cache.db")
        )

        for (candidate in candidatePaths) {
            if (candidate.exists() && candidate.canRead()) {
                Log.d(TAG, "Base SQLite détectée avec succès: ${candidate.absolutePath}")
                cachedDbFile = candidate
                return candidate
            }
        }

        Log.w(TAG, "Aucun fichier shieldnet_cache.db trouvé parmi les chemins candidats.")
        return null
    }

    /**
     * Récupère le sel cryptographique depuis la RAM (<0.001ms) ou EncryptedSharedPreferences.
     */
    fun getCryptoSalt(context: Context): String {
        cachedSalt?.let { return it }

        try {
            val masterKey = MasterKey.Builder(context)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()

            val prefs = EncryptedSharedPreferences.create(
                context,
                "shieldnet_secure_prefs",
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )

            val salt = prefs.getString("crypto_salt", null)
            if (!salt.isNullOrEmpty()) {
                cachedSalt = salt
                return salt
            }
        } catch (e: Exception) {
            Log.w(TAG, "Lecture Keystore impossible: ${e.message}")
        }
        val isDebuggable = (context.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
        val fallback = if (isDebuggable) {
            DEFAULT_SALT
        } else {
            Log.e(TAG, "Sécurité: Sel absent du Keystore en environnement de production.")
            ""
        }
        if (fallback.isNotEmpty()) {
            cachedSalt = fallback
        }
        return fallback
    }

    /**
     * Normalisation identique au format E.164 de CryptoUtils.dart
     */
    fun normalizePhoneNumber(rawNumber: String): String {
        val trimmed = rawNumber.trim()
        val hasPlus = trimmed.startsWith("+")
        val digitsOnly = trimmed.replace(Regex("\\D"), "")

        return when {
            hasPlus -> "+$digitsOnly"
            digitsOnly.length == 10 -> "+1$digitsOnly"
            digitsOnly.length == 11 && digitsOnly.startsWith("1") -> "+$digitsOnly"
            else -> "+$digitsOnly"
        }
    }

    /**
     * Calcul du HMAC-SHA256 strictement identique à CryptoUtils.hashPhoneNumber() en Dart
     */
    fun hashPhoneNumber(context: Context, rawNumber: String): String {
        val normalized = normalizePhoneNumber(rawNumber)
        val salt = getCryptoSalt(context)

        val mac = Mac.getInstance("HmacSHA256")
        val secretKey = SecretKeySpec(salt.toByteArray(Charsets.UTF_8), "HmacSHA256")
        mac.init(secretKey)
        val bytes = mac.doFinal(normalized.toByteArray(Charsets.UTF_8))
        return bytes.joinToString("") { "%02x".format(it) }
    }

    /**
     * Vérifie directement dans la base SQLite locale de Flutter si le hash est présent et actif
     */
    fun isNumberBlacklisted(context: Context, phoneHash: String): Boolean {
        val dbFile = findDatabaseFile(context) ?: return false
        var db: SQLiteDatabase? = null

        return try {
            db = SQLiteDatabase.openDatabase(
                dbFile.absolutePath,
                null,
                SQLiteDatabase.OPEN_READONLY or SQLiteDatabase.NO_LOCALIZED_COLLATORS
            )

            val cursor = db.query(
                "blacklist",
                arrayOf("phone_hash"),
                "phone_hash = ?",
                arrayOf(phoneHash),
                null, null, null
            )

            val count = cursor.count
            cursor.close()
            Log.d(TAG, "Vérification SQLite pour $phoneHash -> Trouvé: ${count > 0}")
            count > 0
        } catch (e: Exception) {
            Log.e(TAG, "Erreur lors de la lecture SQLite native: ${e.message}")
            false
        } finally {
            try { db?.close() } catch (_: Exception) {}
        }
    }

    private val STANDARD_EMERGENCY_NUMBERS = setOf("911", "112", "811", "988", "211", "311", "511")

    /**
     * Vérifie si un numéro est un service d'urgence critique ou un contact en liste blanche prioritaire
     */
    fun isEmergencyNumber(context: Context, rawNumber: String, phoneHash: String): Boolean {
        var cleanDigits = rawNumber.replace(Regex("\\D"), "")
        if (cleanDigits.length == 4 && cleanDigits.startsWith("1")) {
            cleanDigits = cleanDigits.substring(1)
        }
        if (STANDARD_EMERGENCY_NUMBERS.contains(cleanDigits) || STANDARD_EMERGENCY_NUMBERS.contains(rawNumber.trim())) {
            Log.i(TAG, "Numéro identifié comme service d'urgence officiel nord-américain: $rawNumber")
            return true
        }

        val dbFile = findDatabaseFile(context) ?: return false
        var db: SQLiteDatabase? = null

        return try {
            db = SQLiteDatabase.openDatabase(
                dbFile.absolutePath,
                null,
                SQLiteDatabase.OPEN_READONLY or SQLiteDatabase.NO_LOCALIZED_COLLATORS
            )

            val cursor = db.query(
                "emergency_whitelist",
                arrayOf("phone_hash"),
                "phone_hash = ?",
                arrayOf(phoneHash),
                null, null, null
            )

            val isWhitelisted = cursor.count > 0
            cursor.close()
            if (isWhitelisted) {
                Log.i(TAG, "Numéro trouvé dans la liste blanche d'urgence (bénéficie de l'immunité): $phoneHash")
            }
            isWhitelisted
        } catch (e: Exception) {
            Log.e(TAG, "Erreur vérification liste blanche SQLite: ${e.message}")
            false
        } finally {
            try { db?.close() } catch (_: Exception) {}
        }
    }

    /**
     * Diagnostic complet du pont SQLite pour l'écran de réglages Flutter
     */
    fun getBridgeDiagnostic(context: Context): Map<String, Any> {
        val dbFile = findDatabaseFile(context)
        if (dbFile == null) {
            return mapOf(
                "connected" to false,
                "path" to "Introuvable",
                "count" to 0,
                "message" to "Le fichier shieldnet_cache.db n'a pas encore été initialisé par Flutter."
            )
        }

        var count = 0
        var readable = false
        var db: SQLiteDatabase? = null

        try {
            db = SQLiteDatabase.openDatabase(
                dbFile.absolutePath,
                null,
                SQLiteDatabase.OPEN_READONLY or SQLiteDatabase.NO_LOCALIZED_COLLATORS
            )
            val cursor = db.rawQuery("SELECT COUNT(*) FROM blacklist", null)
            if (cursor.moveToFirst()) {
                count = cursor.getInt(0)
            }
            cursor.close()
            readable = true
        } catch (e: Exception) {
            Log.e(TAG, "Diagnostic DB Erreur: ${e.message}")
        } finally {
            try { db?.close() } catch (_: Exception) {}
        }

        return mapOf(
            "connected" to readable,
            "path" to dbFile.absolutePath,
            "count" to count,
            "message" to if (readable) "Pont SQLite <-> Kotlin opérationnel ($count numéros)." else "Fichier trouvé mais illisible."
        )
    }
}
