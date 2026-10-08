package com.shieldnet.shieldnet

import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CALL_CHANNEL = "com.shieldnet.shieldnet/call_screening"
    private val SECURITY_CHANNEL = "com.shieldnet.security"
    private var pendingRoleResult: MethodChannel.Result? = null
    private val REQUEST_ROLE_CODE = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestCallScreeningRole" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val roleManager = getSystemService(Context.ROLE_SERVICE) as? RoleManager
                        if (roleManager != null && roleManager.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING)) {
                            val isHeld = roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)
                            if (isHeld) {
                                result.success(true)
                            } else {
                                pendingRoleResult = result
                                val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING)
                                startActivityForResult(intent, REQUEST_ROLE_CODE)
                            }
                        } else {
                            result.success(true)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "isCallScreeningActive" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val roleManager = getSystemService(Context.ROLE_SERVICE) as? RoleManager
                        if (roleManager != null && roleManager.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING)) {
                            result.success(roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING))
                        } else {
                            result.success(true)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "testDatabaseBridge" -> {
                    val diag = ShieldNetDatabaseHelper.getBridgeDiagnostic(applicationContext)
                    result.success(diag)
                }
                "checkNumber" -> {
                    val number = call.argument<String>("number")
                    if (number != null) {
                        val hash = ShieldNetDatabaseHelper.hashPhoneNumber(applicationContext, number)
                        val isBlocked = ShieldNetDatabaseHelper.isNumberBlacklisted(applicationContext, hash)
                        result.success(isBlocked)
                    } else {
                        result.error("INVALID_ARGUMENT", "number parameter is required", null)
                    }
                }
                "setContactsOnlyMode" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val prefs = getSharedPreferences("shieldnet_prefs", Context.MODE_PRIVATE)
                    prefs.edit().putBoolean("contacts_only_mode", enabled).apply()
                    result.success(true)
                }
                "isContactsOnlyMode" -> {
                    val prefs = getSharedPreferences("shieldnet_prefs", Context.MODE_PRIVATE)
                    result.success(prefs.getBoolean("contacts_only_mode", false))
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURITY_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "setCryptoSalt") {
                val salt = call.argument<String>("salt")
                if (salt != null) {
                    try {
                        val masterKey = MasterKey.Builder(applicationContext)
                            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                            .build()
                        
                        val sharedPreferences = EncryptedSharedPreferences.create(
                            applicationContext,
                            "shieldnet_secure_prefs",
                            masterKey,
                            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
                        )
                        
                        sharedPreferences.edit().putString("crypto_salt", salt).apply()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("KEYSTORE_ERROR", e.message, null)
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "Salt cannot be null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_ROLE_CODE) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val roleManager = getSystemService(Context.ROLE_SERVICE) as? RoleManager
                val isHeld = roleManager?.isRoleHeld(RoleManager.ROLE_CALL_SCREENING) ?: false
                pendingRoleResult?.success(isHeld)
            } else {
                pendingRoleResult?.success(resultCode == RESULT_OK)
            }
            pendingRoleResult = null
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        try {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        } catch (e: IllegalStateException) {
            android.util.Log.w("MainActivity", "Caught duplicate reply from plugin: ${e.message}")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error in onRequestPermissionsResult: ${e.message}")
        }
    }
}

